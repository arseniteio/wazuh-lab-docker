#!/usr/bin/env bash
###############################################################################
# up.sh · brings the whole lab up, from scratch or on top of a running one.
#
#   make up        (or bash scripts/up.sh)
#
# Steps, each one checked before moving on:
#   1. lab certificates               scripts/certs.sh
#   2. ENSFácil zip                   build/ (built if missing)
#   3. indexer, manager, dashboard    docker compose up
#   4. dashboard tuning + manager     scripts/dashboard-setup.sh, manager-setup.sh
#   5. plugin configuration           scripts/seed.sh
#   6. agent running the runbooks     agent-01 service
###############################################################################
set -euo pipefail
. "$(dirname "$0")/lib.sh"

bash "$LAB_DIR/scripts/certs.sh"

step "ENSFácil plugin $ENSFACIL_VERSION"
ZIP="$LAB_DIR/build/ensfacil-$ENSFACIL_VERSION-osd-2.19.5.zip"
if [ "${REBUILD:-}" = 1 ] || [ ! -f "$ZIP" ]; then
  bash "$LAB_DIR/scripts/build-plugin.sh"
else
  ok "using $ZIP (REBUILD=1 to rebuild)"
fi
cp "$ZIP" "$LAB_DIR/images/dashboard/ensfacil-2.19.5.zip"

step "Building images and starting Wazuh $WAZUH_VERSION"
"${COMPOSE[@]}" build --quiet wazuh.manager wazuh.dashboard agent-01
"${COMPOSE[@]}" up -d wazuh.indexer wazuh.manager wazuh.dashboard

indexer_ok() { ix '_cluster/health' | grep -Eq '"status":"(green|yellow)"'; }
wait_for "indexer" 300 indexer_ok
wait_for "manager (analysisd)" 300 docker exec "$MGR" sh -c '/var/ossec/bin/wazuh-control status | grep -q "wazuh-analysisd is running"'
wait_for "dashboard" 400 sh -c "curl -sk -u 'admin:$INDEXER_PASSWORD' https://localhost:$DASHBOARD_PORT/api/status | grep -q '\"state\":\"green\"'"

bash "$LAB_DIR/scripts/dashboard-setup.sh"
bash "$LAB_DIR/scripts/manager-setup.sh"
bash "$LAB_DIR/scripts/seed.sh"

step "Starting the agent"
"${COMPOSE[@]}" up -d agent-01
wait_for "agent active on the manager" 300 docker exec "$MGR" sh -c '/var/ossec/bin/agent_control -l | grep "lab-agent-01" | grep -q Active'
facts_ok() {
  ix 'wazuh-alerts-*/_count' -H 'Content-Type: application/json' \
    -d '{"query":{"bool":{"filter":[{"term":{"agent.name":"lab-agent-01"}},{"exists":{"field":"data.ensfacil"}}]}}}' \
  | grep -Eq '"count":[1-9]'
}
wait_for "first agent facts in the indexer" 300 facts_ok
inventory_ok() { ix 'wazuh-monitoring-*/_count?q=name:lab-agent-01' | grep -Eq '"count":[1-9]'; }
wait_for "agent in the inventory the panel reads" 300 inventory_ok

bash "$LAB_DIR/scripts/status.sh"

cat <<END

Lab is up.
  Dashboard:  https://localhost:$DASHBOARD_PORT   (admin / $INDEXER_PASSWORD, lab only)
  ENSFácil:   menu > Security operations > ENSFácil
  Destroy:    make down
END
