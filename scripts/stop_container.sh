#!/bin/bash
set -uxo pipefail

# Runs against the *previous* revision at this lifecycle event (that's
# how CodeDeploy's ApplicationStop works), so this must not assume
# anything about the new revision — just stop whatever is running.
docker stop appointments-app 2>/dev/null
docker rm appointments-app 2>/dev/null

exit 0
