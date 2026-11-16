#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

INDEXER_HEAP="512m"
LOGS="$SHARED/logs"

assistant() {
  local host="$1" log="$LOGS/$1-$2.log"; shift 2
  if ! on_sh "$host" "cd /lab && bash wazuh-install.sh $*" >"$log" 2>&1; then
    tail -20 "$log" >&2
    die "wazuh-install.sh $* failed on $host (log: $log)"
  fi
  ok "$host: wazuh-install.sh $*"
}

guest() {
  local host="$1" script="$2"; shift 2
  docker exec -i "$(container "$host")" bash -s -- "$@" <"$LAB_DIR/guest/$script"
}

step "Recreating the hosts from the base images"
"${COMPOSE[@]}" down --remove-orphans
rm -rf "$SHARED"
mkdir -p "$LOGS"
cp "$LAB_DIR/config/config.yml" "$SHARED/config.yml"
compose_with_tag base build --quiet
compose_with_tag base up -d
wait_for_systemd

step "Building the installation assistant $WAZUH_VERSION"
guest wazuh-mgr-01 build-assistant.sh "$WAZUH_VERSION" >"$LOGS/assistant-build.log" 2>&1 \
  || die "assistant build failed (log: $LOGS/assistant-build.log)"
ok "$SHARED/wazuh-install.sh"

step "Generating certificates and passwords"
assistant wazuh-mgr-01 generate --generate-config-files
tar -xOf "$SHARED/wazuh-install-files.tar" wazuh-install-files/wazuh-passwords.txt >"$PASSWORDS"
chmod 600 "$PASSWORDS"
ok "passwords saved in $PASSWORDS"

step "Installing the indexer nodes"
pids=()
for host in "${INDEXERS[@]}"; do
  assistant "$host" indexer --wazuh-indexer "$host" -i & pids+=($!)
done
for pid in "${pids[@]}"; do wait "$pid" || die "indexer installation failed"; done
for host in "${INDEXERS[@]}"; do
  guest "$host" indexer-heap.sh "$INDEXER_HEAP"
  ok "$host: JVM heap $INDEXER_HEAP"
done

step "Initializing the indexer cluster"
assistant wazuh-idx-01 start-cluster --start-cluster
wait_for "indexer cluster green with 3 nodes" 600 indexer_green

step "Installing the server nodes"
for host in "${SERVERS[@]}"; do
  assistant "$host" server --wazuh-server "$host" -i
done
wait_for "manager cluster with master and worker" 300 manager_cluster_ok

step "Installing the dashboard nodes"
for host in "${DASHBOARDS[@]}"; do
  assistant "$host" dashboard --wazuh-dashboard "$host" -i
done

step "Installing the agents"
guest agent-01 agent-rpm.sh "$WAZUH_VERSION" 192.168.250.21 agent-01 >"$LOGS/agent-01.log" 2>&1 \
  || die "agent-01 installation failed (log: $LOGS/agent-01.log)"
ok "agent-01 (Rocky Linux 9) reports to wazuh-mgr-01"
guest agent-02 agent-deb.sh "$WAZUH_VERSION" 192.168.250.22 agent-02 >"$LOGS/agent-02.log" 2>&1 \
  || die "agent-02 installation failed (log: $LOGS/agent-02.log)"
ok "agent-02 (Ubuntu 22.04) reports to wazuh-mgr-02"

wait_for_wazuh
bash "$LAB_DIR/scripts/snapshot.sh"
bash "$LAB_DIR/scripts/status.sh"
