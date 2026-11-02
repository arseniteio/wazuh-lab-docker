#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

json() { ix "$1" -X "$2" -H 'Content-Type: application/json' -d "$3"; }

step "Retention of the alerts indices"
if ix '_plugins/_ism/policies/lab-alerts-retention' | grep -q '"_id":"lab-alerts-retention"'; then
  ok "policy lab-alerts-retention already exists"
else
  json '_plugins/_ism/policies/lab-alerts-retention' PUT '{"policy":{"description":"Lab: keep the alerts 400 days","default_state":"hot",
    "states":[{"name":"hot","actions":[],"transitions":[{"state_name":"delete","conditions":{"min_index_age":"400d"}}]},
              {"name":"delete","actions":[{"delete":{}}],"transitions":[]}],
    "ism_template":[{"index_patterns":["wazuh-alerts-*"],"priority":100}]}}' >/dev/null
  ok "policy lab-alerts-retention created"
fi
json '_plugins/_ism/add/wazuh-alerts-*' POST '{"policy_id":"lab-alerts-retention"}' >/dev/null
ok "alerts indices managed"

step "Snapshots of the alerts indices"
json '_snapshot/lab-backups' PUT '{"type":"fs","settings":{"location":"/var/lib/wazuh-indexer/snapshots"}}' >/dev/null
if ix '_plugins/_sm/policies/lab-daily' | grep -q '"_id":"lab-daily"'; then
  ok "snapshot policy lab-daily already exists"
else
  json '_plugins/_sm/policies/lab-daily' POST '{"description":"Lab: daily snapshot of the alerts",
    "creation":{"schedule":{"cron":{"expression":"30 2 * * *","timezone":"UTC"}}},
    "deletion":{"schedule":{"cron":{"expression":"45 2 * * *","timezone":"UTC"}},"condition":{"max_count":14}},
    "snapshot_config":{"repository":"lab-backups","indices":"wazuh-alerts-*"}}' >/dev/null
  ok "snapshot policy lab-daily created"
fi
if ix '_snapshot/lab-backups/_all' | grep -q '"state":"SUCCESS"'; then
  ok "a snapshot already exists"
else
  ix "_snapshot/lab-backups/lab-first?wait_for_completion=true" -X PUT -H 'Content-Type: application/json' -d '{"indices":"wazuh-alerts-*"}' >/dev/null
  ok "first snapshot taken"
fi
