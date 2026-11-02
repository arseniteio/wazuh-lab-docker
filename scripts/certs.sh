#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

if [ -f "$LAB_DIR/certs/root-ca.pem" ]; then
  ok "certificates already in certs/"
  exit 0
fi

step "Generating lab certificates"
mkdir -p "$LAB_DIR/certs"
docker run --rm \
  -e CERT_TOOL_VERSION=4.14 \
  -v "$LAB_DIR/certs:/certificates/" \
  -v "$LAB_DIR/config/certs.yml:/config/certs.yml:ro" \
  wazuh/wazuh-certs-generator:0.0.4 >/dev/null 2>&1

chmod u+w "$LAB_DIR/certs"
[ -f "$LAB_DIR/certs/root-ca-manager.pem" ] || cp "$LAB_DIR/certs/root-ca.pem" "$LAB_DIR/certs/root-ca-manager.pem"
[ -f "$LAB_DIR/certs/root-ca-manager.key" ] || cp "$LAB_DIR/certs/root-ca.key" "$LAB_DIR/certs/root-ca-manager.key"
chmod 400 "$LAB_DIR"/certs/root-ca-manager.*

for f in root-ca.pem admin.pem admin-key.pem wazuh.indexer.pem wazuh.manager.pem wazuh.dashboard.pem; do
  [ -f "$LAB_DIR/certs/$f" ] || die "missing certs/$f"
done
ok "certificates in certs/"
