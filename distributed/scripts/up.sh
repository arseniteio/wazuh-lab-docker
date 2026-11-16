#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

if ! snapshot_exists; then
  warn "no snapshot images found, installing Wazuh from scratch"
  exec bash "$LAB_DIR/scripts/install.sh"
fi

step "Starting $COMPOSE_PROJECT_NAME from the snapshot"
compose_with_tag "$SNAPSHOT_TAG" up -d --remove-orphans
wait_for_wazuh
bash "$LAB_DIR/scripts/status.sh"
