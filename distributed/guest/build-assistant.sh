#!/usr/bin/env bash
set -euo pipefail

version="$1"
work="$(mktemp -d)"
curl -fsSL "https://github.com/wazuh/wazuh-installation-assistant/archive/refs/tags/v${version}.tar.gz" \
  | tar -xz -C "$work"
cd "$work/wazuh-installation-assistant-${version}"
bash builder.sh -i
grep -q "readonly wazuh_version=\"${version}\"" wazuh-install.sh
install -m 0755 wazuh-install.sh /lab/wazuh-install.sh
rm -rf "$work"
