#!/usr/bin/env bash
set -euo pipefail

version="$1" manager="$2" name="$3"

rpm --import https://packages.wazuh.com/key/GPG-KEY-WAZUH
cat > /etc/yum.repos.d/wazuh.repo <<REPO
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=EL-\$releasever - Wazuh
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1
REPO
dnf -y install audit cronie
WAZUH_MANAGER="$manager" WAZUH_AGENT_NAME="$name" dnf -y install "wazuh-agent-${version}-1"
sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/wazuh.repo
systemctl daemon-reload
systemctl enable --now crond
systemctl enable wazuh-agent auditd
systemctl start wazuh-agent
service auditd start || echo "auditd cannot start inside a container: the kernel audit socket only accepts the initial PID namespace" >&2
