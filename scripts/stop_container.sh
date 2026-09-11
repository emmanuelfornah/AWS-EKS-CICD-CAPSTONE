#!/bin/bash
set -uxo pipefail

# Runs against the *previous* revision at this lifecycle event (that's
# how CodeDeploy's ApplicationStop works), so this must not assume
# anything about the new revision — just stop whatever is running.
# `|| true` on each line makes "this command is allowed to fail" explicit
# (first deploy, or a prior failed deploy left nothing running) instead
# of relying on `-e` being absent from the `set` line above.
docker stop appointments-app 2>/dev/null || true
docker rm appointments-app 2>/dev/null || true
