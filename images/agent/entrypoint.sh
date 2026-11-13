#!/usr/bin/env bash
set -eu

OSC_BUILD=/opt/oscompliance
OSC_AGENT=/usr/local/bin/oscompliance-agent
OSC_FACTS=/var/log/oscompliance/facts.ndjson
if [ -x "$OSC_BUILD/oscompliance-agent" ]; then
  echo ">>> oscompliance-agent, installed as in docs/en/install.md section 7"
  ln -sf "$OSC_BUILD/oscompliance-agent" "$OSC_AGENT"
  install -m 644 "$OSC_BUILD/oscompliance.cron" /etc/cron.d/oscompliance
  install -d -m 750 "$(dirname "$OSC_FACTS")"
  install -d -m 700 /var/lib/oscompliance
  [ -e "$OSC_FACTS" ] || install -m 640 /dev/null "$OSC_FACTS"
fi

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

install -d -o clamav -g clamav /run/clamav
[ -f /var/lib/clamav/daily.cvd ] || [ -f /var/lib/clamav/daily.cld ] || freshclam --quiet || true
freshclam -d
clamd
echo '13 3 * * * root clamscan -r -i / --exclude-dir=^/proc --exclude-dir=^/sys --log=/var/log/clamav/scan.log >/dev/null 2>&1' > /etc/cron.d/lab-clamscan

install -d -m 700 /var/backups
echo '41 2 * * * root tar czf /var/backups/lab-etc-$(date +\%F).tgz -C / etc 2>/dev/null' > /etc/cron.d/lab-backup
tar czf "/var/backups/lab-etc-$(date +%F).tgz" -C / etc 2>/dev/null || true

[ -e /var/log/auth.log ] || install -o syslog -g adm -m 640 /dev/null /var/log/auth.log
chown syslog:adm /var/log/auth.log
rsyslogd
mkdir -p /run/sshd
ssh-keygen -A >/dev/null
/usr/sbin/sshd

/var/ossec/bin/wazuh-control start

following() {
  grep -q "$1" /var/ossec/etc/shared/merged.mg 2>/dev/null \
    && grep -q "Analyzing file: '$1" /var/ossec/logs/ossec.log 2>/dev/null
}
for i in $(seq 1 90); do
  { [ ! -x "$OSC_AGENT" ] || following "$OSC_FACTS"; } \
    && following /var/log/auth.log && following "$PORTAL_LOG" && break
  sleep 2
done
sleep 5

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
  "$OSC_AGENT" || echo "warning: $OSC_AGENT exited with an error"
fi

exec cron -f
