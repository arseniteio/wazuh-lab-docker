#!/usr/bin/env bash
set -uo pipefail
. "$(dirname "$0")/lib.sh"

step "Containers"
"${COMPOSE[@]}" ps --format 'table {{.Service}}\t{{.Image}}\t{{.State}}'

step "Agents on the manager"
docker exec "$MGR" /var/ossec/bin/agent_control -l 2>/dev/null | grep -E 'ID:' || warn "manager not available"

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

step "OSCompliance verdicts (newest per agent: control, requirements, evidences)"
ix 'oscompliance-verdicts/_search?size=0' -H 'Content-Type: application/json' -d '{
  "aggs": {"k": {"multi_terms": {"terms": [{"field": "agent.name"}, {"field": "control"}, {"field": "scope"}, {"field": "requirement", "missing": "-"}, {"field": "evidence", "missing": "-"}], "size": 500},
    "aggs": {"last": {"top_hits": {"size": 1, "sort": [{"@timestamp": "desc"}],
      "_source": ["status", "cause", "reason", "score", "@timestamp"]}}}}}}' \
| python3 -c '
import json, sys
r = json.load(sys.stdin)
buckets = r.get("aggregations", {}).get("k", {}).get("buckets", [])
if not buckets:
    print("  none yet")
order = {"control": 0, "requirement": 1, "evidence": 2}
rows = []
for b in buckets:
    agent, control, scope, req, ev = b["key"]
    v = b["last"]["hits"]["hits"][0]["_source"]
    rows.append((agent, control, order[scope], req, ev, v))
for agent, control, scope, req, ev, v in sorted(rows):
    if scope == 0:
        print("  {:<16} {:<10} {:<14} {:<14} score {}  {}".format(agent, control, "control", v["status"], v.get("score", "-"), v.get("reason", "")))
    else:
        name = req if scope == 1 else "  " + ev
        print("  {:<16} {:<10} {:<14} {:<14} {} {}".format(agent, control, name, v["status"], v.get("cause", ""), v.get("reason", "")[:110]))
' 2>/dev/null || warn "no verdicts index yet"
