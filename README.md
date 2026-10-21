# wazuh-lab-docker

Local end-to-end test environment for ENSFácil: Wazuh 4.14.7 (indexer, manager,
dashboard) with the ENSFácil plugin installed, runbook rules on the manager, and
an Ubuntu agent that runs the runbooks and ships their facts. The same agent also
runs `oscompliance-agent`, built from `oscompliance-core`, side by side with v1,
and an `engine` container judges its facts.

## Requirements

- Docker with Compose v2. Tested on OrbStack, Apple Silicon, 12 GB allocated.
- Image `ensfacil-osd-builder:2.19.5`, built from `ci/osd-builder.Dockerfile` in
  the plugin repository.
- Plugin, runbook and `oscompliance-core` sources at the paths set in `lab.conf`.
- Go, to build `oscompliance-agent`.

## Usage

```bash
make up       # create and start the lab (about 3 minutes from scratch)
make status   # containers, agents, facts received
make down     # remove containers, volumes and certificates
```

| Target | Action |
|---|---|
| `make seed` | Re-run configuration seeding and validation |
| `make manager` | Reinstall the manager side of the runbooks |
| `make build-plugin` | Rebuild the plugin zip from `PLUGIN_SRC` |
| `make logs S=<service>` | Follow a service log |

Dashboard: https://localhost:8443, user `admin`, password `SecretPassword`.
The certificate is signed by the lab CA.

Plugin change: `REBUILD=1 make up`.
Runbook change: `make manager`, then recreate `agent-01`.
Engine change: `bash scripts/build-core.sh`, then
`docker restart ensfacil-lab-engine-1`.
Agent change: `bash scripts/build-core.sh`; the next hourly pass (minute 17)
runs it, or run it now:
`docker exec ensfacil-lab-agent-01-1 /opt/oscompliance/oscompliance-agent -output /var/log/oscompliance/facts.ndjson`.
Rule change in `catalog/wazuh/`: `make manager`.

## Configuration

`lab.conf` holds paths, versions, ports and lab-only credentials. Local
overrides go in `lab.conf.local` (not versioned).

| Variable | Default | Purpose |
|---|---|---|
| `COMPOSE_PROJECT_NAME` | `ensfacil-lab` | Prefix for containers, volumes and network |
| `WAZUH_VERSION` | `4.14.7` | Wazuh images and agent package |
| `PLUGIN_SRC` | plugin repository path | Plugin source, mounted read-only |
| `RUNBOOKS_DIR` | runbooks parent path | Runbook sources, mounted read-only |
| `RUNBOOKS` | `op.acc.1-identification` | Runbooks installed on manager and agent |
| `CORE_SRC` | `oscompliance-core` path | Agent source and manager rules (`catalog/wazuh/`) |
| `CONTROLS` | 23 active controls | Controls seeded into the configuration |
| `DASHBOARD_PORT` | `8443` | Dashboard port on `127.0.0.1` |

## `make up` sequence

| Step | Script | Exit condition |
|---|---|---|
| Certificates (lab CA, in `certs/`) | `scripts/certs.sh` | All node and admin certificates present |
| Plugin zip | `scripts/build-plugin.sh` | Zip in `build/` |
| `oscompliance-agent` and `oscompliance-engine`, always rebuilt | `scripts/build-core.sh` | Linux binaries in `build/oscompliance/` |
| Indexer, manager, dashboard | `docker-compose.yml` | Indexer green/yellow, analysisd running, dashboard green |
| Agent inventory interval to 60 s | `scripts/dashboard-setup.sh` | Dashboard green after restart |
| `ens` group, runbook and OSCompliance manager rules, OSCompliance `<localfile>` | `scripts/manager-setup.sh` | Each installer's `wazuh-logtest` check passes, configuration valid |
| First configuration save, seeding, validation | `scripts/seed.sh` | `APPLIED` per control, document valid |
| Agent `lab-agent-01` | `agent-01` service | Agent active, v1 and OSCompliance facts (rule 119001) indexed, agent in inventory |
| OSCompliance engine, one pass every 5 minutes | `engine` service | Verdicts for `lab-agent-01` in `oscompliance-verdicts` |

All steps are idempotent.

## Layout

```
docker-compose.yml   official wazuh-docker single-node compose, modified
config/              official wazuh-docker v4.14.7 config, unmodified
images/              manager, dashboard and agent images
scripts/             one script per step; the Makefile only calls them
lab.conf             lab settings
```

## Design

- Based on the official wazuh-docker v4.14.7 single-node deployment. Changes are
  listed at the top of `docker-compose.yml`.
- Only the dashboard is published, on `127.0.0.1`. The lab coexists with other
  Wazuh deployments on the same host.
- The plugin is installed from its zip and runbooks with their own installers,
  as in a customer deployment.
- Sources are mounted read-only.
- `oscompliance-agent` only runs: its `<localfile>` reaches the agent through
  the `ens` group `agent.conf`, and its rules live on the manager.
- Each step is a standalone script, reusable as a CI job.

## Known issues

- macOS: the certificate generator leaves `certs/` read-only and omits
  `root-ca-manager.*`. Handled in `scripts/certs.sh`.
- A recreated agent without its `client.keys` is rejected as a duplicate name.
  The agent's `/var/ossec/etc` is a volume.
- logcollector skips existing content of a newly discovered file. The agent
  creates fact files empty before starting.
- The plugin reads agents from `wazuh-monitoring-*`, written every 900 s by
  default. The lab sets 60 s.

## Limitations

- Only agent-side runbooks. Manager collectors (op.exp.7, op.exp.8, ...) are not
  scheduled.
- One agent. No authentication log or logins in the container: op.acc.1
  EV-03, EV-05 and EV-06 report no data.
- op.acc.1.5 and op.acc.1.r1.1 have no catalog evidence in plugin 1.4.0 and
  never pass.
