#!/usr/bin/env bash
###############################################################################
# manager-setup.sh · installs the manager side of OSCompliance.
#
#   1. Creates the ens group the agent enrolls into.
#   2. Installs the OSCompliance rules from $CORE_SRC/catalog/wazuh and adds
#      its <localfile> to the ens group agent.conf, plus the lab portal log
#      for lab-agent-01. The manager restarts only when one of them changed.
#
# Idempotent: nothing restarts when nothing changed.
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

# Lab machine only: its auth.log (rsyslog) carries the sshd logins EV-03 reads.
# A real machine keeps whatever authentication source Wazuh already reads.
if docker exec "$MGR" grep -q "<location>/var/log/auth.log</location>" "$AGENT_CONF"; then
  ok "localfile /var/log/auth.log already in the ens group"
else
  tmp="$(mktemp)"
  docker exec "$MGR" cat "$AGENT_CONF" \
  | python3 -c '
import sys
conf = sys.stdin.read()
i = conf.index("</agent_config>", conf.index("<agent_config>"))
sys.stdout.write(conf[:i] + "\n<localfile>\n  <log_format>syslog</log_format>\n  <location>/var/log/auth.log</location>\n</localfile>\n" + conf[i:])
' > "$tmp"
  docker cp -q "$tmp" "$MGR:$AGENT_CONF"
  rm -f "$tmp"
  docker exec "$MGR" chown wazuh:wazuh "$AGENT_CONF"
  docker exec "$MGR" chmod 660 "$AGENT_CONF"
  osc_changed=1
  ok "localfile /var/log/auth.log added to the ens group"
fi

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
i = conf.index("</agent_config>", conf.index("<agent_config>"))
sys.stdout.write(conf[:i] + "\n" + frag + conf[i:])
' "$OSC_WAZUH/agent.conf.fragment.xml" > "$tmp"
  docker cp -q "$tmp" "$MGR:$AGENT_CONF"
  rm -f "$tmp"
  docker exec "$MGR" chown wazuh:wazuh "$AGENT_CONF"
  docker exec "$MGR" chmod 660 "$AGENT_CONF"
  osc_changed=1
  ok "localfile $osc_location added to the ens group"
fi

# Lab machine only: the log of a simulated external-user portal (op.acc.5),
# declared for lab-agent-01 alone, as P-02 declares a service per machine.
# The label names the service on every event (rule 119003).
if docker exec "$MGR" grep -q "<label key=\"oscompliance_service\">sede</label>" "$AGENT_CONF"; then
  ok "lab portal log already declared for lab-agent-01"
else
  docker exec -i "$MGR" sh -c "cat >> $AGENT_CONF" <<'XML'

<agent_config name="lab-agent-01">
  <localfile>
    <log_format>json</log_format>
    <location>/var/log/lab-portal/auth.json</location>
    <label key="oscompliance_service">sede</label>
  </localfile>
</agent_config>
XML
  osc_changed=1
  ok "lab portal log declared for lab-agent-01"
fi

# Paths that come from parameters (op.acc.2 P-08 rights and P-06 audited
# resources, op.acc.3 P-03 binaries and security paths) travel as a shared
# file of the group: Wazuh copies it to every
# agent of the group and oscompliance-agent reads it. Lab values: what the
# lab machine has.
OSC_SHARED=/var/ossec/etc/shared/ens/oscompliance.json
osc_paths='{"acl_paths":["/etc/ssh","/etc/sudoers.d"],"audit_watches":["/etc/ssh","/var/ossec/etc","/etc/audit","/var/log/audit"],"exec_watches":["/usr/bin/git","/usr/bin/systemctl","/usr/bin/crontab","/usr/sbin/visudo","/usr/sbin/usermod","/usr/sbin/useradd","/usr/bin/nano","/usr/bin/vim","/usr/bin/tee","/usr/bin/apt","/usr/bin/dpkg","/usr/bin/apt-get","/usr/sbin/ausearch","/usr/sbin/auditctl"]}'
if [ "$(docker exec "$MGR" cat "$OSC_SHARED" 2>/dev/null)" = "$osc_paths" ]; then
  ok "shared oscompliance.json already up to date"
else
  printf '%s' "$osc_paths" | docker exec -i "$MGR" sh -c "cat > $OSC_SHARED && chown wazuh:wazuh $OSC_SHARED && chmod 660 $OSC_SHARED"
  ok "shared oscompliance.json written"
fi

docker exec "$MGR" /var/ossec/bin/wazuh-analysisd -t >/dev/null || die "manager configuration is not valid"
if [ "$osc_changed" = 1 ]; then
  docker exec "$MGR" /var/ossec/bin/wazuh-control restart >/dev/null
  ok "manager restarted"
fi

docker exec "$MGR" /var/ossec/bin/wazuh-analysisd -t >/dev/null && ok "manager configuration is valid"
