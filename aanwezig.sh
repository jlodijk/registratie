#!/usr/bin/env bash
set -euo pipefail

# Startup script (Ubuntu) — logs in with hostname + SSID (no BSSID)

SERVER_URL="https://116.203.242.75"
HOSTNAME_VALUE=$(hostname)
SSID_VALUE=$(nmcli -f ACTIVE,SSID dev wifi | awk '$1=="yes"{ $1=""; sub(/^ /, "", $0); print $0 }' | head -n1)

if [[ -z "${SSID_VALUE:-}" ]]; then
  echo "Geen actieve wifi-verbinding gevonden."
  exit 1
fi

ENC_HOST=$(printf '%s' "$HOSTNAME_VALUE" | jq -s -R -r @uri)
ENC_SSID=$(printf '%s' "$SSID_VALUE" | jq -s -R -r @uri)

xdg-open "$SERVER_URL/login?hostname=$ENC_HOST&ssid=$ENC_SSID" >/dev/null 2>&1 &
