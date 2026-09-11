#!/bin/bash
set -uxo pipefail

APP_PORT=$(cat /etc/appointments/app_port)
HEALTH_CHECK_PATH=$(cat /etc/appointments/health_check_path)

for i in $(seq 1 10); do
  if curl -fs "http://localhost:${APP_PORT}${HEALTH_CHECK_PATH}" > /dev/null; then
    echo "Health check passed"
    exit 0
  fi
  sleep 5
done

echo "Health check failed after retries"
exit 1
