# Cloud-Native Appointment Scheduler Platform

## Business Case and Architecture Overview

---

## Executive Summary

AnyCompany Web Consultancy was contracted to build and deploy a production-grade appointment scheduling application for a hair salon client. The solution required transforming an incomplete Django application into a fully automated, cloud-native platform capable of reliable deployments, automated quality enforcement, and zero-downtime updates.

The delivered solution runs on Amazon EKS, backed by Amazon RDS and DynamoDB, deployed through a fully automated AWS CI/CD pipeline. Every code change is automatically tested, containerized, and deployed — with full rollback capability — without any manual intervention.

---

## Business Problem

### Client Pain Points

- No reliable appointment booking system — appointments managed manually
- Customer dissatisfaction from double-bookings and scheduling errors
- No visibility into available appointment slots
- No system to broadcast salon announcements to customers
- Manual deployment processes prone to human error

### Technical Debt Inherited

- Incomplete codebase left by a departed senior developer
- Unit test coverage at 98% — untested code paths in production logic
- Application running only on local SQLite — not suitable for multi-user access
- No containerization, no CI/CD, no cloud deployment

---

## Solution Delivered

### Application Features

- Real-time appointment slot availability with automatic conflict detection
- Hairdresser selection with service-level filtering
- Dynamic salon announcements powered by Amazon DynamoDB
- Available slot count displayed to customers before booking

### Infrastructure Delivered

| Component | Service | Purpose |
|-----------|---------|---------|
| Compute | Amazon EKS | Containerized application, 2 replicas |
| Database | Amazon RDS MySQL | Appointment and scheduling data |
| NoSQL | Amazon DynamoDB | Real-time salon announcements |
| Container Registry | Amazon ECR | Versioned Docker image storage |
| Load Balancer | AWS ALB | Traffic routing, health checks |
| CI/CD | AWS CodePipeline + CodeBuild | Automated test, build, deploy |
| Source Control | AWS CodeCommit | Code versioning and pipeline trigger |

### Quality Metrics Achieved

| Metric | Before | After |
|--------|--------|-------|
| Test Coverage | 98% | **100%** |
| Pylint Code Quality | Unknown | **10.00 / 10** |
| Deployment Process | Manual | **Fully Automated** |
| Rollback Capability | None | **< 5 minutes** |
| Database | SQLite (local only) | **Amazon RDS MySQL (multi-user)** |
| Infrastructure | None | **Production-grade EKS** |

---

## Platform Architecture

### System Architecture

```
Users
  │
  ▼
Application Load Balancer
  │
  ▼
Amazon EKS Cluster
  │
  ├─ Django Pod (replica 1)
  └─ Django Pod (replica 2)
  │
  ├─ Amazon RDS MySQL (appointments data)
  └─ Amazon DynamoDB (announcements)
```

### CI/CD Pipeline Architecture

```
Git Push
  │
  ▼
AWS CodePipeline
  │
  ▼
CodeBuild: UnitTest
  │
  ▼
CodeBuild: BuildImage
  │
  ▼
Docker → Amazon ECR
  │
  ▼
CodeBuild: DeployPods
  │
  ▼
EKS Deployment (live in < 60 seconds)
```

---

## Technical Architecture

### CI/CD Pipeline Design

```
Developer pushes code
│
▼
AWS CodeCommit (main branch)
│
▼ (automatic trigger)
AWS CodePipeline
│
┌────┴────────────────────────────────┐
│                                     │
▼                                     │
CodeBuild: UnitTest                       │
- Pylint score must = 10.00/10            │
- Coverage must = 100%                    │
- If either fails → pipeline stops        │
│                                     │
▼                                     │
CodeBuild: BuildImage                     │
- Docker image built                      │
- Tagged: latest, staging, commit SHA     │
- Pushed to Amazon ECR                    │
│                                     │
▼                                     │
CodeBuild: DeployPods                     │
- kubectl apply to EKS cluster            │
- ALB DNS name output                     │
- App live in < 60 seconds                │
│                                     │
└─────────────────────────────────────┘
```

### Security Design Decisions

**IAM Token Authentication for RDS**

Database connections use AWS IAM token authentication — no passwords are stored in environment variables, code, or configuration files. Tokens are generated per-session and expire automatically.

**SSL/TLS for All Database Connections**

All RDS connections enforce SSL/TLS using the AWS CA certificate bundle. Data in transit is always encrypted.

**No Hardcoded Credentials Anywhere**

All sensitive values (database host, username, region) are passed as environment variables injected at runtime by the EKS service account, which uses an IAM role with least-privilege permissions.

**Separate Service Account**

The `appointments-sa` Kubernetes service account is bound to an IAM role with only the permissions the application needs — no over-privileged access.

---

## Non-Functional Requirements

### Availability
- Application deployed with 2 replicas behind ALB
- Health checks ensure traffic only routes to healthy pods
- Zero-downtime deployments via rolling updates

### Scalability
- EKS horizontal scaling supported via replica updates
- Stateless application design enables seamless scaling
- RDS and DynamoDB handle increased load independently

### Security
- IAM-based authentication for database access
- TLS encryption for all database traffic
- Least-privilege IAM roles for service accounts
- No credentials stored in code or environment variables

### Deployment Reliability
- CI/CD pipeline enforces code quality gates (Pylint 10/10)
- 100% test coverage requirement before deployment
- Automated rollback capability in under 5 minutes
- Full audit trail via Git commit history

### Performance
- Application responds in < 2 seconds for booking requests
- ALB distributes load across multiple pods
- Database queries optimized with proper indexing

---

## Risk Management

### Rollback Strategy — Two Approaches Implemented

**Approach 1: Kubernetes Rollback (< 2 minutes)**

```bash
kubectl rollout history deployment/appointments-deployment
kubectl rollout undo deployment/appointments-deployment --to-revision=<N>
```

Used when: Infrastructure-level issue, wrong image tag deployed

**Approach 2: Git Revert + Pipeline (< 10 minutes)**

```bash
git revert <bad-commit> --no-edit
git push
# Pipeline automatically redeploys the reverted state
```

Used when: Bad application code reached production, creates auditable history

Both approaches were tested and demonstrated during the project.

### Quality Gates — Automated Enforcement

The pipeline enforces non-negotiable quality standards before any code reaches ECR or EKS:

- Pylint score below 10.00 → pipeline fails, nothing deploys
- Test coverage below 100% → pipeline fails, nothing deploys

This means code quality standards are enforced by infrastructure, not by convention.

---

## Operational Capabilities

### Monitoring and Troubleshooting

```bash
# Real-time pod logs
kubectl logs <pod-name>

# Pod status and events
kubectl describe pod <pod-name>

# Deployment status
kubectl rollout status deployment/appointments-deployment

# ALB target health
aws elbv2 describe-target-health --target-group-arn <arn>
```

### Scaling

The EKS deployment is configured with 2 replicas behind the ALB. Scaling is a single manifest change:

```yaml
spec:
  replicas: 4  # scale up as needed
```

---

## Business Value Delivered

### For the Salon

- Customers can book appointments 24/7 without calling
- Real-time slot availability prevents double-bookings
- Announcements (promotions, closures, holiday hours) update instantly via DynamoDB
- System handles multiple concurrent users reliably on RDS

### For AnyCompany Web Consultancy

- Repeatable, documented deployment process for future clients
- Automated quality enforcement reduces bug escape rate to near zero
- Infrastructure as code — entire system can be reproduced in a new AWS account
- Full audit trail — every deployment is traceable to a specific commit

### Operational Efficiency

- Zero manual deployment steps after initial setup
- New features deployed in minutes, not hours
- Rollback time reduced from hours (manual) to minutes (automated)
- On-call burden reduced — pipeline catches issues before production

---

## Estimated Business Impact

Manual scheduling previously required staff time and caused booking conflicts.

The automated system enables:

- **24/7 appointment booking** — customers book outside business hours
- **Reduced staff workload** — no phone calls for appointment scheduling
- **Improved customer satisfaction** — instant confirmation, no double-bookings
- **Scalable infrastructure** — supports business growth without infrastructure changes
- **Operational cost savings** — automated deployments reduce DevOps overhead

---

## Conclusion

The delivered platform transforms a manually managed, error-prone process into a reliable, automated system. The hair salon client now has a professional booking platform with enterprise-grade reliability. AnyCompany Web Consultancy has a proven, repeatable cloud-native deployment blueprint built entirely on AWS-native services.

Every design decision — IAM auth, multi-tag ECR strategy, separate buildspec files, dual rollback approach — was made with production reliability and operational simplicity as the primary goals.

---

*Emmanuel Fornah — Cloud Developer, AnyCompany Web Consultancy*

*AWS Cloud Institute — Cloud Developer Capstone Project*
