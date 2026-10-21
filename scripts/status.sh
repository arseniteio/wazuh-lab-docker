#!/usr/bin/env bash
###############################################################################
# status.sh · snapshot of the lab: containers, agents and incoming facts.
###############################################################################
set -uo pipefail
. "$(dirname "$0")/lib.sh"

step "Containers"
"${COMPOSE[@]}" ps --format 'table {{.Service}}\t{{.Image}}\t{{.State}}'

step "Agents on the manager"
docker exec "$MGR" /var/ossec/bin/agent_control -l 2>/dev/null | grep -E 'ID:' || warn "manager not available"

step "ENSFácil facts in the indexer (last 24 h, by control and agent)"
ix 'wazuh-alerts-*/_search?size=0' -H 'Content-Type: application/json' -d '{
  "query": {"bool": {"filter": [
    {"exists": {"field": "data.ensfacil"}},
    {"range": {"timestamp": {"gte": "now-24h"}}}]}},
  "aggs": {"c": {"terms": {"field": "data.ensfacil", "size": 50},
    "aggs": {"a": {"terms": {"field": "agent.name", "size": 20}}}}}}' \
| python3 -c '
import json, sys
r = json.load(sys.stdin)
buckets = r.get("aggregations", {}).get("c", {}).get("buckets", [])
if not buckets:
    print("  none yet (the agent takes a couple of minutes to send the first ones)")
for c in buckets:
    for a in c["a"]["buckets"]:
        print("  {:<12} {:<16} {} facts".format(c["key"], a["key"], a["doc_count"]))
' 2>/dev/null || warn "indexer not available"

step "OSCompliance facts in the indexer (last 24 h, by fact and agent)"
ix 'wazuh-alerts-*/_search?size=0' -H 'Content-Type: application/json' -d '{
  "query": {"bool": {"filter": [
    {"term": {"rule.id": "119001"}},
    {"range": {"timestamp": {"gte": "now-24h"}}}]}},
  "aggs": {"f": {"terms": {"field": "data.fact", "size": 50},
    "aggs": {"a": {"terms": {"field": "agent.name", "size": 20}}}}}}' \
| python3 -c '
import json, sys
r = json.load(sys.stdin)
buckets = r.get("aggregations", {}).get("f", {}).get("buckets", [])
if not buckets:
    print("  none yet")
for f in buckets:
    for a in f["a"]["buckets"]:
        print("  {:<28} {:<16} {} facts".format(f["key"], a["key"], a["doc_count"]))
' 2>/dev/null || warn "indexer not available"

step "OSCompliance verdicts (newest per agent and evidence)"
ix 'oscompliance-verdicts/_search?size=0' -H 'Content-Type: application/json' -d '{
  "aggs": {"k": {"multi_terms": {"terms": [{"field": "agent.name"}, {"field": "control"}, {"field": "evidence"}], "size": 200},
    "aggs": {"last": {"top_hits": {"size": 1, "sort": [{"@timestamp": "desc"}],
      "_source": ["status", "cause", "reason", "@timestamp"]}}}}}}' \
| python3 -c '
import json, sys
r = json.load(sys.stdin)
buckets = r.get("aggregations", {}).get("k", {}).get("buckets", [])
if not buckets:
    print("  none yet")
for b in buckets:
    v = b["last"]["hits"]["hits"][0]["_source"]
    agent, control, evidence = b["key"]
    print("  {:<16} {:<10} {:<6} {:<14} {} {}".format(agent, control, evidence, v["status"], v.get("cause", ""), v.get("reason", "")))
' 2>/dev/null || warn "no verdicts index yet"
