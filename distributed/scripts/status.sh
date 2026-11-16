#!/usr/bin/env bash
set -uo pipefail
. "$(dirname "$0")/lib.sh"

step "Containers"
"${COMPOSE[@]}" ps --format 'table {{.Service}}\t{{.Image}}\t{{.State}}'

step "systemd"
for host in "${HOSTS[@]}"; do
  printf '  %-14s %s\n' "$host" "$(on "$host" systemctl is-system-running 2>/dev/null)"
done

step "Indexer cluster health"
ix '_cluster/health?pretty' | grep -E '"(status|number_of_nodes|active_shards_percent_as_number)"' || warn "indexer not available"

step "Indexer nodes"
ix '_cat/nodes?v&h=ip,name,node.role,master,heap.max,ram.current' || warn "indexer not available"

step "Manager cluster (cluster_control -l)"
on wazuh-mgr-01 /var/ossec/bin/cluster_control -l || warn "manager not available"

step "Agents (agent_control -l)"
on wazuh-mgr-01 /var/ossec/bin/agent_control -l | grep -E 'ID:' || warn "manager not available"

step "Dashboards"
for port in "$DASH01_PORT" "$DASH02_PORT"; do
  if dashboard_login "$port"; then ok "https://localhost:$port login"; else warn "https://localhost:$port login failed"; fi
done
