# Spring PetClinic — EKS Deployment

This repository contains the Infrastructure as Code (Terraform), Kubernetes manifests, and CI/CD workflows that deploy the Spring PetClinic microservices application to **Amazon EKS** in `eu-west-1` (Ireland). The application source lives in a separate repo ([`spring-petclinic-microservices`](https://github.com/spring-pet-clinic/spring-petclinic-microservices)); this repo is everything *around* the application.

## Live URLs

| Surface | URL | Notes |
|---------|-----|-------|
| Application | `http://k8s-springpetclinic-13affa3dfe-92745873.eu-west-1.elb.amazonaws.com` | Public ALB → `api-gateway` |
| Grafana | `http://<alb-dns>/grafana` | `admin` / `MyStrongPassword123` |
| Prometheus | `http://<alb-dns>/prometheus` | No auth — restrict before prod |
| Zipkin | `http://<alb-dns>/zipkin` | No auth — distributed traces |

Grafana, Prometheus, and Zipkin are served off the **same ALB** as the application via the `alb.ingress.kubernetes.io/group.name: spring-petclinic` annotation on `k8s/monitoring-ingress.yaml`.

## Architecture at a Glance

- **Compute:** EKS 1.30 cluster `spring-petclinic-ireland-eks`, three node groups (infra `t3.small × 2`, app `t3.medium × 2`, monitoring `t3.small × 1`)
- **Data:** MySQL 8.4 on RDS, one instance hosting three logical databases (`petclinic_customers`, `petclinic_vets`, `petclinic_visits`); credentials in AWS Secrets Manager
- **Registry:** 8 ECR repos, one per microservice, tagged with `<git-sha>` and `latest`
- **Networking:** VPC with public/private/DB subnets, NAT Gateway, AWS Load Balancer Controller via IRSA
- **Observability:** kube-prometheus-stack (Prometheus, Grafana, Alertmanager) and Zipkin in the `monitoring` namespace; all 8 services export traces via `MANAGEMENT_TRACING_EXPORT_ZIPKIN_ENDPOINT`
- **Services (8):** `config-server`, `discovery-server`, `api-gateway`, `customers-service`, `vets-service`, `visits-service`, `genai-service`, `admin-server`
- **Startup ordering:** `initContainers` poll `/actuator/health` on upstream dependencies, enforcing the strict `config-server → discovery-server → all others` boot order
- **Autoscaling:** HPA on the four traffic-facing services (`api-gateway`, customers/vets/visits) triggered at 60% CPU

## Quick Start

```bash
# 1. Point kubectl at the cluster
aws eks update-kubeconfig --name spring-petclinic-ireland-eks --region eu-west-1

# 2. Verify the deployment is healthy
kubectl get pods -n spring-petclinic-ireland   # expect 8× 1/1 Running
kubectl get pods -n monitoring                 # expect Prometheus / Grafana / Zipkin Running

# 3. Hit the app
curl http://k8s-springpetclinic-13affa3dfe-92745873.eu-west-1.elb.amazonaws.com/
```

For a fresh end-to-end deploy (Terraform → secrets → manifests → ingress → monitoring → smoke test), follow [docs/deployment-guide.md](docs/deployment-guide.md).

## Documentation

| Doc | Audience | When to read it |
|-----|----------|----------------|
| [docs/deployment-guide.md](docs/deployment-guide.md) | Operators | Deploying from scratch or after a teardown |
| [docs/troubleshooting-guide.md](docs/troubleshooting-guide.md) | On-call | Pod crash loops, ALB 404s, missing traces, Terraform locks |
| [docs/spring-petclinic-eks-deployment-report.md](docs/spring-petclinic-eks-deployment-report.md) | Stakeholders | Project scope, phases, team roles, lessons learned |

Each doc is also available as a `.docx` next to its `.md` for non-technical readers.

## Repository Layout

```text
spring-pet-clinic-deployment/
├── .github/workflows/                 # CI/CD
│   ├── infra.yml                      # Terraform infra pipeline
│   ├── build-and-push.yml             # Build & push 8 images to ECR
│   └── reusable-deploy.yml            # Per-service deploy template
├── terraform/                         # Infrastructure as Code (calls modules)
│   ├── main.tf                        # Root — wires modules together
│   ├── networking/                    # VPC, subnets, NAT, security groups
│   ├── ecr/                           # 8 ECR repos
│   ├── eks/                           # Cluster, 3 node groups, OIDC, IRSA
│   ├── rds/                           # MySQL 8.4 + Secrets Manager
│   ├── monitoring/                    # kube-prometheus-stack + Zipkin (Helm)
│   └── ingress/                       # AWS Load Balancer Controller (Helm)
├── k8s/                               # Kubernetes manifests
│   ├── namespace.yaml
│   ├── ingress.yaml                   # App Ingress (ALB)
│   ├── monitoring-ingress.yaml        # Grafana / Prometheus / Zipkin on shared ALB
│   ├── hpa.yaml                       # 4 HPAs
│   ├── db-schema-init-job.yaml        # One-shot MySQL schema bootstrap
│   ├── config-server/                 # Per-service Deployment + Service
│   ├── discovery-server/
│   ├── api-gateway/
│   ├── customers-service/
│   ├── vets-service/
│   ├── visits-service/
│   ├── genai-service/
│   └── admin-server/
├── observability/
│   ├── prometheus/values.yaml         # Helm values overrides
│   └── grafana/dashboards/
│       └── petclinic-dashboard.json   # Importable Grafana dashboard
└── docs/                              # See "Documentation" above
```

## CI/CD Pipelines

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `infra.yml` | Manual (`workflow_dispatch`) | Apply Terraform — networking → ECR → EKS → RDS → monitoring → ingress |
| `build-and-push.yml` | Push to `dev` or `main` | Build all 8 Docker images via Spring Boot buildpack, push to ECR tagged `<git-sha>` + `latest` |
| `reusable-deploy.yml` | Called by other workflows | Parameterised per-service `kubectl apply` + rollout status |

All pipelines authenticate to AWS via **OIDC** through `AWS_ROLE_ARN`; no static IAM credentials are stored. Required GitHub secrets: `AWS_ROLE_ARN`, `AWS_ACCOUNT_ID`, `AWS_REGION`, `CLUSTER_NAME`, `NAMESPACE`.

## Team

DevOps Micro-Internship cohort, May 2026.

| Name | Primary Responsibilities |
|------|--------------------------|
| Mary-Ann Oranekwulu | EKS cluster provisioning, public service exposure |
| Poorva Tumbde | Node group configuration, failure simulation testing |
| Vishal Gore | IAM and access setup, ingress controller, routing rules, troubleshooting guide |
| Suganya Rani Balasundaram| ECR repository creation, initial image push |
| Bukola Baiyewu | Docker image creation for all microservices |
| Kleber Vincent | CI pipeline setup, Services 1–2 deployment automated image push |
| Venkatesh Gangavarapu | EKS pipeline deployment, services 3–4 deployment, service availability validation |
| Sonny Enchill | Reusable pipeline template, initial cluster deployments (config-server, discovery-server, api-gateway), services 7–8 deployment, inter-service testing, resource optimisation |
| Olu F.R.J| Services 5–6 deployment, distributed tracing |
| Rahul Patel | Monitoring dashboards, Observability Documentation and troubleshooting guide|
| Sridevi Parimi | Prometheus and Grafana deployment, Monitoring Ingress | Architecture diagram, deployment guide |

Full project narrative and per-phase contributions: [docs/spring-petclinic-eks-deployment-report.md](docs/spring-petclinic-eks-deployment-report.md).

## Mentors & Acknowledgements

| Name | Role |
|------|------|
| Bhupendra Bhati | Co-Mentor, Group 3, DMI Cohort 2 |
| Pravin Mishra | Director, DMI Cohort 2 |

With thanks to our mentors for their guidance and review throughout the project.
