#!/usr/bin/env bash
set -euo pipefail

version="$1" manager="$2" name="$3"
export DEBIAN_FRONTEND=noninteractive

curl -fsSL https://packages.wazuh.com/key/GPG-KEY-WAZUH \
  | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
  > /etc/apt/sources.list.d/wazuh.list
apt-get update
apt-get install -y auditd cron
WAZUH_MANAGER="$manager" WAZUH_AGENT_NAME="$name" apt-get install -y "wazuh-agent=${version}-1"
apt-mark hold wazuh-agent
systemctl daemon-reload
systemctl enable --now cron
systemctl enable wazuh-agent auditd
systemctl start wazuh-agent
systemctl start auditd || echo "auditd cannot start inside a container: the kernel audit socket only accepts the initial PID namespace" >&2
