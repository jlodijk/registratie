#!/usr/bin/env bash
set -euo pipefail

REMOTE_USER="deploy"
REMOTE_HOST="116.203.242.75"
REMOTE_PATH="/home/deploy/registratie"
BRANCH="master"
LOCAL_REMOTE="origin"
REMOTE_REMOTE="origin"

# Push lokale wijzigingen
git push "${LOCAL_REMOTE}" "$BRANCH"

# Pull + deploy op de server (deploy.sh staat één niveau hoger)
ssh "${REMOTE_USER}@${REMOTE_HOST}" "\
  cd ${REMOTE_PATH} && \
  git pull ${REMOTE_REMOTE} ${BRANCH} && \
  git clean -fd && \
  cd .. && \
  ./deploy.sh"
