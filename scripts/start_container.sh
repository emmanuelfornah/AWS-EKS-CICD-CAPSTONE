#!/bin/bash
set -euxo pipefail

# Non-secret config was written to /etc/appointments/* by the launch
# template's user-data (infra/templates/user-data.sh.tpl) — reading it
# here instead of hardcoding keeps this script in sync with Terraform
# without duplicating values in two places.
AWS_REGION=$(cat /etc/appointments/aws_region)
SECRET_ARN=$(cat /etc/appointments/app_secret_arn)
DATABASE_HOST=$(cat /etc/appointments/database_host)
DATABASE_USER=$(cat /etc/appointments/db_username)
DATABASE_DB_NAME=$(cat /etc/appointments/db_name)
APP_PORT=$(cat /etc/appointments/app_port)
LOG_GROUP=$(cat /etc/appointments/log_group)

# BuildImage (buildspecs/buildspec_buildimage.yml) writes the resolved
# commit-SHA tag here — the ECR repo is IMMUTABLE, so this is the only
# tag guaranteed to point at exactly the image this pipeline run built.
IMAGE_TAG=$(cat /opt/appointments/image_tag.txt)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region "$AWS_REGION")
REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
IMAGE="$REGISTRY/containers-image-repository:$IMAGE_TAG"

DJANGO_SECRET_KEY=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" --region "$AWS_REGION" \
  --query SecretString --output text \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["DJANGO_SECRET_KEY"])')

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"
docker pull "$IMAGE"

# Nothing else in this deploy flow ever runs migrations - found via a
# real deployment failing with "Table ... doesn't exist" on a freshly
# created RDS instance. manage.py migrate is idempotent (no-op if
# already applied), so running it on every deploy is safe, not just a
# first-time bootstrap step.
docker run --rm \
  -e AWS_DEFAULT_REGION="$AWS_REGION" \
  -e DATABASE_HOST="$DATABASE_HOST" \
  -e DATABASE_USER="$DATABASE_USER" \
  -e DATABASE_DB_NAME="$DATABASE_DB_NAME" \
  -e DJANGO_SECRET_KEY="$DJANGO_SECRET_KEY" \
  "$IMAGE" manage.py migrate --noinput

docker run -d --name appointments-app \
  --restart unless-stopped \
  -p "${APP_PORT}:${APP_PORT}" \
  --log-driver awslogs \
  --log-opt awslogs-region="$AWS_REGION" \
  --log-opt awslogs-group="$LOG_GROUP" \
  --log-opt awslogs-create-group=false \
  -e AWS_DEFAULT_REGION="$AWS_REGION" \
  -e DATABASE_HOST="$DATABASE_HOST" \
  -e DATABASE_USER="$DATABASE_USER" \
  -e DATABASE_DB_NAME="$DATABASE_DB_NAME" \
  -e DJANGO_SECRET_KEY="$DJANGO_SECRET_KEY" \
  "$IMAGE"
