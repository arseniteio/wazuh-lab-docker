#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

bash "$LAB_DIR/scripts/certs.sh"

step "Power ENS plugin $POWER_ENS_VERSION"
ZIP="$LAB_DIR/build/power-ens-$POWER_ENS_VERSION-osd-2.19.5.zip"
if [ "${REBUILD:-}" = 1 ] || [ ! -f "$ZIP" ]; then
  bash "$LAB_DIR/scripts/build-plugin.sh"
else
  ok "using $ZIP (REBUILD=1 to rebuild)"
fi
cp "$ZIP" "$LAB_DIR/images/dashboard/power-ens-2.19.5.zip"

bash "$LAB_DIR/scripts/build-core.sh"

step "Building images and starting Wazuh $WAZUH_VERSION"
"${COMPOSE[@]}" build --quiet wazuh.manager wazuh.dashboard agent-01
"${COMPOSE[@]}" up -d wazuh.indexer wazuh.manager wazuh.dashboard

indexer_ok() { ix '_cluster/health' | grep -Eq '"status":"(green|yellow)"'; }
wait_for "indexer" 300 indexer_ok
wait_for "manager (analysisd)" 300 docker exec "$MGR" sh -c '/var/ossec/bin/wazuh-control status | grep -q "wazuh-analysisd is running"'
wait_for "dashboard" 400 sh -c "curl -sk -u 'admin:$INDEXER_PASSWORD' https://localhost:$DASHBOARD_PORT/api/status | grep -q '\"state\":\"green\"'"

bash "$LAB_DIR/scripts/dashboard-setup.sh"
bash "$LAB_DIR/scripts/manager-setup.sh"
bash "$LAB_DIR/scripts/indexer-setup.sh"
bash "$LAB_DIR/scripts/seed.sh"

step "Starting the OSCompliance engine"
"${COMPOSE[@]}" up -d --force-recreate engine
wait_for "ens group configuration written by the engine" 300 \
  docker exec "$MGR" grep -q "oscompliance begin" /var/ossec/etc/shared/ens/agent.conf

step "Starting the agent"
"${COMPOSE[@]}" up -d agent-01
wait_for "agent active on the manager" 300 docker exec "$MGR" sh -c '/var/ossec/bin/agent_control -l | grep "lab-agent-01" | grep -q Active'
osc_facts_ok() {
  ix 'wazuh-alerts-*/_count' -H 'Content-Type: application/json' \
    -d '{"query":{"bool":{"filter":[{"term":{"agent.name":"lab-agent-01"}},{"term":{"rule.id":"119001"}}]}}}' \
  | grep -Eq '"count":[1-9]'
}
wait_for "first oscompliance facts in the indexer" 300 osc_facts_ok
verdicts_ok() {
  ix 'oscompliance-verdicts/_count' -H 'Content-Type: application/json' \
    -d '{"query":{"term":{"agent.name":"lab-agent-01"}}}' \
  | grep -Eq '"count":[1-9]'
}
wait_for "first verdicts in oscompliance-verdicts" 300 verdicts_ok
inventory_ok() { ix 'wazuh-monitoring-*/_count?q=name:lab-agent-01' | grep -Eq '"count":[1-9]'; }
wait_for "agent in the inventory the panel reads" 300 inventory_ok

bash "$LAB_DIR/scripts/status.sh"

cat <<END

Lab is up.
  Dashboard:  https://localhost:$DASHBOARD_PORT   (admin / $INDEXER_PASSWORD, lab only)
  Power ENS:   menu > Security operations > Power ENS
  Destroy:    make down
END
