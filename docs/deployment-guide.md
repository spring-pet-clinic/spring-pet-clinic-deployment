# Spring PetClinic — Deployment Guide

**SPCAD-36 | Author: Sridevi Parimi / Sonny Enchill | Last updated: 13 May 2026**

This guide covers a full end-to-end deployment of the Spring PetClinic Microservices application onto the existing AWS EKS infrastructure. Follow every section in order on a clean deployment.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Repository Setup](#2-repository-setup)
3. [Infrastructure Provisioning (Terraform)](#3-infrastructure-provisioning-terraform)
4. [Kubernetes Secrets](#4-kubernetes-secrets)
5. [Container Images — CI/CD Pipeline](#5-container-images--cicd-pipeline)
6. [Apply Kubernetes Manifests](#6-apply-kubernetes-manifests)
7. [Ingress (Public URL)](#7-ingress-public-url)
8. [Monitoring Stack](#8-monitoring-stack)
9. [Verification](#9-verification)
10. [Known Issues and Traps](#10-known-issues-and-traps)

---

## 1. Prerequisites

### Tools Required

| Tool | Minimum Version | Install |
|------|----------------|---------|
| AWS CLI | v2 | `https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html` |
| kubectl | 1.30+ | `https://kubernetes.io/docs/tasks/tools/` |
| Terraform | 1.8.5 | `https://developer.hashicorp.com/terraform/install` |
| Git | any | system package manager |
| gh (GitHub CLI) | any | `https://cli.github.com/` |

### AWS Access

Configure your IAM user credentials:

```bash
aws configure
# AWS Access Key ID: <your key>
# AWS Secret Access Key: <your secret>
# Default region name: eu-west-1
# Default output format: json
```

Verify access:

```bash
aws sts get-caller-identity
```

### Key Values

| Resource | Value |
|----------|-------|
| AWS Account ID | `135728714831` |
| Region | `eu-west-1` |
| EKS Cluster | `spring-petclinic-ireland-eks` |
| Namespace | `spring-petclinic-ireland` |
| ECR Registry | `135728714831.dkr.ecr.eu-west-1.amazonaws.com` |
| Terraform State Bucket | `petclinic-tfstate-rj79q8aw` |
| Terraform Lock Table | `petclinic-tfstate-lock` |
| Public URL | `http://spring-petclinic-alb-611357354.eu-west-1.elb.amazonaws.com` |

---

## 2. Repository Setup

Two repositories are used. Clone both:

```bash
# Application source code
git clone https://github.com/spring-pet-clinic/spring-petclinic-microservices.git

# Deployment artifacts (Terraform, k8s manifests, CI/CD workflows)
git clone https://github.com/spring-pet-clinic/spring-pet-clinic-deployment.git
cd spring-pet-clinic-deployment
git checkout main
```

Configure kubectl to reach the cluster:

```bash
aws eks update-kubeconfig --name spring-petclinic-ireland-eks --region eu-west-1
kubectl get nodes   # should list 5 nodes across 3 node groups
```

---

## 3. Infrastructure Provisioning (Terraform)

All infrastructure is managed via the Terraform pipeline in GitHub Actions. **Do not run Terraform locally against production** unless recovering from an incident.

### Trigger via Pipeline

Navigate to the deployment repo on GitHub:
**Actions → Terraform Infrastructure Pipeline → Run workflow** (select branch `main`)

The pipeline applies modules in this order: `networking` → `ecr` → `eks` → `rds` → `monitoring` (kube-prometheus-stack CRDs first, then full) → `ingress`.

### What Terraform Provisions

| Module | Resources Created |
|--------|------------------|
| `networking` | VPC, public/private/DB subnets, IGW, NAT Gateway, route tables, security groups |
| `ecr` | 8 ECR repositories (one per microservice) |
| `eks` | EKS cluster (K8s 1.30), 3 node groups, OIDC provider, IAM roles |
| `rds` | MySQL 8.4 RDS instance, parameter group, Secrets Manager secrets (per DB) |
| `monitoring` | kube-prometheus-stack Helm release, Zipkin Helm release, ServiceMonitors |
| `ingress` | AWS Load Balancer Controller IRSA role, Helm release, Kubernetes service account |

### Node Groups

| Node Group | Instance | Count | Workloads |
|------------|----------|-------|-----------|
| `spring-petclinic-ireland-infra-nodes` | t3.small | 2 | config-server, discovery-server |
| `spring-petclinic-ireland-app-nodes` | t3.medium | 2 | api-gateway, customers, vets, visits, genai, admin |
| `spring-petclinic-ireland-monitoring-nodes` | t3.small | 1 | Prometheus, Grafana, Zipkin |

### After Terraform Apply — Critical Check

Terraform applies can silently wipe the RDS security group rule that allows EKS nodes to reach MySQL. After every Terraform apply, verify services are running (see [Section 9](#9-verification)). If DB services crash with "Communications link failure", see [Section 10](#10-known-issues-and-traps).

---

## 4. Kubernetes Secrets

These secrets must exist in the namespace **before** applying any service manifests.

### 4.1 Create the Namespace

```bash
kubectl apply -f k8s/namespace.yaml
```

Or manually:

```bash
kubectl create namespace spring-petclinic-ireland
```

### 4.2 MySQL Secret

The DB services (customers, vets, visits) read database credentials from this secret.

```bash
kubectl create secret generic mysql-secret \
  --from-literal=username=petclinic_admin \
  --from-literal=password=<master-password-from-rds> \
  -n spring-petclinic-ireland
```

To retrieve the master password from Secrets Manager:

```bash
aws secretsmanager get-secret-value \
  --secret-id spring-petclinic-ireland/rds/customers \
  --region eu-west-1 \
  --query SecretString --output text | python3 -m json.tool
```

### 4.3 OpenAI Secret (GenAI Service)

**Note:** The `demo` key is no longer accepted by OpenAI. A valid key from `platform.openai.com` is required. If no key is available, create the secret with a placeholder — the genai-service will start but the chatbot will be non-functional.

```bash
kubectl create secret generic openai-secret \
  --from-literal=OPENAI_API_KEY=<your-openai-api-key> \
  -n spring-petclinic-ireland
```

---

## 5. Container Images — CI/CD Pipeline

Images are built and pushed automatically by the **Build and Push PetClinic Images to ECR** pipeline on every push to `dev` or `main`.

### Trigger Manually

Push any change to `dev` or `main`, or trigger from:
**Actions → Build and Push PetClinic Images to ECR → Run workflow**

### What It Does

1. Checks out `spring-petclinic-microservices` (application source)
2. Authenticates to ECR via OIDC
3. Builds all 8 Docker images using the Spring Boot buildpack
4. Pushes to ECR tagged with both `<git-sha>` and `latest`

### ECR Repository URIs

| Service | ECR URI |
|---------|---------|
| config-server | `135728714831.dkr.ecr.eu-west-1.amazonaws.com/spring-petclinic-ireland/config-server` |
| discovery-server | `135728714831.dkr.ecr.eu-west-1.amazonaws.com/spring-petclinic-ireland/discovery-server` |
| api-gateway | `135728714831.dkr.ecr.eu-west-1.amazonaws.com/spring-petclinic-ireland/api-gateway` |
| customers-service | `135728714831.dkr.ecr.eu-west-1.amazonaws.com/spring-petclinic-ireland/customers-service` |
| vets-service | `135728714831.dkr.ecr.eu-west-1.amazonaws.com/spring-petclinic-ireland/vets-service` |
| visits-service | `135728714831.dkr.ecr.eu-west-1.amazonaws.com/spring-petclinic-ireland/visits-service` |
| genai-service | `135728714831.dkr.ecr.eu-west-1.amazonaws.com/spring-petclinic-ireland/genai-service` |
| admin-server | `135728714831.dkr.ecr.eu-west-1.amazonaws.com/spring-petclinic-ireland/admin-server` |

---

## 6. Apply Kubernetes Manifests

Apply manifests **in this exact order**. The `initContainers` enforce startup dependencies but applying out of order can cause unnecessary restarts.

```bash
# 1. Infrastructure services (must be healthy before anything else)
kubectl apply -f k8s/config-server/deployment.yaml
kubectl rollout status deployment/config-server -n spring-petclinic-ireland --timeout=120s

kubectl apply -f k8s/discovery-server/deployment.yaml
kubectl rollout status deployment/discovery-server -n spring-petclinic-ireland --timeout=120s

# 2. Gateway (waits for discovery-server via initContainer)
kubectl apply -f k8s/api-gateway/deployment.yaml

# 3. DB-backed services (each waits for discovery-server via initContainer)
kubectl apply -f k8s/customers-service/deployment.yaml
kubectl apply -f k8s/vets-service/deployment.yaml
kubectl apply -f k8s/visits-service/deployment.yaml

# 4. GenAI service (requires openai-secret to exist first)
kubectl apply -f k8s/genai-service/deployment.yaml

# 5. Admin server (waits for both config and discovery)
kubectl apply -f k8s/admin-server/deployment.yaml

# 6. HPA for traffic-facing services (requires metrics-server)
kubectl apply -f k8s/hpa.yaml

# Verify all 8 pods are Running
kubectl get pods -n spring-petclinic-ireland
```

All 8 pods should show `1/1 Running`. Allow up to 3 minutes for JVM startup and health checks to pass.

### Database Schema Initialisation

The RDS instance has a single MySQL server. The microservices connect to three separate databases (`petclinic_customers`, `petclinic_vets`, `petclinic_visits`). These databases and their tables must exist before the services start.

If the services crash on first deployment with schema errors, apply the init job:

```bash
kubectl apply -f k8s/db-schema-init-job.yaml
kubectl wait --for=condition=complete job/db-schema-init -n spring-petclinic-ireland --timeout=120s
```

Then restart the DB services:

```bash
kubectl rollout restart deployment/customers-service deployment/vets-service deployment/visits-service \
  -n spring-petclinic-ireland
```

---

## 7. Ingress (Public URL)

The AWS Load Balancer Controller (deployed by Terraform) watches for `Ingress` resources with `kubernetes.io/ingress.class: alb` and provisions an Application Load Balancer automatically.

```bash
kubectl apply -f k8s/ingress.yaml
```

Wait ~2 minutes for the ALB to provision:

```bash
kubectl get ingress -n spring-petclinic-ireland
# EXTERNAL-IP column will show the ALB DNS name once ready
```

**Current public URL:** `http://spring-petclinic-alb-611357354.eu-west-1.elb.amazonaws.com`

The application UI is served at the root path `/`. All API routes are proxied through the `api-gateway`.

---

## 8. Monitoring Stack

The monitoring stack (Prometheus, Grafana, Alertmanager, Zipkin) is deployed by Terraform into the `monitoring` namespace. It starts automatically as part of the Terraform pipeline.

### Verify Monitoring Pods

```bash
kubectl get pods -n monitoring
```

All of the following should be `Running`:
- `kube-prometheus-stack-grafana-*`
- `prometheus-kube-prometheus-stack-prometheus-0`
- `alertmanager-kube-prometheus-stack-alertmanager-0`
- `zipkin-*`

### Access via Port-Forward

Monitoring tools are `ClusterIP` only — not exposed publicly. Access them locally:

```bash
# Grafana — http://localhost:3000  (admin / MyStrongPassword123)
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring

# Prometheus — http://localhost:9090
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring

# Zipkin — http://localhost:9411/zipkin/
kubectl port-forward svc/zipkin 9411:9411 -n monitoring

# Alertmanager — http://localhost:9093
kubectl port-forward svc/kube-prometheus-stack-alertmanager 9093:9093 -n monitoring
```

### Grafana Dashboard

The PetClinic dashboard JSON is at `observability/grafana/dashboards/petclinic-dashboard.json`. To import:

1. Open Grafana → Dashboards → Import
2. Upload the JSON file
3. Select the Prometheus datasource

### Metrics-Server

`kubectl top` and HPA require metrics-server. It is installed on the cluster. Verify:

```bash
kubectl top nodes
kubectl top pods -n spring-petclinic-ireland
```

---

## 9. Verification

### Check All Pods Are Running

```bash
kubectl get pods -n spring-petclinic-ireland
```

Expected: 8 pods, all `1/1 Running`.

### Check HPA

```bash
kubectl get hpa -n spring-petclinic-ireland
```

Expected: 4 HPAs showing real CPU percentages (not `<unknown>`).

### Health Endpoints

Port-forward the api-gateway and test all services:

```bash
kubectl port-forward svc/api-gateway 8080:8080 -n spring-petclinic-ireland &

curl http://localhost:8080/actuator/health          # api-gateway
curl http://localhost:8080/api/customer/actuator/health   # customers-service
curl http://localhost:8080/api/vet/actuator/health        # vets-service
curl http://localhost:8080/api/visit/actuator/health      # visits-service
```

All should return `{"status":"UP"}`.

### Public URL Smoke Test

```bash
curl -s -o /dev/null -w "%{http_code}" \
  http://spring-petclinic-alb-611357354.eu-west-1.elb.amazonaws.com/
# Expected: 200
```

---

## 10. Known Issues and Traps

### RDS Connectivity — Services Crash After Terraform Apply

**Symptom:** customers-service, vets-service, or visits-service enter `CrashLoopBackOff` with `Communications link failure` / `Connect timed out` in the logs.

**Root cause:** Terraform applies the `module.rds` step and recreates or refreshes the `aws_security_group_rule.rds_from_eks_nodes` resource. If the rule is not in Terraform state, the apply will destroy it and not recreate it, blocking MySQL access from worker nodes.

**Diagnosis:**

```bash
# Check the RDS security group rules
aws ec2 describe-security-group-rules \
  --filters Name=group-id,Values=sg-0d1143f7fa984a496 \
  --query 'SecurityGroupRules[?IsEgress==`false`].[FromPort,ReferencedGroupInfo.GroupId,Description]' \
  --output table --region eu-west-1

# The rule for sg-026585940528ba244 must be present
```

**Fix:** If the rule is missing, re-add it:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-0d1143f7fa984a496 \
  --protocol tcp --port 3306 \
  --source-group sg-026585940528ba244 \
  --region eu-west-1
```

Then import it into Terraform state so it survives the next apply:

```bash
cd terraform
terraform import module.rds.aws_security_group_rule.rds_from_eks_nodes \
  sg-0d1143f7fa984a496_ingress_tcp_3306_3306_sg-026585940528ba244
```

Then restart the affected services:

```bash
kubectl rollout restart deployment/customers-service deployment/vets-service deployment/visits-service \
  -n spring-petclinic-ireland
```

**Key SG IDs:**

| SG | Purpose |
|----|---------|
| `sg-0d1143f7fa984a496` | RDS database security group |
| `sg-026585940528ba244` | EKS worker nodes (`spring-petclinic-ireland-eks-nodes-sg`) |
| `sg-0fbb55c0b61b06485` | EKS cluster shared SG — attached to control plane only, NOT to worker node ENIs |

### Terraform State Lock — Stale Lock After Pipeline Cancellation

**Symptom:** `Error acquiring the state lock — ConditionalCheckFailedException`

**Fix:** Force-unlock using the lock ID shown in the error:

```bash
cd terraform
terraform force-unlock -force <lock-id-from-error>
```

Only do this when you are certain no other pipeline is actively running.

### Monitoring Namespace Destroyed by Terraform Apply

**Symptom:** All pods in `monitoring` namespace disappear after a Terraform apply.

**Root cause:** The `kubernetes_namespace_v1.monitoring` resource was removed from the Terraform config. If Terraform previously managed the namespace and it's removed from config, the next apply destroys it.

**Fix:**

```bash
kubectl create namespace monitoring
cd terraform
terraform import module.monitoring.kubernetes_namespace_v1.monitoring monitoring
```

Then re-trigger the Terraform pipeline to redeploy the Helm releases.

### Service Startup Order

config-server → discovery-server → everything else. Do not apply domain service manifests before both infra services show `1/1 Running`. The `initContainers` will wait, but applying in the wrong order causes unnecessary restart cycles.

### GenAI Chatbot Non-Functional

The `demo` OpenAI API key is no longer accepted by OpenAI. The chatbot feature ("Chat with Us") will not respond to messages without a valid API key from `platform.openai.com`. All other application features (owners, pets, vets, visits) work normally.

### ECR Authentication Expiry

ECR authentication tokens expire after 12 hours. If manual Docker pushes fail with an auth error:

```bash
aws ecr get-login-password --region eu-west-1 | \
  docker login --username AWS --password-stdin \
  135728714831.dkr.ecr.eu-west-1.amazonaws.com
```

---

## GitHub Actions Secrets Reference

All secrets are set on `spring-pet-clinic/spring-pet-clinic-deployment`:

| Secret | Value | Used By |
|--------|-------|---------|
| `AWS_ROLE_ARN` | `arn:aws:iam::135728714831:role/spring-petclinic-github-actions-role` | All pipelines |
| `AWS_ACCOUNT_ID` | `135728714831` | Build and Push |
| `AWS_REGION` | `eu-west-1` | All pipelines |
| `CLUSTER_NAME` | `spring-petclinic-ireland-eks` | Deploy pipelines |
| `NAMESPACE` | `spring-petclinic-ireland` | Deploy pipelines |
