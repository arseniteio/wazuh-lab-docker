#!/usr/bin/env bash
# Startup of the audited machine:
#   1. installs each runbook in $RUNBOOKS with its own install.sh (idempotent);
#   2. prepares oscompliance-agent when it is mounted at /opt/oscompliance;
#   3. starts rsyslog and sshd, so there is an auth.log with real logins;
#   4. starts wazuh-agent, which enrolls with the manager;
#   5. makes one sshd login, then keeps cron in the foreground: it runs the
#      collectors.
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
    '# oscompliance-agent: one collection pass per hour, the filesystem sweep daily.' \
    "17 * * * * root $OSC_AGENT -output $OSC_FACTS >/dev/null 2>&1" \
    "23 3 * * * root $OSC_AGENT -collect sweep -output $OSC_FACTS >/dev/null 2>&1" \
    > /etc/cron.d/oscompliance
fi

# A simulated external-user portal for op.acc.5: it writes its authentication
# log in the op.acc.5 contract every hour; the manager declares the file for
# this machine with the oscompliance_service label (scripts/manager-setup.sh).
PORTAL_LOG=/var/log/lab-portal/auth.json
install -d -m 750 "$(dirname "$PORTAL_LOG")"
[ -e "$PORTAL_LOG" ] || install -m 640 /dev/null "$PORTAL_LOG"
cat > /usr/local/bin/lab-portal <<'SH'
#!/bin/sh
# One hour of a citizen portal: its declared policy, a login with password
# and OTP, and a rejection with a message that reveals nothing.
log=/var/log/lab-portal/auth.json
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
{
  echo "{\"ts\":\"$now\",\"tipo\":\"politica\",\"bloqueo\":\"activado\",\"max_intentos\":5,\"reactivacion\":\"intervencion\",\"longitud_minima\":12,\"complejidad\":\"activada\"}"
  echo "{\"ts\":\"$now\",\"tipo\":\"autenticacion\",\"usuario\":\"ciudadano1\",\"origen\":\"203.0.113.7\",\"resultado\":\"exito\",\"factores\":[\"password\",\"otp\"]}"
  echo "{\"ts\":\"$now\",\"tipo\":\"autenticacion\",\"usuario\":\"ciudadano2\",\"origen\":\"203.0.113.8\",\"resultado\":\"fallo\",\"mensaje\":\"Usuario o contraseña incorrectos\"}"
} >> "$log"
SH
chmod 755 /usr/local/bin/lab-portal
echo "7 * * * * root /usr/local/bin/lab-portal" > /etc/cron.d/lab-portal

# Authentication log for op.acc.1 EV-03: rsyslog writes /var/log/auth.log,
# read by wazuh-agent through the ens group (scripts/manager-setup.sh).
# rsyslog drops to the syslog user: the file needs Ubuntu's own ownership.
[ -e /var/log/auth.log ] || install -o syslog -g adm -m 640 /dev/null /var/log/auth.log
chown syslog:adm /var/log/auth.log
rsyslogd
mkdir -p /run/sshd
ssh-keygen -A >/dev/null
/usr/sbin/sshd

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
    && { [ ! -x "$OSC_AGENT" ] || following "$OSC_FACTS"; } \
    && following /var/log/auth.log && following "$PORTAL_LOG" && break
  sleep 2
done
sleep 5

# First run of the collectors without waiting for the hourly cron.
for c in /usr/local/bin/ens_op*_collect.sh; do
  [ -x "$c" ] && { echo ">>> first run: $c"; "$c" || echo "warning: $c exited with an error"; }
done

# One key-based sshd login as jperez, a named account: Wazuh turns it into a
# rule 5715 alert, which is what EV-03 reads.
if [ ! -f /root/.ssh/lab_login ]; then
  mkdir -p /root/.ssh /home/jperez/.ssh
  ssh-keygen -q -t ed25519 -N "" -f /root/.ssh/lab_login
  cp /root/.ssh/lab_login.pub /home/jperez/.ssh/authorized_keys
  chown -R jperez:jperez /home/jperez/.ssh
  chmod 700 /home/jperez/.ssh
  chmod 600 /home/jperez/.ssh/authorized_keys
fi
ssh -i /root/.ssh/lab_login -o BatchMode=yes -o StrictHostKeyChecking=no jperez@localhost true \
  || echo "warning: lab sshd login failed"

/usr/local/bin/lab-portal

if [ -x "$OSC_AGENT" ]; then
  echo ">>> first run: $OSC_AGENT"
  "$OSC_AGENT" -output "$OSC_FACTS" || echo "warning: $OSC_AGENT exited with an error"
fi

exec cron -f
