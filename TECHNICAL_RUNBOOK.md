# Technical Runbook — Cloud-Native Appointment Scheduler

## Operations & Deployment Guide

---

## Runbook Contents

1. [Purpose](#purpose)
2. [System Overview](#system-overview)
3. [AWS Resources Reference](#aws-resources-reference)
4. [Build Pipeline Configuration](#buildspec-files)
5. [Kubernetes Deployment](#kubernetes-manifests-summary)
6. [Day-to-Day Operations](#day-to-day-operations)
7. [Incident Response](#incident-response-quick-start)
8. [Rollback Procedures](#rollback-procedures)
9. [Troubleshooting](#troubleshooting-common-issues)
10. [Image Tag Strategy](#image-tag-strategy)
11. [Environment Variables](#environment-variables)
12. [Deployment Checklist](#github-push--final-checklist)

---

## Purpose

This runbook documents the operational procedures for deploying, maintaining, and troubleshooting the Cloud-Native Appointment Scheduler platform running on AWS.

It is intended for platform engineers and DevOps operators responsible for CI/CD pipeline execution, Kubernetes operations, and production maintenance.

---

## System Overview

The platform runs on AWS using a containerized architecture.

```
User Traffic
    ↓
Application Load Balancer
    ↓
Amazon EKS (Kubernetes Pods)
    ↓
Application Services
    ↓
Amazon RDS (appointments data)
Amazon DynamoDB (announcements)
```

**CI/CD Pipeline Flow:**
```
Git Push → CodePipeline → CodeBuild (Test) → CodeBuild (Build) → ECR → CodeBuild (Deploy) → EKS
```

---

## AWS Resources Reference

| Resource | Name / Value |
|----------|--------------|
| EKS Cluster | `eks-cluster` |
| ECR Repository | `containers-image-repository` |
| CodePipeline | `ApplicationPipeline` |
| CodeBuild — Unit Tests | `UnitTest` |
| CodeBuild — Image Build | `BuildImage` |
| CodeBuild — Deploy | `DeployPods` |
| RDS Instance | `scheduler-db` |
| RDS Database | `django_appointments` |
| RDS User | `appointments_web` |
| DynamoDB Table | `DEV_Announcement` |
| Kubernetes Service Account | `appointments-sa` |
| EKS Subnets | `LabProtectedSubnet`, `LabProtectedSubnet2` |

---

## Buildspec Files

### buildspec_unittest.yml

```yaml
version: 0.2

phases:
  install:
    commands:
      - pip install -r requirements-dev.txt
  build:
    commands:
      - pylint --fail-under=10 appointments/
      - coverage run --source='.' manage.py test appointments
      - coverage report --fail-under=100
```

### buildspec_buildimage.yml

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
      - docker tag appointments-app-container:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/containers-image-repository:latest
      - docker tag appointments-app-container:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/containers-image-repository:staging-test-image
      - docker tag appointments-app-container:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/containers-image-repository:${CODEBUILD_RESOLVED_SOURCE_VERSION}
  post_build:
    commands:
      - docker push --all-tags $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/containers-image-repository
```

### buildspec_deploypods.yml

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      - aws eks update-kubeconfig --name eks-cluster
  build:
    commands:
      - kubectl delete -f manifests/appointments-deployment.yml --ignore-not-found
      - kubectl apply -f manifests/.
      - sleep 30
  post_build:
    commands:
      - aws elbv2 describe-load-balancers --query 'LoadBalancers[*].[DNSName]' --output text
```

---

## Kubernetes Manifests Summary

### appointments-deployment.yml (key fields)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: appointments-deployment
spec:
  replicas: 2
  template:
    metadata:
      annotations:
        kubernetes.io/change-cause: "Description of this deployment"
    spec:
      serviceAccountName: appointments-sa
      containers:
        - name: appointments-container
          image: <ACCOUNT>.dkr.ecr.<REGION>.amazonaws.com/containers-image-repository:staging-test-image
          env:
            - name: DATABASE_HOST
              value: "<RDS-ENDPOINT>"
            - name: DATABASE_USER
              value: "appointments_web"
            - name: DATABASE_DB_NAME
              value: "django_appointments"
            - name: AWS_DEFAULT_REGION
              value: "<REGION>"
```

### appointments-service.yml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: appointments-service
spec:
  type: NodePort
  selector:
    app: appointments
  ports:
    - port: 8088
      targetPort: 8088
```

### appointments-ingress.yml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: appointments-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: appointments-service
                port:
                  number: 8088
```

---

## Day-to-Day Operations

### Deploy a New Version

```bash
# Make code changes
git add .
git commit -m "Describe what changed"
git push

# Pipeline triggers automatically — nothing else needed
```

### Check Pipeline Status

```bash
aws codepipeline get-pipeline-state --name ApplicationPipeline
```

### Check Pod Status

```bash
kubectl get pods
kubectl get deployments
kubectl describe deployment appointments-deployment
```

### View Application Logs

```bash
# Get pod name
kubectl get pods

# View logs
kubectl logs <pod-name>

# Filter for errors
kubectl logs <pod-name> | grep -i "error\|exception\|traceback"

# Follow live logs
kubectl logs -f <pod-name>
```

### Get ALB DNS Name

```bash
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[*].[LoadBalancerName,DNSName]' \
  --output table
```

---

## Incident Response Quick Start

When an incident occurs, follow this sequence:

**1. Check pod health**
```bash
kubectl get pods
```

**2. Check recent deployment**
```bash
kubectl rollout history deployment/appointments-deployment
```

**3. Inspect application logs**
```bash
kubectl logs <pod-name>
```

**4. If deployment caused failure — immediate rollback**
```bash
kubectl rollout undo deployment/appointments-deployment
```

**5. Verify recovery**
```bash
kubectl rollout status deployment/appointments-deployment
kubectl get pods
```

---

## Rollback Procedures

### Option A — Kubernetes Rollback (fastest, 1-2 min)

Use when: Wrong image deployed, pod crash loop, infrastructure issue

```bash
# View revision history
kubectl rollout history deployment/appointments-deployment

# Rollback to previous version
kubectl rollout undo deployment/appointments-deployment

# Rollback to specific revision
kubectl rollout undo deployment/appointments-deployment --to-revision=3

# Verify rollback completed
kubectl rollout status deployment/appointments-deployment
```

### Option B — Git Revert Rollback (auditable, 5-10 min)

Use when: Bad application code in production, want full audit trail

```bash
# Find the bad commit
git log --oneline -n 10

# Revert it (creates new commit)
git revert <bad-commit-sha> --no-edit

# Push — pipeline auto-deploys the reverted state
git push
```

### Option C — ECR Tag Rollback (precise, 5 min)

Use when: Need to deploy exactly a specific past commit

```bash
# Edit appointments-deployment.yml
# Change image tag from 'staging-test-image' to the specific commit SHA
# Example:
#   image: <ACCOUNT>.dkr.ecr.<REGION>.amazonaws.com/containers-image-repository:abc1234

kubectl apply -f manifests/appointments-deployment.yml
kubectl rollout status deployment/appointments-deployment
```

---

## Troubleshooting Common Issues

### Pods in CrashLoopBackOff

```bash
kubectl describe pod <pod-name>   # check Events section
kubectl logs <pod-name>           # check application error

# Common causes:
# - Wrong DATABASE_HOST value
# - Wrong AWS_DEFAULT_REGION value
# - RDS security group not allowing EKS node traffic
```

### Pipeline Fails at UnitTest Stage

```bash
# Go to CodeBuild console → UnitTest project → latest build → logs

# Common causes:
# - Pylint score dropped (code quality issue)
# - New code not tested (coverage below 100%)
# - Import error in tests.py
```

### Pipeline Fails at BuildImage Stage

```bash
# Common causes:
# - ECR login expired (handled by buildspec pre_build)
# - Dockerfile syntax error
# - Missing dependency in requirements-dev.txt
```

### Pipeline Fails at DeployPods Stage

```bash
# Common causes:
# - kubectl not authorized (check CodeBuild IAM role)
# - EKS cluster name mismatch in buildspec
# - Manifest YAML syntax error
```

### ALB Not Routing Traffic

```bash
# Check target group health
aws elbv2 describe-target-groups --query 'TargetGroups[*].[TargetGroupName,TargetType]'

# Check subnet tags
aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/role/elb,Values=1"
# Both LabProtectedSubnet and LabProtectedSubnet2 must appear

# Check ALB controller pods
kubectl get pods -n kube-system | grep aws-load-balancer
```

---

## Image Tag Strategy

| Tag | When Updated | Use Case |
|-----|-------------|----------|
| `latest` | Every pipeline run | Quick reference to newest build |
| `staging-test-image` | Every pipeline run | Stable deployment reference in manifests |
| `$CODEBUILD_RESOLVED_SOURCE_VERSION` | Every pipeline run | Surgical rollback to exact commit |
| `feature-ui-update` | Manual feature releases | Feature-specific version tag |

---

## Environment Variables

### Required for Application (set in deployment manifest)

| Variable | Value |
|----------|-------|
| `DATABASE_HOST` | RDS endpoint URL |
| `DATABASE_USER` | `appointments_web` |
| `DATABASE_DB_NAME` | `django_appointments` |
| `AWS_DEFAULT_REGION` | AWS region (e.g. `us-east-1`) |

### Required in AWS Code Editor (~/.bashrc)

```bash
export AWS_REGION="<your-region>"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_REPO_NAME="containers-image-repository"
```

---

## GitHub Push — Final Checklist

```bash
cd ~/environment/appointments-app

# Clean up build artifacts
rm -rf htmlcov __pycache__ .coverage
find . -name "*.pyc" -delete
find . -name "__pycache__" -type d -exec rm -rf {} +

# Verify screenshots folder exists
ls screenshots/

# Verify all buildspecs are committed
ls buildspecs/
# Expected: buildspec_unittest.yml, buildspec_buildimage.yml, buildspec_deploypods.yml

# Verify manifests are committed
ls manifests/
# Expected: appointments-deployment.yml, appointments-service.yml, appointments-ingress.yml

# Final commit
git add .
git commit -m "Final project — complete cloud-native CI/CD platform on AWS EKS"
git push

# Add GitHub remote and push
git remote add github https://github.com/emmanuelfornah/aws-eks-cicd-capstone.git
git push github main
```

---

*Emmanuel Fornah — AWS Cloud Developer*
