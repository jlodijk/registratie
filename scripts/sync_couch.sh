#!/usr/bin/env bash
set -euo pipefail

# Sync alle CouchDB databases tussen couchdb1 en couchdb2 in beide richtingen.
# Gebruikt admin basic auth uit environment (.env) en _replicate endpoint.

COUCHDB1_URL=${COUCHDB1_URL:-http://couchdb1:5984}
COUCHDB2_URL=${COUCHDB2_URL:-http://couchdb2:5984}

COUCHDB_USER=${COUCHDB_USER:-admin}
COUCHDB_PASSWORD=${COUCHDB_PASSWORD:-}
COUCHDB1_PASSWORD=${COUCHDB1_PASSWORD:-$COUCHDB_PASSWORD}
COUCHDB2_PASSWORD=${COUCHDB2_PASSWORD:-$COUCHDB_PASSWORD}

AUTH1="${COUCHDB_USER}:${COUCHDB1_PASSWORD}"
AUTH2="${COUCHDB_USER}:${COUCHDB2_PASSWORD}"

echo "Bron 1: ${COUCHDB1_URL} (user ${COUCHDB_USER})"
echo "Bron 2: ${COUCHDB2_URL} (user ${COUCHDB_USER})"

DBS1=$(curl -s -u "$AUTH1" "${COUCHDB1_URL}/_all_dbs")
DBS2=$(curl -s -u "$AUTH2" "${COUCHDB2_URL}/_all_dbs")

INCLUDE_USERS=${INCLUDE_USERS:-false}

DBS=$(DBS1="$DBS1" DBS2="$DBS2" INCLUDE_USERS="$INCLUDE_USERS" python3 - <<'PY'
import os, json
dbs1 = json.loads(os.environ["DBS1"] or "[]")
dbs2 = json.loads(os.environ["DBS2"] or "[]")
skip = {"_users", "_replicator", "_global_changes"}
if os.environ.get("INCLUDE_USERS", "false").lower() in ("1", "true", "yes"):
    skip.remove("_users")
union = [d for d in sorted(set(dbs1 + dbs2)) if d not in skip]
print(" ".join(union))
PY
)

if [ -z "$DBS" ]; then
  echo "Geen databases gevonden om te synchroniseren."
  exit 0
fi

echo "Synchroniseer databases: $DBS"

replicate() {
  local src_url=$1 src_auth=$2 tgt_url=$3 tgt_auth=$4 db=$5
  local src_url_auth tgt_url_auth
  src_url_auth=${src_url/http:\/\//http:\/\/${src_auth}@}
  tgt_url_auth=${tgt_url/http:\/\//http:\/\/${tgt_auth}@}

  echo "→ ${db}: ${src_url} -> ${tgt_url}"
  resp=$(curl -s -u "$src_auth" \
    -H "Content-Type: application/json" \
    -X POST "${src_url}/_replicate" \
    -d "{\"source\":\"${src_url_auth}/${db}\",\"target\":\"${tgt_url_auth}/${db}\",\"create_target\":true}")
  [ -n "$resp" ] && echo "   response: $resp" || echo "   response: (empty)"
}

for db in $DBS; do
  replicate "$COUCHDB1_URL" "$AUTH1" "$COUCHDB2_URL" "$AUTH2" "$db"
  replicate "$COUCHDB2_URL" "$AUTH2" "$COUCHDB1_URL" "$AUTH1" "$db"
done

echo "Klaar."
