#!/usr/bin/env bash
###############################################################################
# dashboard-setup.sh · lab-only tuning of the Wazuh app in the dashboard.
#
# ENSFácil reads the agent inventory from wazuh-monitoring-*, which the Wazuh
# app writes every 900 s by default. In the lab that means waiting up to
# 15 minutes before a new agent shows up in the panel, so it is lowered to
# 60 s. The setting needs a dashboard restart. Idempotent.
###############################################################################
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

# Changing app settings needs a Wazuh API session (wz-token cookie); the host
# id is the one in config/wazuh_dashboard/wazuh.yml.
HOST_ID="$(sed -n 's/^  - \([0-9]*\):.*/\1/p' "$LAB_DIR/config/wazuh_dashboard/wazuh.yml" | head -1)"
curl -sk -c "$JAR" -b "$JAR" -u "admin:$INDEXER_PASSWORD" -H 'osd-xsrf: true' -H 'Content-Type: application/json' \
  -X POST "$URL/api/login" -d "{\"idHost\":\"$HOST_ID\",\"force\":true}" -o /dev/null
curl -sk -c "$JAR" -b "$JAR" -u "admin:$INDEXER_PASSWORD" -H 'osd-xsrf: true' -H 'Content-Type: application/json' \
  -H "Cookie: wz-api=$HOST_ID" -X PUT "$URL/utils/configuration" \
  -d "{\"wazuh.monitoring.frequency\":$FREQUENCY}" | grep -q '"updatedConfiguration"' \
  || die "could not change wazuh.monitoring.frequency"

docker restart "${COMPOSE_PROJECT_NAME}-wazuh.dashboard-1" >/dev/null
wait_for "dashboard after restart" 400 sh -c "curl -sk -u 'admin:$INDEXER_PASSWORD' $URL/api/status | grep -q '\"state\":\"green\"'"
