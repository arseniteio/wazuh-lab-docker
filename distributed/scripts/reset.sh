#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

snapshot_exists || die "no snapshot images, run make install"

step "Resetting $COMPOSE_PROJECT_NAME to the clean Wazuh snapshot"
"${COMPOSE[@]}" down --remove-orphans
compose_with_tag "$SNAPSHOT_TAG" up -d
wait_for_wazuh
ok "lab reset to the snapshot"
