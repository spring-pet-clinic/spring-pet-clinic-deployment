# Petclinic Infrastructure & Deployment

This repository contains the Infrastructure as Code (IaC) and Kubernetes manifests for the Petclinic microservices application.

## Project Structure

```text
petclinic-infra/
├── .github/workflows/          # CI/CD Automation
│   ├── terraform.yml           # Infra provisioning pipeline
│   ├── observability.yml       # Monitoring stack updates
│   ├── deploy-p1.yml           # Config & Discovery servers
│   ├── deploy-p2.yml           # Gateway & Admin servers
│   ├── deploy-p3.yml           # Customers & Visits services
│   └── deploy-p4.yml           # Vets & GenAI services
├── terraform/                  # Infrastructure as Code
│   ├── modules/                # Reusable resource components
│   │   ├── networking/         # VPC, Subnets, IGW, NAT
│   │   ├── cluster/            # EKS/GKE Cluster & IAM Roles
│   │   └── database/           # Managed SQL (RDS/Cloud SQL)
│   │   └── monitoring/         # Install Prometheus, Grafana, and Zipkin using helm
│   └── envs/                   # Environment-specific configurations
│       ├── dev/
│       │   ├── main.tf         # Calls modules for Dev
│       │   ├── variables.tf
│       │   └── terraform.tfvars
│       └── prod/
│           ├── main.tf         # Calls modules for Prod
│           ├── variables.tf
│           └── terraform.tfvars
├── k8s/                        # Kubernetes Manifests
│   ├── shared/                 # Namespace, RBAC, ConfigMaps
│   │   ├── namespace.yaml
│   │   └── global-config.yaml
│   ├── config-server/          # Service manifests (Deployment, SVC, HPA)
│   ├── discovery-server/
│   ├── api-gateway/
│   ├── admin-server/
│   ├── customers-service/
│   ├── visits-service/
│   ├── vets-service/
│   └── genai-service/          # AI-enhanced service component
├── observability/              # Monitoring & Logging (Helm Values)
│   ├── prometheus/
│   │   └── values.yaml
│   ├── grafana/
│   │   └── dashboards/         # JSON dashboard exports
│   │   |  └──petclinic-dashboard.json
├── scripts/                    # Helper scripts for local setup
│   └── setup-local-env.sh
└── README.md
