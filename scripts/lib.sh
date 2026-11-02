LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

. "$LAB_DIR/lab.conf"
[ -f "$LAB_DIR/lab.conf.local" ] && . "$LAB_DIR/lab.conf.local"

export COMPOSE_PROJECT_NAME WAZUH_VERSION DASHBOARD_PORT \
       INDEXER_PASSWORD API_PASSWORD ENGINE_API_USER ENGINE_API_PASSWORD CORE_SRC
POWER_ENS_VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' \
  "$PLUGIN_SRC/opensearch_dashboards.json" 2>/dev/null || echo unknown)"
export POWER_ENS_VERSION
COMPOSE=(docker compose -f "$LAB_DIR/docker-compose.yml" --profile agents)
NETWORK="${COMPOSE_PROJECT_NAME}_default"
MGR="${COMPOSE_PROJECT_NAME}-wazuh.manager-1"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m  ok: %s\033[0m\n' "$*"; }
warn() { printf '\033[33m  warning: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[31m  ERROR: %s\033[0m\n' "$*" >&2; exit 1; }

plugin_version() { echo "$POWER_ENS_VERSION"; }

ix() {
  docker run --rm -i --network "$NETWORK" -v "$LAB_DIR/certs:/certs:ro" \
    curlimages/curl:8.10.1 -s --cacert /certs/root-ca.pem \
    --cert /certs/admin.pem --key /certs/admin-key.pem \
    "https://wazuh.indexer:9200/$1" "${@:2}"
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
