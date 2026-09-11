#!/bin/bash
set -euo pipefail

# Runs at `terraform apply` time (local-exec), not on any EC2 instance.
# Delivers scripts/bootstrap_rds_iam_user.py to a running app instance via
# SSM and executes it in a throwaway container from whatever image ECR
# most recently received — deliberately not `docker exec` into a
# long-lived "appointments-app" container, since at bootstrap time (or
# after a failed deployment gets cleaned up) no such container may exist
# anywhere in the fleet yet. Targets by tag (Key=Name), not a specific
# instance ID, since the ASG's instance set isn't something Terraform
# tracks individually — any instance with Docker + the pull permission
# can run this.

SCRIPT_B64=$(base64 -w0 "${script_path}")

COMMANDS=$(cat <<EOF
[
  "echo $SCRIPT_B64 | base64 -d > /tmp/bootstrap_rds_iam_user.py",
  "IMAGE_TAG=\$(aws ecr describe-images --repository-name ${ecr_repo_name} --region ${aws_region} --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' --output text)",
  "aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${ecr_registry}",
  "docker pull ${ecr_registry}/${ecr_repo_name}:\$IMAGE_TAG",
  "docker run --rm --entrypoint python3 -v /tmp/bootstrap_rds_iam_user.py:/tmp/bootstrap_rds_iam_user.py:ro -e AWS_REGION=${aws_region} -e MASTER_SECRET_ARN=${master_secret_arn} -e DB_HOST=${db_host} -e DB_NAME=${db_name} -e APP_DB_USER=${app_db_user} ${ecr_registry}/${ecr_repo_name}:\$IMAGE_TAG /tmp/bootstrap_rds_iam_user.py"
]
EOF
)

COMMAND_ID=$(aws ssm send-command \
  --targets "Key=tag:Name,Values=appointments-app" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=$COMMANDS" \
  --profile "${aws_profile}" \
  --query 'Command.CommandId' --output text)

echo "SSM command: $COMMAND_ID"

for i in $(seq 1 30); do
  STATUS=$(aws ssm list-command-invocations --command-id "$COMMAND_ID" --profile "${aws_profile}" --query 'CommandInvocations[0].Status' --output text 2>/dev/null || echo "Pending")
  if [ "$STATUS" = "Success" ] || [ "$STATUS" = "Failed" ] || [ "$STATUS" = "Cancelled" ] || [ "$STATUS" = "TimedOut" ]; then
    break
  fi
  sleep 5
done

echo "Final status: $STATUS"
aws ssm list-command-invocations --command-id "$COMMAND_ID" --profile "${aws_profile}" --details \
  --query 'CommandInvocations[0].CommandPlugins[0].Output' --output text

if [ "$STATUS" != "Success" ]; then
  echo "Bootstrap failed" >&2
  exit 1
fi
