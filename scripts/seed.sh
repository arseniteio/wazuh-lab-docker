#!/usr/bin/env bash
###############################################################################
# seed.sh · leaves the Power ENS configuration ready (plugin guide 06 §6, §8, §9).
#
#   1. First save of the `active` document, if missing, through the plugin
#      API with the lab admin user.
#   2. Seeds every control the plugin has a seed block for with
#      inject-control.py (it merges: it never overwrites values you already set).
#   3. Validates the document with the plugin's validate-configuration.ts.
#
# Idempotent: safe to repeat.
###############################################################################
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# Node container with the plugin source read-only and its dependencies in a
# volume of its own (your Mac's node_modules is never touched).
node_plugin() {
  docker run --rm -v "$PLUGIN_SRC:/w:ro" -v "${COMPOSE_PROJECT_NAME}_node_modules:/w/node_modules" \
    -v "${COMPOSE_PROJECT_NAME}_npm_cache:/root/.npm" -v "$LAB_DIR/scripts:/lab:ro" -w /w "$@"
}

step "Installing the plugin dependencies for the tools (slow only the first time)"
node_plugin node:22-alpine \
  npx --yes yarn@1.22.22 install --frozen-lockfile --ignore-scripts --non-interactive --silent >/dev/null 2>&1
ok "dependencies ready"

step "First save of the configuration"
if ix 'wazuh-ens-configuration/_doc/active?filter_path=found' | grep -q '"found":true'; then
  ok "the active document already exists"
else
  BODY="$(node_plugin node:22-alpine npx --yes tsx /lab/default-config.ts)"
  CODE="$(curl -sk -o "$LAB_DIR/build/first-save.json" -w '%{http_code}' -X PUT \
    -u "admin:$INDEXER_PASSWORD" -H 'osd-xsrf: true' -H 'Content-Type: application/json' \
    "https://localhost:$DASHBOARD_PORT/api/powerEns/configuration" --data-binary "$BODY")"
  [ "$CODE" = 200 ] || { cat "$LAB_DIR/build/first-save.json" >&2; die "first save returned $CODE"; }
  ok "active document created"
fi

step "Seeding controls"
CONTROLS="$(ls "$PLUGIN_SRC"/config/*-control-block.json | sed -E 's#.*/##; s#-control-block.json##; s#-([0-9]+)$#.\1#; s#-#.#g')"
for c in $CONTROLS; do
  OUT="$(docker run --rm --network "$NETWORK" \
    -v "$LAB_DIR/certs:/certs:ro" -v "$PLUGIN_SRC/config:/cfg:ro" \
    -e PYTHONDONTWRITEBYTECODE=1 \
    -e OS_CERT=/certs/admin.pem -e OS_KEY=/certs/admin-key.pem -e OS_CA=/certs/root-ca.pem \
    -e ENS_OS_URL=https://wazuh.indexer:9200 -w /cfg python:3.12-slim \
    python3 inject-control.py "$c" --apply 2>&1)" || { echo "$OUT" >&2; die "seeding $c failed"; }
  echo "$OUT" | grep -q 'APPLIED' || { echo "$OUT" >&2; die "seeding $c did not end in APPLIED"; }
  printf '  %s' "$c"
done
echo; ok "controls seeded"

step "Lab parameter values (scripts/lab-parameters.json)"
OUT="$(docker run --rm --network "$NETWORK" \
  -v "$LAB_DIR/certs:/certs:ro" -v "$PLUGIN_SRC:/plugin:ro" -v "$LAB_DIR/scripts:/lab:ro" \
  -e PYTHONDONTWRITEBYTECODE=1 \
  -e OS_CERT=/certs/admin.pem -e OS_KEY=/certs/admin-key.pem -e OS_CA=/certs/root-ca.pem \
  -e ENS_OS_URL=https://wazuh.indexer:9200 -w /plugin/config python:3.12-slim \
  python3 set-parameters.py /lab/lab-parameters.json --apply </dev/null 2>&1)" || { echo "$OUT" >&2; die "lab parameters failed"; }
ok "lab parameters set"

step "Validating the document"
ix wazuh-ens-configuration/_doc/active > "$LAB_DIR/build/active.json"
node_plugin -v "$LAB_DIR/build/active.json:/tmp/active.json:ro" node:22-alpine \
  npx --yes tsx config/validate-configuration.ts /tmp/active.json | tail -3
ok "configuration is valid"
