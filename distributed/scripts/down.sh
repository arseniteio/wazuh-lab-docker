#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

step "Removing the $COMPOSE_PROJECT_NAME containers"
"${COMPOSE[@]}" down --remove-orphans
ok "containers removed (snapshot images and passwords kept)"
