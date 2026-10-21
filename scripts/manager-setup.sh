#!/usr/bin/env bash
###############################################################################
# manager-setup.sh · installs the manager side of the runbooks (plugin guide 06 §13.5).
#
#   1. Creates the ens group the agent enrolls into.
#   2. Copies each runbook in $RUNBOOKS into the container and runs its
#      install-manager.sh. The image has no systemd: the restart goes through
#      wazuh-control via ENSFACIL_SYSTEMCTL, without touching the scripts.
#
# Idempotent: the installers do not restart when nothing changed.
###############################################################################
set -euo pipefail
. "$(dirname "$0")/lib.sh"

step "ens group on the manager"
if docker exec "$MGR" test -f /var/ossec/etc/shared/ens/agent.conf; then
  ok "the ens group already exists"
else
  docker exec "$MGR" /var/ossec/bin/agent_groups -a -g ens -q >/dev/null
  ok "ens group created"
fi

for r in $RUNBOOKS; do
  step "Runbook $r on the manager"
  [ -f "$RUNBOOKS_DIR/$r/install-manager.sh" ] || { warn "$r has no install-manager.sh"; continue; }
  docker exec "$MGR" rm -rf "/opt/ensfacil-runbooks/$r"
  docker exec "$MGR" mkdir -p "/opt/ensfacil-runbooks/$r"
  # Only what gets deployed: no .git, no tests.
  tar -C "$RUNBOOKS_DIR/$r" --exclude .git --exclude tests --exclude .superpowers -cf - . \
    | docker exec -i "$MGR" tar -C "/opt/ensfacil-runbooks/$r" -xf -
  docker exec -e ENSFACIL_SYSTEMCTL=/var/ossec/bin/wazuh-control "$MGR" \
    bash "/opt/ensfacil-runbooks/$r/install-manager.sh"
done

docker exec "$MGR" /var/ossec/bin/wazuh-analysisd -t >/dev/null && ok "manager configuration is valid"
