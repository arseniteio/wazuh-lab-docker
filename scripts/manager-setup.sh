#!/usr/bin/env bash
###############################################################################
# manager-setup.sh · installs the manager side of the runbooks (plugin guide 06 §13.5).
#
#   1. Creates the ens group the agent enrolls into.
#   2. Copies each runbook in $RUNBOOKS into the container and runs its
#      install-manager.sh. The image has no systemd: the restart goes through
#      wazuh-control via ENSFACIL_SYSTEMCTL, without touching the scripts.
#   3. Installs the OSCompliance rules from $CORE_SRC/catalog/wazuh and adds
#      its <localfile> to the ens group agent.conf. The manager restarts only
#      when one of them changed.
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

step "OSCompliance rules and localfile on the manager"
OSC_WAZUH="$CORE_SRC/catalog/wazuh"
OSC_RULES=oscompliance_facts_rules.xml
[ -f "$OSC_WAZUH/$OSC_RULES" ] || die "no $OSC_RULES in $OSC_WAZUH"
osc_changed=0

if docker exec "$MGR" cat "/var/ossec/etc/rules/$OSC_RULES" 2>/dev/null | cmp -s - "$OSC_WAZUH/$OSC_RULES"; then
  ok "rules already up to date"
else
  docker cp -q "$OSC_WAZUH/$OSC_RULES" "$MGR:/var/ossec/etc/rules/$OSC_RULES"
  docker exec "$MGR" chown wazuh:wazuh "/var/ossec/etc/rules/$OSC_RULES"
  docker exec "$MGR" chmod 640 "/var/ossec/etc/rules/$OSC_RULES"
  osc_changed=1
  ok "rules installed"
fi

AGENT_CONF=/var/ossec/etc/shared/ens/agent.conf
osc_location="$(sed -n 's:.*<location>\(.*\)</location>.*:\1:p' "$OSC_WAZUH/agent.conf.fragment.xml")"
if docker exec "$MGR" grep -q "<location>$osc_location</location>" "$AGENT_CONF"; then
  ok "localfile $osc_location already in the ens group"
else
  # The fragment goes right before the closing </agent_config>, comment lines dropped.
  tmp="$(mktemp)"
  docker exec "$MGR" cat "$AGENT_CONF" \
  | python3 -c '
import sys
conf, frag = sys.stdin.read(), open(sys.argv[1]).read()
frag = "".join(l for l in frag.splitlines(True) if not l.lstrip().startswith("<!--"))
i = conf.rindex("</agent_config>")
sys.stdout.write(conf[:i] + "\n" + frag + conf[i:])
' "$OSC_WAZUH/agent.conf.fragment.xml" > "$tmp"
  docker cp -q "$tmp" "$MGR:$AGENT_CONF"
  rm -f "$tmp"
  docker exec "$MGR" chown wazuh:wazuh "$AGENT_CONF"
  docker exec "$MGR" chmod 660 "$AGENT_CONF"
  osc_changed=1
  ok "localfile $osc_location added to the ens group"
fi

docker exec "$MGR" /var/ossec/bin/wazuh-analysisd -t >/dev/null || die "manager configuration is not valid"
if [ "$osc_changed" = 1 ]; then
  docker exec "$MGR" /var/ossec/bin/wazuh-control restart >/dev/null
  ok "manager restarted"
fi

docker exec "$MGR" /var/ossec/bin/wazuh-analysisd -t >/dev/null && ok "manager configuration is valid"
