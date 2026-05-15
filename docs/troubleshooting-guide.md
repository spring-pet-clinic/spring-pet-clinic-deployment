# Spring PetClinic EKS — Troubleshooting Guide

**Author:** Deployment Team
**Last Updated:** 13 May 2026
**Cluster:** `spring-petclinic-ireland-eks` | **Region:** `eu-west-1` | **Namespace:** `spring-petclinic-ireland`

---

## Table of Contents

1. [RDS / Database Connectivity](#1-rds--database-connectivity)
2. [Pod CrashLoopBackOff or OOMKilled](#2-pod-crashloopbackoff-or-oomkilled)
3. [Service Startup Order / initContainer Stuck](#3-service-startup-order--initcontainer-stuck)
4. [Terraform State Lock](#4-terraform-state-lock)
5. [Terraform Pipeline 403 on S3 State](#5-terraform-pipeline-403-on-s3-state)
6. [GitHub Actions AWS Auth Failures](#6-github-actions-aws-auth-failures)
7. [ECR Authentication Expired](#7-ecr-authentication-expired)
8. [ALB / Ingress Not Provisioning](#8-alb--ingress-not-provisioning)
9. [MySQL Schema Not Initialised](#9-mysql-schema-not-initialised)
10. [GenAI Service Non-Functional](#10-genai-service-non-functional)
11. [kubectl: Wrong Context or No Access](#11-kubectl-wrong-context-or-no-access)
12. [Monitoring Stack Destroyed by Terraform](#12-monitoring-stack-destroyed-by-terraform)
13. [Monitoring Public URLs Returning 404](#13-monitoring-public-urls-returning-404)
14. [Zipkin Traces Not Appearing](#14-zipkin-traces-not-appearing)
15. [General Diagnostic Commands](#15-general-diagnostic-commands)

---

## 1. RDS / Database Connectivity

**Symptom:**
`customers-service`, `vets-service`, or `visits-service` pods enter `CrashLoopBackOff`. Logs show:

```
com.mysql.cj.jdbc.exceptions.CommunicationsException: Communications link failure
```

**Root Cause:**
EKS worker nodes have only `sg-026585940528ba244` (`spring-petclinic-ireland-eks-nodes-sg`) on their ENIs. The EKS *cluster* shared security group (`sg-0fbb55c0b61b06485`) is NOT attached to node ENIs despite being returned by `vpc_config[0].cluster_security_group_id`. If Terraform runs without the correct node SG in the RDS ingress rule, connectivity is silently broken.

**Fix:**

Check the current RDS security group rules:
```bash
aws ec2 describe-security-group-rules \
  --filters Name=group-id,Values=sg-0d1143f7fa984a496 \
  --query 'SecurityGroupRules[?IsEgress==`false`].[SourceSecurityGroupId,FromPort,Description]' \
  --output table --region eu-west-1
```

If `sg-026585940528ba244` is missing from the ingress rules, add it manually:
```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-0d1143f7fa984a496 \
  --protocol tcp --port 3306 \
  --source-group sg-026585940528ba244 \
  --region eu-west-1
```

Then restart the affected services:
```bash
kubectl rollout restart deployment/customers-service -n spring-petclinic-ireland
kubectl rollout restart deployment/vets-service -n spring-petclinic-ireland
kubectl rollout restart deployment/visits-service -n spring-petclinic-ireland
```

**Long-term fix:**
This rule is codified in `terraform/rds/main.tf` as `aws_security_group_rule.rds_from_eks_nodes` using `var.eks_node_security_group_id`. If it disappears after a `terraform apply`, check that `module.rds.eks_node_security_group_id` maps to `module.eks.node_security_group_id` in `terraform/main.tf` — NOT `module.eks.cluster_security_group_id`.

---

## 2. Pod CrashLoopBackOff or OOMKilled

**Symptom:**
A pod shows `CrashLoopBackOff` or `OOMKilled` in `kubectl get pods`.

**Diagnosis:**
```bash
# Check pod status and recent events
kubectl describe pod <pod-name> -n spring-petclinic-ireland

# Check logs from the failing container
kubectl logs <pod-name> -n spring-petclinic-ireland --previous
```

**Common causes and fixes:**

| Cause | How to Identify | Fix |
|-------|----------------|-----|
| Missing Kubernetes secret | `secret "openai-secret" not found` in describe output | Create the secret (see Section 10) |
| RDS unreachable | `Communications link failure` in logs | See Section 1 |
| Memory limit too low (OOMKilled) | `OOMKilled` in pod status | Increase `resources.limits.memory` in the deployment manifest and re-apply |
| Wrong ECR image URI | `ErrImagePull` or `ImagePullBackOff` | Verify image tag exists in ECR; re-run CI/CD pipeline |
| initContainer waiting | Pod stuck in `Init:0/1` | See Section 3 |

---

## 3. Service Startup Order / initContainer Stuck

**Symptom:**
A pod is stuck in `Init:0/1` and never starts.

**Root Cause:**
Every service has an `initContainer` that polls `/actuator/health` on its upstream dependency before the main container is allowed to start. If the dependency is down, the init container loops indefinitely.

**Startup dependency chain:**
```
config-server → discovery-server → api-gateway → customers/vets/visits/genai/admin
```

**Diagnosis:**
```bash
# Check which init container is waiting
kubectl describe pod <pod-name> -n spring-petclinic-ireland | grep -A5 "Init Containers"

# Check logs of the init container
kubectl logs <pod-name> -n spring-petclinic-ireland -c wait-for-config-server
# (replace container name with the actual init container name shown in describe)
```

**Fix:**

1. Identify which upstream service is unhealthy:
```bash
kubectl get pods -n spring-petclinic-ireland
```

2. Fix the upstream service first (work back up the chain to `config-server`).

3. Once the upstream pod is `Running` and `1/1 Ready`, the downstream init container will proceed automatically within its next poll interval (~10s).

**Always apply manifests in this order:**
```bash
kubectl apply -f k8s/config-server/
kubectl apply -f k8s/discovery-server/
kubectl apply -f k8s/api-gateway/
kubectl apply -f k8s/customers-service/
kubectl apply -f k8s/vets-service/
kubectl apply -f k8s/visits-service/
kubectl apply -f k8s/genai-service/
kubectl apply -f k8s/admin-server/
```

---

## 4. Terraform State Lock

**Symptom:**
`terraform apply` or `terraform init` fails with:

```
Error acquiring the state lock
Lock Info:
  ID: 20e6efde-67dc-4546-d775-e6ce6c98423f
```

**Root Cause:**
A previous Terraform run (pipeline or local) was cancelled or crashed without releasing the DynamoDB lock.

**Fix:**
```bash
cd terraform/
terraform init  # ensure backend is configured
terraform force-unlock -force <LOCK-ID>
```

Replace `<LOCK-ID>` with the ID shown in the error (e.g. `20e6efde-67dc-4546-d775-e6ce6c98423f`).

**Prevention:** Never cancel a running Terraform pipeline mid-apply. If you must, wait for the current step to finish or the lock will need to be force-released.

---

## 5. Terraform Pipeline 403 on S3 State

**Symptom:**
GitHub Actions `Terraform Init` step fails with:

```
Error refreshing state: Unable to access object "root/terraform.tfstate" in S3 bucket
"petclinic-tfstate-rj79q8aw": operation error S3: HeadObject, StatusCode: 403, Forbidden
```

**Root Cause:**
The GitHub Actions OIDC role (`spring-petclinic-github-actions-role`) is missing S3 or DynamoDB permissions for the Terraform state backend.

**Fix:**
Verify the `spring-petclinic-terraform-execution-policy` is attached to the role:
```bash
aws iam list-attached-role-policies \
  --role-name spring-petclinic-github-actions-role \
  --query 'AttachedPolicies[].PolicyName' \
  --output table
```

If `spring-petclinic-terraform-execution-policy` is missing, attach it:
```bash
aws iam attach-role-policy \
  --role-name spring-petclinic-github-actions-role \
  --policy-arn arn:aws:iam::135728714831:policy/spring-petclinic-terraform-execution-policy
```

---

## 6. GitHub Actions AWS Auth Failures

**Symptom:**
GitHub Actions pipeline fails at the `Configure AWS credentials` step, typically within 30 seconds. Error references missing `AWS_ACCESS_KEY_ID` or OIDC token errors.

**Root Cause:**
The static credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) were removed from GitHub secrets on 10 May 2026. Both pipelines now use OIDC (`AWS_ROLE_ARN`). If a workflow file still references the old secrets, it will fail.

**Fix:**
Ensure the workflow uses OIDC authentication and has `id-token: write` permission:

```yaml
permissions:
  contents: read
  id-token: write

- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ env.AWS_REGION }}
```

Verify the required GitHub secrets are set on the deployment repo:
```bash
gh secret list --repo spring-pet-clinic/spring-pet-clinic-deployment
```

Required secrets: `AWS_ROLE_ARN`, `AWS_ACCOUNT_ID`, `AWS_REGION`, `CLUSTER_NAME`, `NAMESPACE`.

---

## 7. ECR Authentication Expired

**Symptom:**
Docker push fails with `no basic auth credentials` or `unauthorized: authentication required`. Typically happens when running local builds more than 12 hours after the last login.

**Fix:**
Re-authenticate Docker to ECR:
```bash
aws ecr get-login-password --region eu-west-1 | \
  docker login --username AWS --password-stdin \
  135728714831.dkr.ecr.eu-west-1.amazonaws.com
```

ECR tokens are valid for 12 hours. The CI/CD pipeline handles this automatically on every run.

---

## 8. ALB / Ingress Not Provisioning

**Symptom:**
`kubectl get ingress -n spring-petclinic-ireland` shows no ADDRESS after several minutes, or the AWS Load Balancer Controller pod logs show permission errors.

**Common causes:**

**a) IAM policy using wrong action prefix**
The AWS Load Balancer Controller IAM policy must use `elasticloadbalancing:*`, not `elbv2:*`. If you see `AccessDenied` for `elbv2:` actions in the controller logs, the policy is wrong.

**b) IRSA annotation missing or incorrect**
The controller's service account must have the correct `eks.amazonaws.com/role-arn` annotation pointing to the LBC IAM role.

**Diagnosis:**
```bash
# Check controller pod logs
kubectl logs -n kube-system \
  $(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller \
    -o jsonpath='{.items[0].metadata.name}') --tail=50

# Check ingress events
kubectl describe ingress -n spring-petclinic-ireland
```

**Fix:**
If the IAM policy is wrong, update it via Terraform (`terraform/ingress/irsa.tf`) and re-apply. Do not edit the policy manually — Terraform will overwrite the change.

---

## 9. MySQL Schema Not Initialised

**Symptom:**
`customers-service`, `vets-service`, or `visits-service` start successfully but API calls return empty results or SQL errors. The application logs may show `Table 'petclinic_customers.owners' doesn't exist`.

**Root Cause:**
The Spring PetClinic SQL initialisation scripts target a single `petclinic` database. This deployment uses three separate databases (`petclinic_customers`, `petclinic_vets`, `petclinic_visits`). The schema must be initialised manually on first deployment.

**Fix:**
Apply the database initialisation job:
```bash
kubectl apply -f k8s/db-schema-init-job.yaml -n spring-petclinic-ireland

# Wait for completion
kubectl wait --for=condition=complete job/db-schema-init \
  -n spring-petclinic-ireland --timeout=120s

# Check logs if it fails
kubectl logs job/db-schema-init -n spring-petclinic-ireland
```

This job only needs to be run once per fresh RDS instance. Do not re-run it on an existing populated database.

---

## 10. GenAI Service Non-Functional

**Symptom:**
The AI chatbot in the PetClinic UI does not respond. The `genai-service` logs show one of the following:
- `HTTP 401 Unauthorized` — invalid or expired API key
- `HTTP 429 Too Many Requests` — valid key but account has exceeded its quota or has no billing credit

**Root Cause:**
The `openai-secret` Kubernetes secret is configured with `OPENAI_API_KEY=demo`. The `demo` key was referenced in the upstream Spring PetClinic README but is no longer accepted by OpenAI.

**Impact:**
All other PetClinic functionality (owners, pets, vets, visits) is unaffected. Only the AI chatbot is non-functional.

**Workaround:**
If a valid OpenAI API key is available, update the secret:
```bash
kubectl delete secret openai-secret -n spring-petclinic-ireland
kubectl create secret generic openai-secret \
  --from-literal=OPENAI_API_KEY=<valid-key> \
  -n spring-petclinic-ireland

kubectl rollout restart deployment/genai-service -n spring-petclinic-ireland
```

If no key is available, accept this as a known limitation. The rest of the application is fully operational.

---

## 11. kubectl: Wrong Context or No Access

**Symptom:**
`kubectl` commands fail with `error: You must be logged in to the server` or connect to the wrong cluster.

**Fix:**
Update your kubeconfig to point to the EKS cluster:
```bash
aws eks update-kubeconfig \
  --name spring-petclinic-ireland-eks \
  --region eu-west-1
```

Verify the correct context is active:
```bash
kubectl config current-context
# Expected: arn:aws:eks:eu-west-1:135728714831:cluster/spring-petclinic-ireland-eks
```

---

## 12. Monitoring Stack Destroyed by Terraform

**Symptom:**
Grafana, Prometheus, or Zipkin pods are missing from the `monitoring` namespace after a `terraform apply`.

**Root Cause:**
Running `terraform apply` without `-target` flags can destroy and recreate Helm releases if state has drifted. The monitoring Helm releases (`kube-prometheus-stack`, `zipkin`) are managed by Terraform in `terraform/monitoring/`.

**Fix:**
Re-apply the monitoring module:
```bash
cd terraform/
# Apply CRDs first (ServiceMonitor must exist before the rest)
terraform apply -auto-approve \
  -target=module.monitoring.helm_release.kube_prometheus_stack

# Then apply the full monitoring module
terraform apply -auto-approve -target=module.monitoring
```

**Note:** After monitoring is re-deployed, `ServiceMonitor` resources are recreated and Prometheus resumes scraping all services automatically. No service restarts are required.

The public-access Ingress for Grafana/Prometheus/Zipkin lives in `k8s/monitoring-ingress.yaml` (not in Terraform). If the `monitoring` namespace was destroyed and recreated, re-apply it:

```bash
kubectl apply -f k8s/monitoring-ingress.yaml
```

---

## 13. Monitoring Public URLs Returning 404

**Symptom:**
`http://<alb-dns>/grafana`, `/prometheus`, or `/zipkin` returns 404, or the monitoring Ingress shows no ADDRESS:

```bash
kubectl get ingress -n monitoring
# monitoring-ingress   aws-load-balancer-controller   *      <none>      80
```

**Root Cause:**
The monitoring Ingress shares the application ALB through `alb.ingress.kubernetes.io/group.name: spring-petclinic`. Both `petclinic-ingress` (in `spring-petclinic-ireland`) and `monitoring-ingress` (in `monitoring`) must declare the **same** `group.name`, and the AWS Load Balancer Controller must have permission to read Ingresses across namespaces. A common failure mode is the monitoring Ingress being applied to the wrong namespace, missing the group annotation, or the controller being too old to support IngressGroup.

**Diagnosis:**
```bash
# Confirm both Ingresses are in the same group
kubectl get ingress -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\t"}{.metadata.annotations.alb\.ingress\.kubernetes\.io/group\.name}{"\n"}{end}'

# Check AWS LB Controller logs for IngressGroup errors
kubectl logs -n kube-system \
  $(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller \
    -o jsonpath='{.items[0].metadata.name}') --tail=100 | grep -i "group\|monitoring-ingress"

# Confirm the backend services exist on the expected ports
kubectl get svc -n monitoring kube-prometheus-stack-grafana kube-prometheus-stack-prometheus zipkin
```

**Fix:**

1. Re-apply the monitoring Ingress in the correct namespace:
```bash
kubectl apply -f k8s/monitoring-ingress.yaml
```

2. If the ALB has no listener rule for `/grafana`/`/prometheus`/`/zipkin`, force the controller to reconcile by editing any annotation on either Ingress (e.g. bump `group.order`).

3. If service names/ports drift (e.g. Helm chart upgrade renames `kube-prometheus-stack-grafana`), update `k8s/monitoring-ingress.yaml` to match `kubectl get svc -n monitoring`.

---

## 14. Zipkin Traces Not Appearing

**Symptom:**
The Zipkin UI loads at `http://<alb-dns>/zipkin` but **Run Query** returns no traces, even after exercising the application.

**Root Cause:**
All eight services export traces via two environment variables set in each Deployment manifest:

```yaml
- name: MANAGEMENT_TRACING_EXPORT_ZIPKIN_ENDPOINT
  value: "http://zipkin.monitoring.svc.cluster.local:9411/api/v2/spans"
- name: MANAGEMENT_TRACING_SAMPLING_PROBABILITY
  value: "1.0"
```

Traces will not appear if (a) the env vars are missing on a Deployment, (b) the Zipkin Service is not reachable across namespaces, (c) sampling probability is `0`, or (d) the service is on an image that predates the env-var addition (commit `b60287a`).

**Diagnosis:**
```bash
# Confirm both env vars are present on every Deployment
for svc in config-server discovery-server api-gateway customers-service \
           vets-service visits-service genai-service admin-server; do
  echo "== $svc =="
  kubectl get deploy $svc -n spring-petclinic-ireland \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="MANAGEMENT_TRACING_EXPORT_ZIPKIN_ENDPOINT")].value}{"\n"}'
done

# From an application pod, confirm Zipkin is reachable
kubectl exec -n spring-petclinic-ireland deploy/api-gateway -- \
  curl -sf -o /dev/null -w "%{http_code}\n" \
  http://zipkin.monitoring.svc.cluster.local:9411/health

# Tail Zipkin to confirm spans are arriving
kubectl logs -n monitoring -l app.kubernetes.io/name=zipkin --tail=50
```

**Fix:**

- If env vars are missing on any service, re-apply that Deployment (`kubectl apply -f k8s/<service>/deployment.yaml`).
- If the curl above returns non-200, the Zipkin Service is missing or in the wrong namespace. Verify with `kubectl get svc zipkin -n monitoring`.
- If pods are running an old image, re-run the **Build and Push PetClinic Images to ECR** pipeline and then `kubectl rollout restart deployment/<svc> -n spring-petclinic-ireland`.
- For production, lower `MANAGEMENT_TRACING_SAMPLING_PROBABILITY` from `1.0` to e.g. `0.1` to reduce trace volume — but for diagnosing missing traces, keep it at `1.0`.

---

## 15. General Diagnostic Commands

```bash
# All pods in the application namespace
kubectl get pods -n spring-petclinic-ireland

# All pods in the monitoring namespace
kubectl get pods -n monitoring

# Pod logs (live)
kubectl logs -f deployment/<service-name> -n spring-petclinic-ireland

# Pod logs (previous crash)
kubectl logs deployment/<service-name> -n spring-petclinic-ireland --previous

# Describe a pod (events, resource usage, probe status)
kubectl describe pod <pod-name> -n spring-petclinic-ireland

# Check resource usage (requires metrics-server)
kubectl top pods -n spring-petclinic-ireland
kubectl top nodes

# Check HPA status
kubectl get hpa -n spring-petclinic-ireland

# Check ingress and ALB address
kubectl get ingress -n spring-petclinic-ireland

# Check all services
kubectl get svc -n spring-petclinic-ireland

# Health check via api-gateway (replace with your ALB DNS)
curl http://k8s-springpetclinic-13affa3dfe-92745873.eu-west-1.elb.amazonaws.com/actuator/health

# Monitoring tools — primary access via shared ALB (see Section 13):
#   http://<alb-dns>/grafana     (admin / MyStrongPassword123)
#   http://<alb-dns>/prometheus
#   http://<alb-dns>/zipkin
#
# Fallback: port-forward when the ALB or monitoring-ingress is broken.
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
kubectl port-forward svc/zipkin 9411:9411 -n monitoring
kubectl port-forward svc/kube-prometheus-stack-alertmanager 9093:9093 -n monitoring
```

---

*Deployment Team | Spring PetClinic EKS Deployment | May 2026*
