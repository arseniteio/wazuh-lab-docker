#!/usr/bin/env bash
# Startup of the audited machine:
#   1. installs each runbook in $RUNBOOKS with its own install.sh (idempotent);
#   2. prepares oscompliance-agent when it is mounted at /opt/oscompliance;
#   3. starts wazuh-agent, which enrolls with the manager;
#   4. keeps cron in the foreground: it runs the collectors.
set -eu

for r in ${RUNBOOKS:-}; do
  echo ">>> runbook $r"
  # install.sh installs from its own folder; /runbooks being read-only does not matter.
  ENSFACIL_SIN_DEPS=1 bash "/runbooks/$r/install.sh"
  # logcollector skips whatever a file already holds when it first finds it,
  # so the facts of the first run would be lost. Creating each runbook's fact
  # file empty before the agent starts makes logcollector follow it from line 1.
  sed -n 's:.*<location>\(/var/log/ensfacil/[^<]*\)</location>.*:\1:p' \
    "/runbooks/$r/manager/agent.conf.fragment.xml" 2>/dev/null \
  | while read -r f; do [ -e "$f" ] || { touch "$f"; chmod 640 "$f"; }; done
done

# oscompliance-agent only runs: its <localfile>, decoder and rules come from
# the manager. Its fact file is created empty for the same reason as above.
OSC_AGENT=/opt/oscompliance/oscompliance-agent
OSC_FACTS=/var/log/oscompliance/facts.ndjson
if [ -x "$OSC_AGENT" ]; then
  echo ">>> oscompliance-agent"
  install -d -m 750 "$(dirname "$OSC_FACTS")"
  [ -e "$OSC_FACTS" ] || install -m 640 /dev/null "$OSC_FACTS"
  printf '%s\n' \
    '# oscompliance-agent: one collection pass per hour.' \
    "17 * * * * root $OSC_AGENT -output $OSC_FACTS >/dev/null 2>&1" \
    > /etc/cron.d/oscompliance
fi

/var/ossec/bin/wazuh-control start

# Each runbook's <localfile> arrives with the ens group configuration, which
# the manager sends after enrollment. Wait until logcollector is reading the
# fact files before the first run.
following() {
  grep -q "$1" /var/ossec/etc/shared/merged.mg 2>/dev/null \
    && grep -q "Analyzing file: '$1" /var/ossec/logs/ossec.log 2>/dev/null
}
for i in $(seq 1 90); do
  { [ -z "${RUNBOOKS:-}" ] || following /var/log/ensfacil/; } \
    && { [ ! -x "$OSC_AGENT" ] || following "$OSC_FACTS"; } && break
  sleep 2
done
sleep 5

# First run of the collectors without waiting for the hourly cron.
for c in /usr/local/bin/ens_op*_collect.sh; do
  [ -x "$c" ] && { echo ">>> first run: $c"; "$c" || echo "warning: $c exited with an error"; }
done

if [ -x "$OSC_AGENT" ]; then
  echo ">>> first run: $OSC_AGENT"
  "$OSC_AGENT" -output "$OSC_FACTS" || echo "warning: $OSC_AGENT exited with an error"
fi

exec cron -f
