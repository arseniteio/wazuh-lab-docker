#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

step "Destroying the $COMPOSE_PROJECT_NAME lab"
"${COMPOSE[@]}" down -v --remove-orphans
docker volume rm "${COMPOSE_PROJECT_NAME}_node_modules" "${COMPOSE_PROJECT_NAME}_npm_cache" >/dev/null 2>&1 || true
[ -d "$LAB_DIR/certs" ] && chmod -R u+w "$LAB_DIR/certs"
rm -rf "$LAB_DIR/certs" "$LAB_DIR/images/dashboard/power-ens-2.19.5.zip" \
       "$LAB_DIR/build/active.json" "$LAB_DIR/build/first-save.json"
ok "lab destroyed (images and zip kept)"
