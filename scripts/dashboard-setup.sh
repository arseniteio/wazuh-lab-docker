#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

URL="https://localhost:$DASHBOARD_PORT"
FREQUENCY=60
JAR="$(mktemp)"
trap 'rm -f "$JAR"' EXIT

step "Agent inventory refresh every ${FREQUENCY}s"
CURRENT="$(curl -sk -u "admin:$INDEXER_PASSWORD" -H 'osd-xsrf: true' "$URL/utils/configuration" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["wazuh.monitoring.frequency"])')"
if [ "$CURRENT" = "$FREQUENCY" ]; then
  ok "already ${FREQUENCY}s"
  exit 0
fi

HOST_ID="$(sed -n 's/^  - \([0-9]*\):.*/\1/p' "$LAB_DIR/config/wazuh_dashboard/wazuh.yml" | head -1)"
curl -sk -c "$JAR" -b "$JAR" -u "admin:$INDEXER_PASSWORD" -H 'osd-xsrf: true' -H 'Content-Type: application/json' \
  -X POST "$URL/api/login" -d "{\"idHost\":\"$HOST_ID\",\"force\":true}" -o /dev/null
curl -sk -c "$JAR" -b "$JAR" -u "admin:$INDEXER_PASSWORD" -H 'osd-xsrf: true' -H 'Content-Type: application/json' \
  -H "Cookie: wz-api=$HOST_ID" -X PUT "$URL/utils/configuration" \
  -d "{\"wazuh.monitoring.frequency\":$FREQUENCY}" | grep -q '"updatedConfiguration"' \
  || die "could not change wazuh.monitoring.frequency"

docker restart "${COMPOSE_PROJECT_NAME}-wazuh.dashboard-1" >/dev/null
wait_for "dashboard after restart" 400 sh -c "curl -sk -u 'admin:$INDEXER_PASSWORD' $URL/api/status | grep -q '\"state\":\"green\"'"
