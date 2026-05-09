Reference folder structure, Please feel free to add any files or delete any files that you want and update this folder structure.



petclinic-infra/
├── terraform/
│   ├── networking/        → VPC, subnets, security groups
│   ├── cluster/           → EKS/GKE, node groups, IAM
│   ├── database/          → RDS MySQL
│   └── envs/
│       ├── dev/           → dev tfvars + main.tf
│       └── prod/          → prod tfvars + main.tf
├── k8s/
│   ├── shared/            → namespace.yaml, configmap.yaml (team-owned)
│   ├── config-server/     → Person 1
│   ├── discovery-server/  → Person 1
│   ├── api-gateway/       → Person 2
│   ├── admin-server/      → Person 2
│   ├── customers-service/ → Person 3
│   ├── visits-service/    → Person 3
│   ├── vets-service/      → Person 4
│   └── genai-service/     → Person 4
├── observability/
│   ├── prometheus/values.yaml
│   ├── grafana/dashboards/
│   └── loki/values.yaml
├── .github/workflows/
│   ├── terraform.yml
│   ├── observability.yml
│   ├── deploy-p1.yml      → triggers on k8s/config-server + discovery-server
│   ├── deploy-p2.yml      → triggers on k8s/api-gateway + admin-server
│   ├── deploy-p3.yml      → triggers on k8s/customers-service + visits-service
│   └── deploy-p4.yml      → triggers on k8s/vets-service + genai-service
└── README.md