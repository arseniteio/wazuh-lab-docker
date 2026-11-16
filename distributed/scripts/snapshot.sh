#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

step "Checking the deployment before the snapshot"
"${COMPOSE[@]}" start >/dev/null
wait_for_wazuh

step "Removing core dumps"
for host in "${HOSTS[@]}"; do
  on_sh "$host" 'find / -xdev -type f -regex ".*/core\.[0-9]+" -print -delete 2>/dev/null || true' | sed "s|^|  $host: |"
done

step "Stopping the indexers and removing their Lucene locks"
# Lucene rejects lock files inherited from an image layer after copy-up.
for host in "${INDEXERS[@]}"; do
  on_sh "$host" 'systemctl stop wazuh-indexer && find /var/lib/wazuh-indexer -name "*.lock" -type f -delete'
done

step "Stopping the hosts cleanly"
"${COMPOSE[@]}" stop

previous=()
for host in "${HOSTS[@]}"; do
  id="$(docker image inspect -f '{{.Id}}' "$(snapshot_image "$host")" 2>/dev/null || true)"
  [ -n "$id" ] && previous+=("$id")
done

step "Committing every host to ${COMPOSE_PROJECT_NAME}/<host>:$SNAPSHOT_TAG"
for host in "${HOSTS[@]}"; do
  docker commit -m "Wazuh $WAZUH_VERSION clean install" "$(container "$host")" "$(snapshot_image "$host")" >/dev/null
  ok "$(snapshot_image "$host")"
done

step "Recreating the hosts from the snapshot"
compose_with_tag "$SNAPSHOT_TAG" up -d --force-recreate
wait_for_wazuh

if [ "${#previous[@]}" -gt 0 ]; then
  docker rmi "${previous[@]}" >/dev/null 2>&1 && ok "superseded snapshot images removed" || true
fi
