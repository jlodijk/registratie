#!/usr/bin/env bash
set -euo pipefail

# Deployment script for registratie on Hetzner
# Runs on the server as user 'deploy' (with sudo for service restart)

# Path on the server; for Hetzner deploy user
APP_DIR="/home/deploy/registratie"
# Use 'master' because the repository default branch is master
BRANCH="master"
SERVICE_NAME="registratie"

export MIX_ENV=prod

# Load environment variables (prefer system env, then /opt/registratie/.env.prod, then ~/.env.prod)
ENV_FILE="/opt/registratie/.env.prod"
[ -f "$ENV_FILE" ] || ENV_FILE="$HOME/.env.prod"
if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
  export SECRET_KEY_BASE COUCHDB_USERNAME COUCHDB_PASSWORD COUCHDB_URL
  echo "[deploy] Using COUCHDB_USERNAME=${COUCHDB_USERNAME:-unset}"
else
  echo "[deploy] ERROR: no env file found"
  exit 1
fi

# Ensure Dotenvy sees the env file in the app dir
cp "$ENV_FILE" "$APP_DIR/.env"

# Ensure asdf (or other toolchain) shims are on PATH when running non-login
# Load shell environment so asdf or other toolchains are available
export HOME="/home/deploy"
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
[ -f "$HOME/.profile" ] && . "$HOME/.profile"
if [ -f "$HOME/.asdf/asdf.sh" ]; then
  # shellcheck disable=SC1090
  . "$HOME/.asdf/asdf.sh"
fi
export PATH="$HOME/.asdf/shims:$HOME/.asdf/bin:/usr/local/lib/elixir/bin:/usr/lib/elixir/bin:/usr/local/bin:/usr/bin:/bin:/snap/bin:$PATH"

if ! command -v mix >/dev/null 2>&1; then
  echo "[deploy] ERROR: mix not found in PATH. PATH=$PATH"
  exit 1
fi

echo "[deploy] Switching to $APP_DIR"
cd "$APP_DIR"

echo "[deploy] Fetching latest code ($BRANCH)"
git fetch --tags origin "$BRANCH"
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"

echo "[deploy] Installing deps"
mix deps.get --only prod

echo "[deploy] Compiling"
mix compile

echo "[deploy] Building assets"
mix assets.deploy

echo "[deploy] Running migrations"
mix ecto.migrate

echo "[deploy] Restarting service $SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

echo "[deploy] Done"
