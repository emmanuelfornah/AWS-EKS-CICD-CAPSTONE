# ☁️ Cloud-Native Appointment Scheduler — AWS EKS CI/CD Capstone

![Python](https://img.shields.io/badge/Python-3.11-blue?logo=python)
![Django](https://img.shields.io/badge/Django-5.0-green?logo=django)
![Docker](https://img.shields.io/badge/Docker-Containerized-blue?logo=docker)
![AWS EKS](https://img.shields.io/badge/AWS-EKS-orange?logo=amazon-aws)
![CodePipeline](https://img.shields.io/badge/CI%2FCD-CodePipeline-purple?logo=amazon-aws)
![Coverage](https://img.shields.io/badge/Coverage-100%25-brightgreen)
![Pylint](https://img.shields.io/badge/Pylint-10.00%2F10-brightgreen)

> A production-grade cloud-native appointment scheduling platform built with **Python/Django**, containerized with **Docker**, and deployed to **Amazon EKS** through a fully automated **CI/CD pipeline**.

Every `git push` automatically:
- runs linting and unit tests
- builds and version-tags a Docker container
- pushes the image to Amazon ECR
- deploys the application to Kubernetes on Amazon EKS

**Zero manual deployment steps. Every change passes automated quality gates before reaching production.**

---

## 📸 Screenshots

### Development & CI/CD Setup

| IDE Workspace | CodeCommit Repository |
|---|---|
| ![IDE](screenshots/01_ide_workspace_setup.png) | ![Repo](screenshots/02_codecommit_repository.png) |

| Application — Initial Launch | Appointment Timeslot Selection |
|---|---|
| ![App](screenshots/03_application_initial_launch.png) | ![Timeslots](screenshots/04_appointment_timeslot_selection.png) |

### Test Coverage & Pipeline

| 100% Test Coverage | Coverage — Views Module |
|---|---|
| ![100%](screenshots/05_unit_test_coverage_100.png) | ![Views](screenshots/06_coverage_views_module.png) |

| Full Coverage Report | Template Update Push |
|---|---|
| ![Full](screenshots/07_coverage_full_report.png) | ![Push](screenshots/08_template_update_push.png) |

| CodeBuild Succeeded | Pipeline — All Stages Green |
|---|---|
| ![Build](screenshots/09_codebuild_succeeded.png) | ![Pipeline](screenshots/10_pipeline_all_stages_green.png) |

### Troubleshooting & Rollbacks

| Pod Error Logs — Region Misconfiguration | Region Fix Deployed Successfully |
|---|---|
| ![Logs](screenshots/11_kubectl_pod_error_logs.png) | ![Fix](screenshots/12_region_fix_deployed.png) |

| Orange Template Update | Pipeline — Orange Build Succeeded |
|---|---|
| ![Orange](screenshots/13_base_template_orange_update.png) | ![Pipeline](screenshots/14_pipeline_orange_build_succeeded.png) |

| Application — Orange Background | Pipeline — Cadetblue Build Succeeded |
|---|---|
| ![Orange App](screenshots/15_app_orange_background.png) | ![Cadetblue Pipeline](screenshots/16_pipeline_cadetblue_build_succeeded.png) |

| Application — Cadetblue Background | Rollout History |
|---|---|
| ![Cadetblue](screenshots/17_app_cadetblue_background.png) | ![History](screenshots/18_rollout_history.png) |

| Rollback to Orange |
|---|
| ![Rollback](screenshots/19_rollback_to_orange.png) |

### ALB Migration & EKS Cluster

| EKS Cluster Verified | ALB Controller Installed |
|---|---|
| ![EKS](screenshots/20_eks_cluster_verified.png) | ![ALB](screenshots/21_alb_controller_installed.png) |

| Helm Installed |
|---|
| ![Helm](screenshots/22_helm_installed.png) |

### Deploy Pipeline — Automated EKS Deployment

| Deploy Buildspec Configuration | Application Running via ALB |
|---|---|
| ![Buildspec](screenshots/deploy-pipeline/01-deploy-buildspec-configuration.png) | ![Running](screenshots/deploy-pipeline/02-application-running-verification.png) |

| Pipeline — All 4 Stages Succeeded | UI Theme Update — Cadetblue |
|---|---|
| ![Pipeline](screenshots/deploy-pipeline/03-pipeline-all-stages-succeeded.png) | ![Theme](screenshots/deploy-pipeline/04-ui-theme-update-cadetblue.png) |

| Cadetblue Deployed | Git Revert — Rollback to Original |
|---|---|
| ![Deployed](screenshots/deploy-pipeline/05-ui-cadetblue-deployed.png) | ![Revert](screenshots/deploy-pipeline/06-git-revert-rollback-to-original.png) |

---

## 🏗️ Architecture

### Complete CI/CD Platform

![Full Architecture](screenshots/architecture/cicd-pipeline-eks-architecture.png)

The architecture illustrates the end-to-end CI/CD workflow:

1. **Developer** pushes code changes from the AWS Code Editor IDE
2. **AWS CodeCommit** hosts the private Git repository and triggers the pipeline on every push
3. **AWS CodePipeline** orchestrates the full CI/CD workflow across four stages:
   - **UnitTest** — CodeBuild runs Pylint (10/10) and coverage (100%) as a quality gate
   - **BuildImage** — CodeBuild builds the Docker container and pushes to Amazon ECR with three version tags
   - **DeployPods** — CodeBuild runs `kubectl apply` to deploy the application onto Amazon EKS
4. **Amazon ECR** stores and manages the versioned Docker container images
5. **Amazon EKS** runs the Kubernetes cluster with rolling deployments and ALB ingress
6. **Application Frontend** is served through the AWS Application Load Balancer and connects to:
   - **Amazon RDS (MySQL)** — appointment bookings, hairdressers, and services via IAM token auth + SSL/TLS
   - **Amazon DynamoDB** — salon announcements with schema-free, instant updates

---

## ⚙️ System Workflow

```
Developer
│
▼
git push
│
▼
AWS CodeCommit
│
▼
AWS CodePipeline
│
├─ UnitTest Stage ──────────────── Pylint (10/10 required)
│                                  Coverage (100% required)
│                                  ❌ Fails here → nothing deploys
│
├─ BuildImage Stage ────────────── Docker build
│                                  Image tagged: latest + staging + commit SHA
│                                  Push to Amazon ECR
│
└─ DeployPods Stage ────────────── kubectl apply
                                   Deploy to Amazon EKS
         │
         ▼
App exposed via AWS Application Load Balancer
Backed by Amazon RDS (MySQL) + DynamoDB
```

---

## 🔄 Automated Deployment Pipeline

```
┌──────────┐   ┌─────────────┐   ┌──────────────┐   ┌────────────┐
│  Source  │──▶│  UnitTest   │──▶│  BuildImage  │──▶│ DeployPods │
│CodeCommit│   │Pylint 10/10 │   │ Docker + ECR │   │ kubectl    │
│          │   │100% coverage│   │   3 tags     │   │   EKS      │
└──────────┘   └─────────────┘   └──────────────┘   └────────────┘
     ❌                  ❌                 ❌
Fail = stop         Fail = stop        Fail = alert
```

---

## 🛠️ Tech Stack

| Category | Technology |
|----------|-----------|
| Language | Python 3.11 |
| Framework | Django 5.0 |
| Relational DB | Amazon RDS MySQL — IAM token auth + SSL/TLS |
| NoSQL DB | Amazon DynamoDB — salon announcements |
| Containerization | Docker |
| Container Registry | Amazon ECR |
| Orchestration | Amazon EKS (Kubernetes) |
| Load Balancer | AWS ALB via Helm + AWS Load Balancer Controller |
| CI/CD | AWS CodePipeline + CodeBuild (3 build stages) |
| Source Control | AWS CodeCommit |
| Testing | Coverage.py 100%, Pylint 10.00/10 |
| IDE | AWS Code Editor (cloud VS Code) |

---

## 📁 Project Structure

```
appointments-app/
├── manage.py
├── Dockerfile
├── requirements-dev.txt
├── local_build.sh
│
├── hairdresser-django/
│   └── settings.py              # Conditional RDS/SQLite config
│
├── appointments/
│   ├── views.py                 # Business logic + DynamoDB + RDS
│   ├── tests.py                 # 100% coverage + mock_scan
│   ├── models.py                # Appointment, Hairdresser, Service
│   └── templates/appointments/
│       ├── index.html           # Booking UI + announcements
│       └── base.html            # Base layout
│
├── buildspecs/
│   ├── buildspec_unittest.yml   # Stage 1: Pylint + coverage
│   ├── buildspec_buildimage.yml # Stage 2: Docker + ECR
│   └── buildspec_deploypods.yml # Stage 3: kubectl EKS
│
└── manifests/
    ├── appointments-deployment.yml
    ├── appointments-service.yml
    └── appointments-ingress.yml  # ALB ingress
```

---

## 🚀 Getting Started

### Local Run (SQLite)

```bash
git clone <repo-url>
cd appointments-app
pip install -r requirements-dev.txt
python manage.py migrate
python manage.py runserver 0.0.0.0:8088
```

### Local Run (RDS)

```bash
export DATABASE_HOST="<rds-endpoint>"
export DATABASE_USER="appointments_web"
export DATABASE_DB_NAME="django_appointments"
export AWS_DEFAULT_REGION="<region>"

python manage.py migrate
python manage.py runserver 0.0.0.0:8088
```

---

## 🧪 Testing

```bash
coverage run --source='.' manage.py test appointments
coverage html        # opens htmlcov/index.html

./local_build.sh     # full Pylint + coverage check
```

| Metric | Result |
|--------|--------|
| Statements Covered | 161 |
| Test Coverage | **100%** |
| Pylint Score | **10.00 / 10** |
| Test Strategy | Unit tests with mocked DynamoDB calls |

---

## 🐳 Docker

```bash
docker build -t appointments-app-container .

docker run -it --rm -p 8088:8088 \
  -e DATABASE_HOST -e DATABASE_USER \
  -e DATABASE_DB_NAME -e AWS_DEFAULT_REGION \
  appointments-app-container

docker tag appointments-app-container:latest \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/containers-image-repository:latest

docker push --all-tags \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/containers-image-repository
```

---

## ☸️ Kubernetes

```bash
kubectl apply -f appointments-app/manifests/.

kubectl get deployments && kubectl get pods

kubectl rollout history deployment/appointments-deployment

kubectl rollout undo deployment/appointments-deployment --to-revision=3

git revert <commit-id> --no-edit && git push   # full pipeline rollback
```

---

## 🧠 Production Engineering Practices

- Zero-downtime rolling deployments on Kubernetes
- IAM token authentication for RDS — no passwords stored anywhere
- SSL/TLS enforced on all RDS connections
- Environment-driven config — SQLite locally, RDS in cloud
- Commit-SHA image tags enable precise, auditable rollbacks
- Dual rollback strategy: `kubectl rollout undo` AND `git revert`
- ALB health checks on all target pods
- Buildspecs split by responsibility — test, build, deploy are fully independent

---

## 🧩 Architecture Decisions

### Why Kubernetes (EKS)?

Kubernetes enables rolling deployments, container orchestration, and horizontal scalability. The deployment strategy ensures new pods start before old ones terminate — enabling zero-downtime releases without any custom scripting.

### Why CodePipeline?

AWS CodePipeline orchestrates the entire CI/CD workflow with clear stage separation (test → build → deploy). Each stage is independently configurable and auditable, making the pipeline fully reproducible across environments.

### Why Multi-Tag Container Images?

Images are tagged with three distinct identifiers:

| Tag | Purpose |
|-----|---------|
| `latest` | Always points to the most recent build |
| `staging-test-image` | Stable reference used in Kubernetes manifests |
| `$CODEBUILD_RESOLVED_SOURCE_VERSION` | Commit SHA — enables rollback to any exact historical build |

This enables both quick rollbacks and precise deployment of historical builds without rebuilding.

### Why RDS + DynamoDB?

The system deliberately separates concerns across two database technologies:

| Data Type | Database | Reason |
|-----------|----------|--------|
| Appointment bookings, hairdressers, services | Amazon RDS MySQL | Relational integrity, transactions, foreign keys |
| Salon announcements, dynamic messaging | Amazon DynamoDB | Schema-free, instant updates, no migrations needed |

Salon staff can update announcements in DynamoDB without any code deployment or database migration.

---

## 🎯 DevOps Skills Demonstrated

| Skill | Evidence |
|-------|---------|
| CI/CD Pipeline Design | 4-stage CodePipeline, fully automated from push to deploy |
| Container Engineering | Multi-tag Docker strategy, ECR lifecycle management |
| Kubernetes Operations | Deployments, Services, Ingress, rollback history |
| Infrastructure as Code | Kubernetes manifests and automated buildspec pipelines |
| Cloud Networking | ALB via Helm, subnet tagging, NodePort routing |
| Database Engineering | RDS MySQL + DynamoDB, IAM auth, SSL/TLS |
| Test Automation | 100% coverage + Pylint 10/10 enforced as pipeline gate |
| Troubleshooting | kubectl logs diagnosis, bug fix, redeployment in 3 min |
| Rollback Strategy | Both kubectl rollout undo AND git revert demonstrated |
| Security | IAM roles, no hardcoded credentials, SSL everywhere |

---

## ✅ Key Accomplishments

- Achieved **100% test coverage** across 161 statements with **Pylint 10/10** — enforced as automated pipeline gates
- Designed and implemented a **4-stage CI/CD pipeline** (Source → UnitTest → BuildImage → DeployPods) with zero manual intervention
- Integrated **Amazon DynamoDB** for real-time salon announcements with fully mocked unit tests
- Migrated the database layer from SQLite to **Amazon RDS MySQL** with IAM token authentication and SSL/TLS encryption
- Containerized the full application with **Docker** and implemented a **multi-tag versioning strategy** (latest, staging, commit SHA) on Amazon ECR
- Deployed and managed the application on **Amazon EKS** with Kubernetes rolling deployments and health-checked ALB ingress
- Diagnosed and resolved a production pod failure by analyzing **kubectl logs** — identified region misconfiguration and redeployed within minutes
- Implemented **dual rollback capability** — both `kubectl rollout undo` for instant Kubernetes rollback and `git revert` for full pipeline-driven redeployment
- Migrated from Classic Load Balancer to **Application Load Balancer** using Helm and the AWS Load Balancer Controller
- Automated the complete deployment lifecycle — every `git push` triggers quality gates, container builds, and Kubernetes deployment

---

## 🔮 Future Improvements

Potential enhancements for a production deployment:

- **Horizontal Pod Autoscaler** — dynamic scaling based on real-time traffic load
- **Prometheus + Grafana** — observability, dashboards, and alerting stack
- **Blue/Green or Canary deployments** — safer progressive releases with instant cutover
- **AWS Secrets Manager** — centralized, rotatable database credential management
- **Terraform or AWS CDK** — fully reproducible infrastructure provisioning as code
- **Distributed tracing** — AWS X-Ray or OpenTelemetry for request-level visibility
- **Multi-region deployment** — active-active architecture for high availability

---

## 💡 Key Takeaway

This project demonstrates how a traditional web application can be transformed into a fully automated cloud-native platform using AWS-native services. The result is a system where code quality, security, and deployment reliability are enforced by infrastructure — not by convention.

**Every push. Every time. Automatically.**

---

## 👤 Author

**Emmanuel Fornah** — AWS Cloud Developer | DevOps Engineer

[![GitHub](https://img.shields.io/badge/GitHub-emmanuelfornah-black?logo=github)](https://github.com/emmanuelfornah)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue?logo=linkedin)](https://linkedin.com/in/emmanuelfornah)

---

*Full cloud-native development and deployment lifecycle on AWS.*

📄 [Business Case](BUSINESS_CASE.md) · 📘 [Technical Runbook](TECHNICAL_RUNBOOK.md)
