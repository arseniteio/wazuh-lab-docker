LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

. "$LAB_DIR/lab.conf"

export COMPOSE_PROJECT_NAME WAZUH_VERSION LAB_SUBNET DASH01_PORT DASH02_PORT API_PORT
COMPOSE=(docker compose -f "$LAB_DIR/docker-compose.yml")
SHARED="$LAB_DIR/shared"
PASSWORDS="$LAB_DIR/wazuh-passwords.txt"
SNAPSHOT_TAG="wazuh"

INDEXERS=(wazuh-idx-01 wazuh-idx-02 wazuh-idx-03)
SERVERS=(wazuh-mgr-01 wazuh-mgr-02)
DASHBOARDS=(wazuh-dash-01 wazuh-dash-02)
AGENTS=(agent-01 agent-02)
HOSTS=("${INDEXERS[@]}" "${SERVERS[@]}" "${DASHBOARDS[@]}" "${AGENTS[@]}")

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m  ok: %s\033[0m\n' "$*"; }
warn() { printf '\033[33m  warning: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[31m  ERROR: %s\033[0m\n' "$*" >&2; exit 1; }

container() { echo "${COMPOSE_PROJECT_NAME}-$1-1"; }
on() { local host="$1"; shift; docker exec "$(container "$host")" "$@"; }
on_sh() { on "$1" bash -c "$2"; }

snapshot_image() { echo "${COMPOSE_PROJECT_NAME}/$1:$SNAPSHOT_TAG"; }

snapshot_exists() {
  local host
  for host in "${HOSTS[@]}"; do
    docker image inspect "$(snapshot_image "$host")" >/dev/null 2>&1 || return 1
  done
}

compose_with_tag() { local tag="$1"; shift; LAB_TAG="$tag" "${COMPOSE[@]}" "$@"; }

admin_password() {
  [ -f "$PASSWORDS" ] || return 1
  awk "/indexer_username: 'admin'/ { getline; print }" "$PASSWORDS" | sed -E "s/.*indexer_password: '(.*)'/\1/"
}

ix() {
  on wazuh-idx-01 curl -s --cacert /etc/wazuh-indexer/certs/root-ca.pem \
    --cert /etc/wazuh-indexer/certs/admin.pem --key /etc/wazuh-indexer/certs/admin-key.pem \
    "https://192.168.250.11:9200/$1" "${@:2}"
}

wait_for() {
  local desc="$1" max="$2"; shift 2
  local t=0
  printf '  waiting for %s' "$desc"
  until "$@" >/dev/null 2>&1; do
    t=$((t + 5))
    [ "$t" -ge "$max" ] && { echo; die "$desc not ready after ${max}s"; }
    printf '.'; sleep 5
  done
  echo; ok "$desc"
}

systemd_up() {
  local state
  state="$(on "$1" systemctl is-system-running 2>/dev/null)"
  case "$state" in running|degraded|starting) return 0 ;; *) return 1 ;; esac
}

wait_for_systemd() {
  local host
  for host in "${HOSTS[@]}"; do
    wait_for "systemd on $host" 120 systemd_up "$host"
  done
}

indexer_green() { ix '_cluster/health' | grep -q '"status":"green".*"number_of_nodes":3'; }
manager_cluster_ok() { [ "$(on wazuh-mgr-01 /var/ossec/bin/cluster_control -l | grep -cE 'wazuh-mgr-0[12] ')" -eq 2 ]; }
agents_active() { [ "$(on wazuh-mgr-01 /var/ossec/bin/agent_control -l | grep -cE 'Name: agent-0[12],.*Active')" -eq 2 ]; }

dashboard_login() {
  curl -sk -o /dev/null -w '%{http_code}' -X POST "https://localhost:$1/auth/login" \
    -H 'osd-xsrf: true' -H 'Content-Type: application/json' \
    -d "{\"username\":\"admin\",\"password\":\"$(admin_password)\"}" | grep -q '^200$'
}

wait_for_wazuh() {
  wait_for_systemd
  wait_for "indexer cluster green with 3 nodes" 600 indexer_green
  wait_for "manager cluster with master and worker" 300 manager_cluster_ok
  wait_for "dashboard login on $DASH01_PORT" 600 dashboard_login "$DASH01_PORT"
  wait_for "dashboard login on $DASH02_PORT" 600 dashboard_login "$DASH02_PORT"
  wait_for "both agents active" 300 agents_active
}
