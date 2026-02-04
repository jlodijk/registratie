#!/usr/bin/env bash
set -euo pipefail

REMOTE_USER="deploy"
REMOTE_HOST="116.203.242.75"
REMOTE_PATH="/home/deploy/"
BRANCH="master"

# Push lokale wijzigingen
git push origin "$BRANCH"

# Pull + deploy op de server
ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ${REMOTE_PATH} && git pull origin ${BRANCH} && ./deploy.sh"
