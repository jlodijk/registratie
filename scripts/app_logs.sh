#!/usr/bin/env bash
set -euo pipefail

# Show logs for the running app container (works for both compose names)

# Prefer explicit container_name from docker-compose.yml
if docker ps --format '{{.Names}}' | grep -q '^registratie_app$'; then
  target="registratie_app"
# Fallback to compose default naming (e.g. registratie-app-1)
elif docker ps --filter "label=com.docker.compose.service=app" --format '{{.Names}}' | head -n1 | grep -q '.'; then
  target="$(docker ps --filter "label=com.docker.compose.service=app" --format '{{.Names}}' | head -n1)"
else
  echo "No running app container found (service 'app')."
  exit 1
fi

docker logs "$@" "$target"
