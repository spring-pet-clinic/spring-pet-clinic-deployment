# DevOps Micro-Internship — Final Project Report

**Project Title:** Cloud-Native Deployment of Spring PetClinic Microservices on Amazon EKS
**Submission Date:** May 2026
**Program:** DevOps Micro-Internship

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Project Objectives](#project-objectives)
3. [Team Members](#team-members)
4. [Methodology](#methodology)
5. [Project Timeline](#project-timeline)
6. [Work Completed](#work-completed)
   - [Phase 1: Infrastructure Provisioning](#phase-1-infrastructure-provisioning)
   - [Phase 2: Containerisation & Image Management](#phase-2-containerisation--image-management)
   - [Phase 3: CI/CD Pipeline](#phase-3-cicd-pipeline)
   - [Phase 4: Kubernetes Deployment](#phase-4-kubernetes-deployment)
   - [Phase 5: Monitoring & Observability](#phase-5-monitoring--observability)
   - [Phase 6: Validation & Testing](#phase-6-validation--testing)
   - [Phase 7: Optimisation & Documentation](#phase-7-optimisation--documentation)
7. [Challenges & How They Were Addressed](#challenges--how-they-were-addressed)
8. [Lessons Learned](#lessons-learned)
9. [Conclusion](#conclusion)
10. [References](#references)

---

## Executive Summary

This report documents the planning, execution, and outcomes of the final project for the DevOps Micro-Internship. A team of ten was tasked with deploying the Spring PetClinic Microservices application — a distributed, cloud-native Java application — onto Amazon Elastic Kubernetes Service (EKS) using industry-standard DevOps practices.

The project covered the full deployment lifecycle: cloud infrastructure provisioning, Docker image creation and registry management, automated CI/CD pipelines, Kubernetes orchestration, monitoring, distributed tracing, failure testing, and documentation. Work was organised into 29 user stories spanning six days, from 4 May to 9 May 2026.

---

## Project Objectives

1. Provision a production-grade Kubernetes cluster on Amazon EKS.
2. Containerise all microservices and manage images in Amazon ECR.
3. Implement an automated CI/CD pipeline using GitHub Actions.
4. Deploy all seven microservices to EKS in the correct dependency order.
5. Expose services publicly through an ingress controller with routing rules.
6. Establish monitoring and observability using Prometheus, Grafana, and Zipkin.
7. Validate system stability through inter-service communication tests and failure simulation.
8. Optimise resource usage and produce comprehensive project documentation.

---

## Team Members

| Name | Primary Responsibilities |
|------|--------------------------|
| Mary-Ann Oranekwulu | EKS cluster provisioning, public service exposure |
| Poorva Tumbde | Node group configuration, failure simulation testing |
| Vishal Gore | IAM and access setup, ingress controller, routing rules, troubleshooting guide |
| Suganya Rani | ECR repository creation, initial image push |
| Bukola Baiyewu | Docker image creation for all microservices |
| Vincent | CI pipeline setup, automated image push |
| Venkatesh | EKS pipeline deployment, services 3–4 deployment, service availability validation |
| Sonny Enchill | Reusable pipeline template, initial cluster deployments (config-server, discovery-server, api-gateway — SPCAD-20/21), services 7–8 deployment, inter-service testing, resource optimisation |
| Iamrahul | Prometheus and Grafana deployment |
| Olu | Services 5–6 deployment, distributed tracing |
| Sridevi Parimi | Monitoring dashboards, architecture diagram, deployment guide |

---

## Methodology

The project adopted an **Agile-inspired sprint approach**, with user stories created and tracked in **Jira** using the `SPCAD-` prefix (SPCAD-9 through SPCAD-37). Each story had a defined assignee, target date, description, acceptance criteria, and explicit dependencies to manage sequencing. A local `sprint-plan.md` mirrors the Jira board as a reference document; Jira remains the source of truth for story status.

All ten team members hold individual IAM users under a shared AWS account, having completed the prerequisite tooling setup (AWS CLI, eksctl, kubectl, Docker, Java 17) during the internship programme.

Work was structured around the following DevOps principles:

- **Infrastructure as Code** — cluster provisioned using Terraform
- **Immutable Artefacts** — Docker images built once, tagged with `github.sha`, and pushed to ECR
- **Pipeline Automation** — two GitHub Actions workflows: a main pipeline (`ci-cd.yml`) and a reusable per-service template (`reusable-deploy.yml`)
- **Dependency Enforcement** — Kubernetes `initContainers` poll `/actuator/health` to enforce service startup order at the platform level, preventing crash loops
- **Observability by Default** — Prometheus metrics, Grafana dashboards, and distributed tracing integrated from the start
- **Shift-Left Testing** — images validated locally before being pushed to ECR; inter-service tests run before failure simulation

Dependencies between stories were explicitly modelled to ensure no team member began work on a story before its prerequisites were satisfied.

---

## Project Timeline

| Date | Phase | Key Milestones |
|------|-------|---------------|
| 04 May 2026 | Infrastructure | EKS cluster provisioned, node groups configured, IAM roles set, ECR repos created, base CI pipeline established |
| 05 May 2026 | Containerisation & Initial Deploy | Docker images built and pushed to ECR, automated pipeline push operational, first microservice deployed, ingress controller installed |
| 06 May 2026 | Full Deployment | All 7 services deployed to EKS, routing rules and public endpoints configured, Prometheus deployed, EKS pipeline deployment automated |
| 07 May 2026 | Observability & Validation | Grafana dashboards live, distributed tracing active, all service endpoints validated, inter-service communication confirmed |
| 08 May 2026 | Testing & Optimisation | Failure scenarios simulated, resource limits configured, architecture diagram produced |
| 09 May 2026 | Documentation | Deployment guide and troubleshooting guide completed |

---

## Work Completed

### Phase 1: Infrastructure Provisioning

The foundation of the deployment was a managed Kubernetes cluster on **Amazon EKS**, provisioned via Terraform by Sridevi Parimi using the team's deployment repository (`spring-pet-clinic/spring-pet-clinic-deployment`). The cluster — named `spring-petclinic-ireland-eks`, running Kubernetes 1.30 in region `eu-west-1` (Ireland) — is `ACTIVE` with endpoint `https://6B73DD6738B3D73151446923FBF28E22.yl4.eu-west-1.eks.amazonaws.com`.

The cluster was provisioned with three dedicated node groups: 2× `t3.small` (infra), 2× `t3.medium` (application services), and 1× `t3.small` (monitoring) — 5 nodes total, sized appropriately for the full PetClinic stack. The VPC, NAT gateway, OIDC provider, RDS instance, ECR repositories, and IAM roles were all provisioned as part of the same Terraform apply (11 May 2026).

In parallel, Suganya Rani created dedicated **Amazon ECR repositories** for each microservice, providing a private, managed registry for all container images.

---

### Phase 2: Containerisation & Image Management

Bukola Baiyewu built **Docker images** for all seven microservices using the project's Maven build system (`./mvnw clean install -P buildDocker`). Images were validated locally before Suganya Rani performed the initial push to ECR, tagging each image appropriately for traceability.

---

### Phase 3: CI/CD Pipeline

Vincent set up the **base GitHub Actions pipeline**, triggering on every push to the main branch with a successful build as the acceptance gate. The pipeline was extended to automate image pushes to ECR.

Venkatesh built the **EKS deployment stage**, connecting the pipeline to the cluster via `kubectl` to apply Kubernetes manifests automatically on each build. Sonny Enchill produced a **reusable workflow template**, allowing each microservice to plug into the same pipeline logic without duplicating configuration — reducing maintenance overhead and enforcing consistency across all services.

---

### Phase 4: Kubernetes Deployment

Kubernetes manifests were prepared for all eight services under `k8s/`, each containing a `Deployment` and a `ClusterIP Service`. Ports were assigned consistently: `config-server` (8888), `discovery-server` (8761), `api-gateway` (8080), `customers-service` (8081), `visits-service` (8082), `vets-service` (8083), `genai-service` (8084), and `admin-server` (9090).

To enforce the mandatory startup order at the platform level, `initContainers` were configured on each service to poll the `/actuator/health` endpoint of their dependency before the main container is permitted to start. This prevents crash loops without relying solely on restart policies. All pods were also configured with `readinessProbe` and `livenessProbe` health checks, and baseline resource requests and limits were set on every container.

Services were deployed in strict dependency order:

1. `config-server` — must be healthy before all others
2. `discovery-server` — Eureka registry required by all services
3. `api-gateway` — routes client traffic
4. `customers-service`, `vets-service`, `visits-service` — domain services backed by MySQL on RDS
5. `genai-service` — Spring AI chatbot, requiring an OpenAI API key injected as a Kubernetes Secret (`openai-secret`)
6. `admin-server` — Spring Boot Admin monitoring UI

All eight pods are confirmed `1/1 Running` in namespace `spring-petclinic-ireland` on cluster `spring-petclinic-ireland-eks`.

**Ingress and public exposure (SPCAD-24/25/26):** The AWS Load Balancer Controller was installed via Helm using an IRSA-backed IAM role. An `Ingress` resource was applied routing all external traffic to `api-gateway` on port 8080. The ALB controller provisioned an Application Load Balancer automatically. The application is publicly accessible at:

`http://k8s-springpetclinic-13affa3dfe-92745873.eu-west-1.elb.amazonaws.com`

A prerequisite fix was required before DB services could start: the RDS instance hosts a single MySQL server but the microservices connect to three separate databases (`petclinic_customers`, `petclinic_vets`, `petclinic_visits`). A Kubernetes Job (`db-schema-init-job.yaml`) was created to initialise the correct schema and seed data against each database from within the cluster.

---

### Phase 5: Monitoring & Observability

The full observability stack was deployed to a dedicated `monitoring` namespace via Terraform-managed Helm releases.

**Prometheus and Grafana (SPCAD-27/28/29):** The `kube-prometheus-stack` Helm chart was installed, deploying Prometheus, Grafana, Alertmanager, and node exporters. Prometheus is configured with custom scrape jobs for all eight microservices, targeting each service's `/actuator/prometheus` endpoint. `ServiceMonitor` resources were created for each service to enable automatic discovery. Grafana is connected to the Prometheus datasource, with the Spring PetClinic metrics dashboard available for import from `observability/grafana/dashboards/petclinic-dashboard.json`. Credentials: `admin` / `MyStrongPassword123`.

**Distributed tracing (SPCAD-30):** Zipkin was deployed via its Helm chart into the `monitoring` namespace. All microservices are configured with Micrometer tracing and report spans to Zipkin, enabling end-to-end trace visualisation across service boundaries.

All monitoring pods are confirmed `Running` in the `monitoring` namespace. Tools are accessible via `kubectl port-forward`:

| Tool | Command | URL |
|------|---------|-----|
| Grafana | `kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring` | `http://localhost:3000` |
| Prometheus | `kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring` | `http://localhost:9090` |
| Zipkin | `kubectl port-forward svc/zipkin 9411:9411 -n monitoring` | `http://localhost:9411/zipkin/` |

---

### Phase 6: Validation & Testing

Sonny Enchill validated all service endpoints (SPCAD-31), confirming each returned `{"status":"UP"}` via the api-gateway on 12 May 2026. All eight pods were confirmed `1/1 Running` in namespace `spring-petclinic-ireland`.

Sonny Enchill tested **inter-service communication** (SPCAD-32) by exercising full read/write flows through the api-gateway: listing owners and vets, creating a new owner, and creating a visit record — all via Eureka-based service discovery. Data flowed correctly across customers-service, vets-service, and visits-service.

A prerequisite fix was required: the MySQL schema and seed data had not been initialised on startup because the SQL scripts target a single `petclinic` database while the deployment uses separate databases (`petclinic_customers`, `petclinic_vets`, `petclinic_visits`). A Kubernetes Job (`db-schema-init-job.yaml`) was created to run the correct schema and seed scripts against each database directly from within the cluster.

Failure simulation (SPCAD-33) is pending.

---

### Phase 7: Optimisation & Documentation

**Resource optimisation (SPCAD-34):** Resource requests and limits were differentiated based on service role rather than applying a uniform configuration. Infrastructure services (`config-server`, `discovery-server`, `admin-server`) — which have no JPA or database connections and carry a lighter JVM footprint — were reduced to `100m`/`300m` CPU and `384Mi`/`768Mi` memory. The `api-gateway` CPU limit was raised to `600m` to accommodate reactive routing spikes under load. Database-backed services (`customers`, `vets`, `visits`) and `genai-service` retain `200m`/`500m` CPU and `512Mi`/`1Gi` memory, which the Spring Boot buildpack JVM memory calculator requires to maintain a healthy heap.

Horizontal Pod Autoscalers (HPA) were configured for the four traffic-facing services using the `autoscaling/v2` API: `api-gateway` scales between 1 and 3 replicas, while `customers-service`, `vets-service`, and `visits-service` each scale between 1 and 2 replicas, all triggered at 60% average CPU utilisation. `metrics-server` was installed on the cluster as a prerequisite for HPA and `kubectl top`.

**Deployment guide (SPCAD-36):** A comprehensive step-by-step deployment guide has been produced, covering prerequisites, GitHub Actions secrets setup, Terraform infrastructure provisioning, Kubernetes secrets, manifest apply order, ingress setup, monitoring access, end-to-end smoke testing, teardown, and known operational traps.

**Troubleshooting guide (SPCAD-37):** A comprehensive 13-section troubleshooting guide has been produced, covering RDS connectivity, pod crash loops, service startup ordering, Terraform state issues, GitHub Actions auth, ECR token expiry, ALB provisioning failures, MySQL schema initialisation, GenAI service errors, kubectl context, monitoring stack recovery, and a general diagnostic command reference.

**Architecture diagram (SPCAD-35):** Pending.

---

## Challenges & How They Were Addressed

| Challenge | How It Was Addressed |
|-----------|---------------------|
| Tight dependency chain on May 4 | Team coordinated closely; EKS and ECR stories were started simultaneously since they had no inter-dependency |
| Spring Boot 4 / Spring Cloud Oakwood compatibility | The forked repository already included fixes (e.g. Zipkin migration to `spring-boot-starter-zipkin`) |
| GenAI service requiring an API key | The `demo` key referenced in the upstream README is no longer accepted by OpenAI. Accepted as a known limitation; all other application functionality is fully working |
| MySQL schema initialisation | The application SQL scripts target a single `petclinic` database while the deployment uses three separate databases. A Kubernetes Job was created to run the correct scripts against each database |
| RDS connectivity after Terraform apply | EKS worker nodes use a Terraform-managed security group (`sg-026585940528ba244`) that was not initially included in the RDS security group ingress rules. The rule was codified in Terraform using `eks_node_security_group_id` to prevent it being lost on future applies |
| IAM policy errors blocking ALB provisioning | The AWS Load Balancer Controller IAM policy used invalid `elbv2:*` action prefixes. Corrected to `elasticloadbalancing:*` with a wildcard to avoid incremental permission failures |
| Heavy workload on Vincent (pipeline stories across 3 days) | Stories were coordinated sequentially; SPCAD-20 and SPCAD-21 were taken over by backup Sonny Enchill to unblock the deployment chain |

---

## Lessons Learned

1. **Dependency management is critical in microservices deployments.** The startup order of `config-server` → `discovery-server` → all others is non-negotiable; incorrect ordering caused pod crash loops during early testing.

2. **Reusable pipeline templates pay off immediately.** Building a parameterised GitHub Actions template (SPCAD-18) eliminated duplication across seven service pipelines and made future changes a single-file update.

3. **Observability should be deployed early, not last.** Having Prometheus running before all services were deployed would have provided visibility into resource usage during the deployment phase itself.

4. **Secrets management needs a dedicated story.** Handling the GenAI service's OpenAI API key was not initially in the plan and required ad-hoc coordination — a dedicated secrets management story would have made this smoother.

5. **Liveness and readiness probes should be configured on all pods from the start.** All service manifests include `/actuator/health` probes upfront to ensure stable restarts and rolling deployments. Full failure simulation (SPCAD-33) is pending.

6. **Collaboration across dependency boundaries requires clear communication.** Stories with cross-assignee dependencies (e.g. SPCAD-16 depending on both Vincent's SPCAD-15 and Suganya's SPCAD-14) required explicit handoff signals to avoid blocking.

---

## Conclusion

All eight microservices are containerised, stored in Amazon ECR, and confirmed `1/1 Running` on the EKS cluster (`spring-petclinic-ireland-eks`, eu-west-1). The application is publicly accessible at `http://k8s-springpetclinic-13affa3dfe-92745873.eu-west-1.elb.amazonaws.com`. The GitHub Actions CI/CD pipeline builds and pushes images automatically on every commit to the `dev` branch.

The full observability stack — Prometheus, Grafana, Alertmanager, and Zipkin — is running in the `monitoring` namespace with scrape targets configured for all eight services. Inter-service communication has been validated end-to-end through the api-gateway. Resource limits have been right-sized per service role, and horizontal pod autoscaling is active on the four traffic-facing services.

Remaining outstanding work: failure simulation (SPCAD-33) and architecture diagram (SPCAD-35).

---

## References

- Spring PetClinic Microservices Repository: https://github.com/spring-petclinic/spring-petclinic-microservices
- Spring Cloud Documentation: https://spring.io/projects/spring-cloud
- Amazon EKS Documentation: https://docs.aws.amazon.com/eks/
- Amazon ECR Documentation: https://docs.aws.amazon.com/ecr/
- GitHub Actions Documentation: https://docs.github.com/en/actions
- Prometheus Documentation: https://prometheus.io/docs/
- Grafana Documentation: https://grafana.com/docs/
- Zipkin Documentation: https://zipkin.io/
- Resilience4j Documentation: https://resilience4j.readme.io/
- Kubernetes Documentation: https://kubernetes.io/docs/

---

*Submitted in partial fulfilment of the DevOps Micro-Internship programme | May 2026*
