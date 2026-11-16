#!/usr/bin/env bash
set -euo pipefail

heap="$1"
sed -i -E "s/^-Xms[0-9]+[mg]$/-Xms${heap}/; s/^-Xmx[0-9]+[mg]$/-Xmx${heap}/" /etc/wazuh-indexer/jvm.options
grep -q "^-Xmx${heap}$" /etc/wazuh-indexer/jvm.options
systemctl restart wazuh-indexer
