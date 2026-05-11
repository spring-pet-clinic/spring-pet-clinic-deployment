#!/usr/bin/env bash
# =============================================================================
# build-and-push.sh
# Builds all 8 Spring PetClinic microservice Docker images and pushes them to
# Amazon ECR.
#
# Usage (local):
#   export AWS_REGION=eu-west-1
#   export IMAGE_TAG=v1.0.0           # optional — defaults to 'latest'
#   ./scripts/build-and-push.sh
#
# The script is also called by the Azure DevOps pipeline automatically.
# =============================================================================
set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
AWS_REGION="${AWS_REGION:-eu-west-1}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
JAVA_VERSION="${JAVA_VERSION:-17}"

# ── Build strategy ─────────────────────────────────────────────────────────────
# WHY: Spring Boot build-image uses CNB (Cloud Native Buildpacks) internally.
# CNB has its own registry auth layer and does NOT read Docker CLI credentials.
# Passing an ECR URI as imageName causes CNB to attempt ECR auth → 'username' null.
# Fix: always build with a LOCAL image name first, then tag + push via Docker CLI
# (which DOES use the ECR credentials from 'docker login' in Step 2).
USE_DOCKERFILE="${USE_DOCKERFILE:-false}"   # set to true if you add Dockerfiles

# All 8 microservice module names (must match Maven module dirs and ECR repo names)
SERVICES=(
  "spring-petclinic-config-server"
  "spring-petclinic-discovery-server"
  "spring-petclinic-api-gateway"
  "spring-petclinic-customers-service"
  "spring-petclinic-visits-service"
  "spring-petclinic-vets-service"
  "spring-petclinic-admin-server"
  "spring-petclinic-genai-service"
)

# ── Derived values ─────────────────────────────────────────────────────────────
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "============================================================"
echo "  Spring PetClinic — ECR Build & Push"
echo "  Registry : ${ECR_REGISTRY}"
echo "  Tag      : ${IMAGE_TAG}"
echo "  Region   : ${AWS_REGION}"
echo "============================================================"

# ── Step 1: Verify prerequisites ──────────────────────────────────────────────
echo ""
echo "[1/4] Checking prerequisites..."
command -v aws    >/dev/null 2>&1 || { echo "ERROR: aws CLI not found"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found"; exit 1; }
command -v java   >/dev/null 2>&1 || { echo "ERROR: java not found"; exit 1; }
command -v mvn    >/dev/null 2>&1 || HAVE_MVN=false

JAVA_VER=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
# Spring Boot 4.x requires Java 17+; Java 21 is also fine (21 > 17 passes this check)
if [[ "${JAVA_VER}" -lt "${JAVA_VERSION}" ]]; then
  echo "ERROR: Java ${JAVA_VERSION}+ required (found ${JAVA_VER})"
  exit 1
fi
echo "Prerequisites OK"

# ── Step 2: Authenticate Docker to ECR ────────────────────────────────────────
echo ""
echo "[2/4] Authenticating to ECR..."
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${ECR_REGISTRY}"
echo "ECR authentication successful"

# ── Step 3: Maven build (skip tests — tests run in a separate pipeline stage) ─
echo ""
echo "[3/4] Building all services with Maven..."
if [[ -x "./mvnw" ]]; then
  ./mvnw clean package -DskipTests --batch-mode -q
else
  mvn clean package -DskipTests --batch-mode -q
fi
echo "Maven build complete"

# ── Step 4: Build Docker images and push to ECR ───────────────────────────────
echo ""
echo "[4/4] Building and pushing Docker images..."
FAILED_SERVICES=()

for SERVICE in "${SERVICES[@]}"; do
  echo ""
  echo "──────────────────────────────────────"
  echo "  Service: ${SERVICE}"
  echo "──────────────────────────────────────"

  SERVICE_DIR="./${SERVICE}"
  IMAGE_URI="${ECR_REGISTRY}/${SERVICE}"

  # Validate service directory exists
  if [[ ! -d "${SERVICE_DIR}" ]]; then
    echo "  WARN: Directory '${SERVICE_DIR}' not found — skipping"
    FAILED_SERVICES+=("${SERVICE} (directory missing)")
    continue
  fi

  # ── Build strategy ───────────────────────────────────────────────────────────
  if [[ -f "${SERVICE_DIR}/Dockerfile" ]]; then
    # Path A: Dockerfile exists — standard docker build (fastest, no CNB involved)
    echo "  Building from Dockerfile..."
    docker build \
      --build-arg JAR_FILE="${SERVICE}/target/*.jar" \
      -t "${IMAGE_URI}:${IMAGE_TAG}" \
      -t "${IMAGE_URI}:latest" \
      -f "${SERVICE_DIR}/Dockerfile" \
      .

  else
    # Path B: No Dockerfile — use Spring Boot build-image (CNB/Paketo Buildpacks)
    # ─────────────────────────────────────────────────────────────────────────
    # IMPORTANT: Do NOT pass the ECR URI as imageName here.
    # CNB has its own registry client that cannot read Docker CLI credentials.
    # Passing an ECR URL causes: 'username' must not be null → crash.
    # Fix: build with a plain local name, then tag + push via Docker CLI.
    # ─────────────────────────────────────────────────────────────────────────
    LOCAL_IMAGE="${SERVICE}:${IMAGE_TAG}"
    echo "  INFO: No Dockerfile — building locally via Spring Boot Buildpacks..."
    echo "  Local image name: ${LOCAL_IMAGE}  (will be tagged for ECR after build)"

    MVN_CMD="./mvnw"
    [[ ! -x "./mvnw" ]] && MVN_CMD="mvn"

    ${MVN_CMD} spring-boot:build-image \
      -pl "${SERVICE}" \
      -Dspring-boot.build-image.imageName="${LOCAL_IMAGE}" \
      -Dspring-boot.build-image.publish=false \
      -DskipTests \
      --batch-mode -q

    echo "  Tagging local image → ECR URI..."
    docker tag "${LOCAL_IMAGE}" "${IMAGE_URI}:${IMAGE_TAG}"
    docker tag "${LOCAL_IMAGE}" "${IMAGE_URI}:latest"
    # Clean up the untagged local copy to save disk space
    docker rmi "${LOCAL_IMAGE}" 2>/dev/null || true
  fi

  # Push both tags using Docker CLI (which has ECR credentials from Step 2)
  echo "  Pushing ${SERVICE}:${IMAGE_TAG} ..."
  docker push "${IMAGE_URI}:${IMAGE_TAG}"
  docker push "${IMAGE_URI}:latest"

  echo "  ✅ ${SERVICE} pushed successfully"
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  Build & Push Summary"
echo "============================================================"
TOTAL=${#SERVICES[@]}
FAILED=${#FAILED_SERVICES[@]}
echo "  Total services : ${TOTAL}"
echo "  Succeeded      : $(( TOTAL - FAILED ))"
echo "  Failed         : ${FAILED}"

if [[ ${FAILED} -gt 0 ]]; then
  echo ""
  echo "  Failed services:"
  for s in "${FAILED_SERVICES[@]}"; do
    echo "    ✗ ${s}"
  done
  exit 1
fi

echo ""
echo "🎉 All images pushed to ECR successfully!"
echo ""
echo "  ECR Registry  : ${ECR_REGISTRY}"
echo "  Tag pushed    : ${IMAGE_TAG}"
echo "  Also tagged   : latest"
