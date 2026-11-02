#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

step "ens group on the manager"
if docker exec "$MGR" test -f /var/ossec/etc/shared/ens/agent.conf; then
  ok "the ens group already exists"
else
  docker exec "$MGR" /var/ossec/bin/agent_groups -a -g ens -q >/dev/null
  ok "ens group created"
fi

step "OSCompliance rules on the manager"
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

for log in /var/log/auth.log /var/log/syslog; do
  if docker exec "$MGR" grep -q "<location>$log</location>" "$AGENT_CONF"; then
    ok "localfile $log already in the ens group"
    continue
  fi
  tmp="$(mktemp)"
  docker exec "$MGR" cat "$AGENT_CONF" \
  | LOG="$log" python3 -c '
import os, sys
conf = sys.stdin.read()
i = conf.index("</agent_config>", conf.index("<agent_config>"))
sys.stdout.write(conf[:i] + "\n<localfile>\n  <log_format>syslog</log_format>\n  <location>" + os.environ["LOG"] + "</location>\n</localfile>\n" + conf[i:])
' > "$tmp"
  docker cp -q "$tmp" "$MGR:$AGENT_CONF"
  rm -f "$tmp"
  docker exec "$MGR" chown wazuh:wazuh "$AGENT_CONF"
  docker exec "$MGR" chmod 660 "$AGENT_CONF"
  osc_changed=1
  ok "localfile $log added to the ens group"
done

docker exec "$MGR" /var/ossec/bin/wazuh-analysisd -t >/dev/null || die "manager configuration is not valid"
if [ "$osc_changed" = 1 ]; then
  docker exec "$MGR" /var/ossec/bin/wazuh-control restart >/dev/null
  ok "manager restarted"
fi

docker exec "$MGR" /var/ossec/bin/wazuh-analysisd -t >/dev/null && ok "manager configuration is valid"

step "Wazuh API user of the engine"
api() {
  local token
  token="$(docker run --rm --network "$NETWORK" curlimages/curl:8.10.1 -sk -u "wazuh-wui:$API_PASSWORD" \
    -X POST "https://wazuh.manager:55000/security/user/authenticate?raw=true")"
  docker run --rm -i --network "$NETWORK" curlimages/curl:8.10.1 -sk -X "$1" \
    -H "Authorization: Bearer $token" -H 'Content-Type: application/json' "https://wazuh.manager:55000$2" "${@:3}"
}
id_of() { python3 -c 'import json,sys; items=json.load(sys.stdin)["data"]["affected_items"]; print(items[0]["id"] if items else "")'; }

wait_for "Wazuh API" 300 sh -c "docker run --rm --network $NETWORK curlimages/curl:8.10.1 -sk -o /dev/null -w %{http_code} -u wazuh-wui:'$API_PASSWORD' -X POST https://wazuh.manager:55000/security/user/authenticate | grep -q 200"

ROLE_FILE="$CORE_SRC/catalog/wazuh/engine-api-role.json"
role_name="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["role"])' "$ROLE_FILE")"
policy_body="$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))["policy"]))' "$ROLE_FILE")"
policy_name="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["policy"]["name"])' "$ROLE_FILE")"

policy_id="$(api GET "/security/policies?search=$policy_name" | id_of)"
if [ -n "$policy_id" ]; then
  printf '%s' "$policy_body" | api PUT "/security/policies/$policy_id" --data-binary @- >/dev/null
  ok "policy $policy_name updated"
else
  policy_id="$(printf '%s' "$policy_body" | api POST /security/policies --data-binary @- | id_of)"
fi

user_id="$(api GET "/security/users?search=$ENGINE_API_USER" | id_of)"
if [ -n "$user_id" ]; then
  ok "user $ENGINE_API_USER already exists"
else
  role_id="$(api GET "/security/roles?search=$role_name" | id_of)"
  [ -n "$role_id" ] || role_id="$(api POST /security/roles -d "{\"name\":\"$role_name\"}" | id_of)"
  api POST "/security/roles/$role_id/policies?policy_ids=$policy_id" >/dev/null
  user_id="$(api POST /security/users -d "{\"username\":\"$ENGINE_API_USER\",\"password\":\"$ENGINE_API_PASSWORD\"}" | id_of)"
  [ -n "$user_id" ] || die "could not create the API user $ENGINE_API_USER"
  api POST "/security/users/$user_id/roles?role_ids=$role_id" >/dev/null
  ok "user $ENGINE_API_USER created with role $role_name"
fi
