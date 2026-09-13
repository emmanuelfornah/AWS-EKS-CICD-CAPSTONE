# Technical Runbook — Cloud-Native Appointment Scheduler

## Operations & Deployment Guide

---

## Runbook Contents

1. [Purpose](#purpose)
2. [System Overview](#system-overview)
3. [AWS Resources Reference](#aws-resources-reference)
4. [Build Pipeline Configuration](#build-pipeline-configuration)
5. [Deployment Mechanics — CodeDeploy Blue/Green](#deployment-mechanics--codedeploy-bluegreen)
6. [Day-to-Day Operations](#day-to-day-operations)
7. [Incident Response](#incident-response-quick-start)
8. [Rollback Procedures](#rollback-procedures)
9. [Troubleshooting](#troubleshooting-common-issues)
10. [Image Tag Strategy](#image-tag-strategy)
11. [Environment Variables](#environment-variables)
12. [Historical — EKS Phase Operations](#historical--eks-phase-operations)

---

## Purpose

This runbook documents the operational procedures for deploying,
maintaining, and troubleshooting the Cloud-Native Appointment Scheduler
platform **as it runs today** — EC2, CodeDeploy blue/green, GitHub-sourced
CodePipeline. It is intended for platform engineers and DevOps operators
responsible for CI/CD pipeline execution and production maintenance.

The platform was originally built and operated on Amazon EKS. That phase
is preserved as a [historical appendix](#historical--eks-phase-operations)
rather than deleted — it's real, evidenced work, just not what's currently
live. Everything above that section describes current reality.

---

## System Overview

```
User Traffic
    ↓
Route 53 (appointments.emmanuelfornah.com)
    ↓
Application Load Balancer (ACM/TLS)
    ↓
EC2 Auto Scaling Group (CodeDeploy-managed, blue/green)
    ↓
Application Container (Docker)
    ↓
Amazon RDS MySQL (appointments data, IAM auth)
Amazon DynamoDB (announcements)
```

**CI/CD Pipeline Flow:**
```
GitHub Push → CodePipeline (CodeStarSourceConnection) → CodeBuild (UnitTest)
  → CodeBuild (BuildImage, ARM64) → ECR → CodeDeploy (blue/green to EC2)
```

---

## AWS Resources Reference

| Resource | Name / Value |
|----------|--------------|
| ECR Repository | `containers-image-repository` (immutable tags) |
| CodePipeline | `appointments-pipeline` |
| CodeBuild — Unit Tests | `appointments-unittest` |
| CodeBuild — Image Build | `appointments-buildimage` (ARM_CONTAINER, Graviton) |
| CodeDeploy Application | see `infra/codedeploy.tf` |
| CodeDeploy Deployment Group | blue/green, `COPY_AUTO_SCALING_GROUP` |
| RDS Instance | see `infra/rds.tf` — MySQL, IAM auth enabled |
| RDS App User | dedicated IAM-auth user (`var.app_db_username`), distinct from the master account |
| DynamoDB Table | salon announcements table |
| EC2 Auto Scaling Group | **not statically named** — CodeDeploy deletes and recreates it on every deployment (`CodeDeploy_<app>-<deployment-id>`); see note below |
| Access | AWS Systems Manager Session Manager only — no SSH, no bastion |

**Why there's no fixed ASG name:** CodeDeploy's `COPY_AUTO_SCALING_GROUP`
blue/green model doesn't scale the original ASG to zero after a
deployment — it deletes it outright and hands live traffic to a new,
differently-named ASG it creates. Don't `grep` for a static ASG name in
scripts or alarms; find the current one with:

```bash
aws autoscaling describe-auto-scaling-groups \
  --query "AutoScalingGroups[?contains(AutoScalingGroupName, 'CodeDeploy')].AutoScalingGroupName"
```

---

## Build Pipeline Configuration

### buildspecs/buildspec_unittest.yml

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      python: 3.11
    commands:
      - pip3 install -r requirements-dev.txt
  build:
    commands:
      - pylint --load-plugins pylint_django --django-settings-module=hairdresser_django.settings --ignore=migrations appointments/
      - coverage run --source='.' manage.py test appointments
      - coverage xml

reports:
  UnitTests:
    files: ['unittests.xml']
  NewCoverage:
    files: ['coverage.xml']
    file-format: COBERTURAXML
```

### buildspecs/buildspec_buildimage.yml

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      - AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
      - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
  build:
    commands:
      - docker build -t appointments-app-container .
      # ECR repo is IMMUTABLE — only the commit-SHA tag is used, since
      # it's the one tag that unambiguously identifies this exact build.
      - docker tag appointments-app-container:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/containers-image-repository:${CODEBUILD_RESOLVED_SOURCE_VERSION}
  post_build:
    commands:
      - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/containers-image-repository:${CODEBUILD_RESOLVED_SOURCE_VERSION}
      - echo -n "${CODEBUILD_RESOLVED_SOURCE_VERSION}" > image_tag.txt

artifacts:
  files: [appspec.yml, image_tag.txt, "scripts/**/*"]
```

Note the environment: `ARM_CONTAINER` /
`aws/codebuild/amazonlinux2-aarch64-standard:3.0`, not the default
`LINUX_CONTAINER`. The EC2 fleet runs Graviton (t4g); building natively on
ARM here avoids `buildx`/QEMU cross-compilation and the "exec format
error" a mismatched x86_64 image would produce on boot.

There is no third "DeployPods"-equivalent CodeBuild project. CodePipeline's
**native CodeDeploy action** replaces that stage entirely — it consumes
`appspec.yml` + `scripts/` + `image_tag.txt` straight from the BuildImage
artifact.

---

## Deployment Mechanics — CodeDeploy Blue/Green

### appspec.yml

```yaml
version: 0.0
os: linux
files:
  - source: /
    destination: /opt/appointments
hooks:
  ApplicationStop:
    - location: scripts/stop_container.sh
      timeout: 30
  AfterInstall:
    - location: scripts/start_container.sh
      timeout: 90
  ValidateService:
    - location: scripts/validate_service.sh
      timeout: 60
```

### scripts/start_container.sh (AfterInstall hook)

Reads non-secret config from `/etc/appointments/*` (written by the launch
template's user-data — kept in sync with Terraform, not duplicated),
fetches the Django secret key from Secrets Manager, pulls the exact
commit-SHA-tagged image, **runs `manage.py migrate --noinput` before
starting the app** (idempotent — safe on every deploy, not just the
first), then starts the container with `awslogs` log driver pointed at the
app's CloudWatch log group.

### The bootstrap chicken-and-egg (first deploy only)

A brand-new ASG has no healthy hosts yet, so `DEPLOYMENT_STOP_ON_ALARM`
blocks the very first deployment before it can ever produce a healthy host
to clear the alarm. Fix: temporarily disable the alarm gate for exactly
one bootstrap deployment, then re-enable it immediately after. Every
deployment since the first has the alarm gate active.

---

## Day-to-Day Operations

### Deploy a New Version

```bash
git add .
git commit -m "Describe what changed"
git push
# Pipeline triggers automatically via the GitHub CodeStarSourceConnection
```

Infra-only changes (anything under `infra/`) do **not** trigger a
deploy — the pipeline's V2 trigger excludes `infra/**` via `file_paths`,
since Terraform never touches the running app.

### Check Pipeline Status

```bash
aws codepipeline get-pipeline-state --name appointments-pipeline
```

### Session Into a Running Instance (no SSH)

```bash
aws ssm start-session --target <instance-id>
docker ps
docker logs appointments-app
```

### Get ALB DNS Name

```bash
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[*].[LoadBalancerName,DNSName]' \
  --output table
```

---

## Incident Response Quick Start

**1. Check the live deployment's status**
```bash
aws deploy get-deployment --deployment-id <id>
```

**2. Find the current ASG and check instance health**
```bash
aws autoscaling describe-auto-scaling-groups \
  --query "AutoScalingGroups[?contains(AutoScalingGroupName, 'CodeDeploy')]"
aws elbv2 describe-target-health --target-group-arn <arn>
```

**3. Inspect application logs (SSM session, no SSH)**
```bash
aws ssm start-session --target <instance-id>
docker logs appointments-app
```

**4. If the new revision caused the failure**

Blue/green with `DEPLOYMENT_STOP_ON_ALARM` rolls back automatically on an
unhealthy-hosts alarm. If it hasn't (or the alarm gate was intentionally
disabled), stop the deployment manually:
```bash
aws deploy stop-deployment --deployment-id <id> --auto-rollback-enabled
```

**5. Verify recovery**
```bash
aws elbv2 describe-target-health --target-group-arn <arn>
curl -I https://appointments.emmanuelfornah.com
```

---

## Rollback Procedures

### Option A — Automatic blue/green rollback (fastest)

CodeDeploy holds the previous fleet during the deployment window; a
CloudWatch alarm on unhealthy hosts triggers rollback with no manual step.

### Option B — Git Revert Rollback (auditable, 5-10 min)

```bash
git log --oneline -n 10
git revert <bad-commit-sha> --no-edit
git push   # pipeline auto-rebuilds and redeploys the reverted state
```

### Option C — Retry a specific pipeline execution's Deploy stage

The ECR tag is immutable — re-running a pipeline execution that already
pushed its image once will fail trying to push the same tag again. If the
image is still good and only the Deploy stage needs a retry:

```bash
aws codepipeline retry-stage-execution \
  --pipeline-name appointments-pipeline \
  --stage-name Deploy \
  --pipeline-execution-id <execution-id> \
  --retry-mode FAILED_ACTIONS
```

---

## Troubleshooting Common Issues

### CodeDeploy can't provision instances (`IAM_ROLE_PERMISSIONS`)

The error usually names the wrong service. Check CloudTrail for the
actual denied API call before changing IAM — `ec2:RunInstances` called
directly by the CodeDeploy service role is the common real cause, not the
Auto Scaling permissions the error message implies.

### App container can't reach AWS credentials (`NoCredentialsError`)

Check the launch template's `metadata_options.http_put_response_hop_limit`
— must be `2`, not `1`. A request from inside the Docker container to
IMDS crosses one extra network hop beyond the host itself.

### RDS "Access denied" despite correct IAM auth setup

Two independent things to check, in order:
1. Is the app connecting as its own dedicated IAM-auth user, not the RDS
   master account? (`iam_database_authentication_enabled` alone doesn't
   create or configure any MySQL user.)
2. Is `DATABASES["default"]["PORT"]` explicitly set to `3306` in
   `settings.py`? `django_iam_dbauth` defaults the auth-token port to
   PostgreSQL's `5432` if unset — a token signed for the wrong port is
   indistinguishable from a wrong password at the error-message level.

### Pipeline fails at UnitTest stage

```bash
# CodeBuild console → appointments-unittest → latest build → logs
# Common causes: Pylint score dropped, coverage below 100%, import error in tests.py
```

### Pipeline fails at BuildImage stage

```bash
# Common causes: ECR login expired, Dockerfile syntax error,
# wrong CodeBuild environment type (must be ARM_CONTAINER, not LINUX_CONTAINER)
```

### ALB not routing traffic

```bash
aws elbv2 describe-target-groups --query 'TargetGroups[*].[TargetGroupName,TargetType]'
aws elbv2 describe-target-health --target-group-arn <arn>
```

---

## Image Tag Strategy

| Tag | When Updated | Use Case |
|-----|-------------|----------|
| `$CODEBUILD_RESOLVED_SOURCE_VERSION` (commit SHA) | Every pipeline run | The **only** tag used — ECR repo is immutable, so this is the sole unambiguous reference to a specific build |

---

## Environment Variables

### Non-secret config (written to `/etc/appointments/*` by user-data)

| File | Value |
|------|-------|
| `aws_region` | AWS region |
| `app_secret_arn` | Secrets Manager ARN for the Django secret key |
| `database_host` | RDS endpoint |
| `db_username` | App's dedicated IAM-auth DB user |
| `db_name` | Database name |
| `app_port` | Application port |
| `log_group` | CloudWatch log group for container logs |

No secret *values* are ever written to disk — only where to fetch them
from at deploy time.

---

## Historical — EKS Phase Operations

The platform's original delivery ran on Amazon EKS. These procedures are
preserved as evidence of that phase's real operational work (a genuine
production incident diagnosed and fixed, a demonstrated rollback), not
because they apply to the current EC2 deployment.

### Original CI/CD Flow (CodeCommit → EKS)

```
Git Push → CodePipeline → CodeBuild (Test) → CodeBuild (Build) → ECR
  → CodeBuild (Deploy: kubectl apply) → EKS
```

### Original Rollback Options

```bash
# Kubernetes-native rollback (~1-2 min)
kubectl rollout history deployment/appointments-deployment
kubectl rollout undo deployment/appointments-deployment --to-revision=<N>

# Git revert + pipeline (~5-10 min, auditable)
git revert <bad-commit> --no-edit && git push
```

Both were tested and demonstrated during the EKS phase — see
`screenshots/` for the rollout history and rollback evidence.

### Original Incident: Pod Crash from Region Misconfiguration

Diagnosed via `kubectl logs <pod-name>`, root-caused to a region
mismatch, fixed and redeployed within minutes. See
`screenshots/11_kubectl_pod_error_logs.png` and
`screenshots/12_region_fix_deployed.png`.

### Why This Phase Was Torn Down, Not Kept Running

EKS's ~$0.10/hr (~$73/mo) control-plane charge ran regardless of traffic.
For this workload's low, bursty volume, that cost bought no HA guarantee
an ASG + ALB doesn't already provide — see `BUSINESS_CASE.md`'s
"Why We Migrated" section for the full reasoning.

---

*Emmanuel Fornah — AWS Cloud Developer*
