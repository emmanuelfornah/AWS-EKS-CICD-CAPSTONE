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

| Full Coverage Report | CodeBuild Succeeded |
|---|---|
| ![Full](screenshots/07_coverage_full_report.png) | ![Build](screenshots/09_codebuild_succeeded.png) |

| Pipeline — All Stages Green |
|---|
| ![Pipeline](screenshots/10_pipeline_all_stages_green.png) |

### Troubleshooting & Rollbacks

| Pod Error Logs — Region Misconfiguration | Region Fix Deployed Successfully |
|---|---|
| ![Logs](screenshots/11_kubectl_pod_error_logs.png) | ![Fix](screenshots/12_region_fix_deployed.png) |

| Application — Orange Background | Pipeline — Orange Build Succeeded |
|---|---|
| ![Orange](screenshots/13_app_orange_background.png) | ![Pipeline](screenshots/14_pipeline_orange_build_succeeded.png) |

| Application — Cadetblue Background | Rollback to Orange |
|---|---|
| ![Cadetblue](screenshots/15_app_cadetblue_background.png) | ![Rollback](screenshots/16_rollback_to_orange.png) |

---

## 🏗️ Architecture

### Complete CI/CD Platform

![Full Architecture](screenshots/architecture.png)

### Architecture Evolution

| Stage | Diagram | What Was Built |
|-------|---------|----------------|
| Stage 1: Dev Environment | ![](screenshots/stage1_architecture.png) | IDE + CodeCommit + local SQLite |
| Stage 2: DynamoDB Added | ![](screenshots/stage2_architecture.png) | Announcements from DynamoDB |
| Stage 3: CI Pipeline | ![](screenshots/stage3_architecture.png) | CodeBuild + ECR + automated tests |
| Stage 4: Full Platform | ![](screenshots/stage4_architecture.png) | EKS + ALB + DeployPods automation |

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

## ✅ What Was Built

- Cloned the project, ran locally, understood the codebase in AWS Code Editor
- Improved unit test coverage from **98% → 100% across 161 statements**, Pylint 10/10
- Built the hairdresser selection feature — UI template + Django backend
- Integrated **Amazon DynamoDB** for salon announcements with full mock unit tests
- Configured **AWS CodeBuild** to automate Pylint and coverage on every commit
- Created **AWS CodePipeline** — Source → UnitTest stage triggering on every push
- Migrated from SQLite to **Amazon RDS MySQL** with IAM authentication and SSL/TLS
- Containerized the application with **Docker**, tested against live RDS
- Pushed container image to **Amazon ECR** with 3 versioned tags
- Deployed the application to **Amazon EKS** cluster using Kubernetes manifests
- Diagnosed a broken pod deployment by reading **kubectl logs** — fixed region misconfiguration
- Performed **Kubernetes rollbacks** using `kubectl rollout undo` across revision history
- Replaced Classic Load Balancer with **Application Load Balancer** using Helm
- Added **DeployPods CodeBuild stage** — completing the full automated CI/CD pipeline
- Demonstrated **git revert rollback** — pipeline auto-redeployed the previous version

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

*AWS Cloud Institute Capstone — Full cloud-native development and deployment lifecycle on AWS.*
