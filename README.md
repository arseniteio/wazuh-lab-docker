# wazuh-lab-docker

Local end-to-end test environment for Power ENS: Wazuh 4.14.7 (indexer, manager,
dashboard) with the Power ENS plugin installed, OSCompliance rules on the
manager, and an Ubuntu agent that runs `oscompliance-agent`, built from
`oscompliance-ens`. An `engine` container judges its facts.

## Requirements

- Docker with Compose v2. Tested on OrbStack, Apple Silicon, 12 GB allocated.
- Image `power-ens-osd-builder:2.19.5`, built from `ci/osd-builder.Dockerfile` in
  the plugin repository.
- Plugin and `oscompliance-ens` sources at the paths set in `lab.conf`.
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
| `make manager` | Reinstall the manager side of OSCompliance |
| `make build-plugin` | Rebuild the plugin zip from `PLUGIN_SRC` |
| `make logs S=<service>` | Follow a service log |

Dashboard: https://localhost:8443, user `admin`, password `SecretPassword`.
The certificate is signed by the lab CA.

Plugin change: `REBUILD=1 make up`.
Manager rules change: `make manager`.
Engine change: `bash scripts/build-core.sh`, then
`docker restart power-ens-lab-engine-1`.
Agent change: `bash scripts/build-core.sh`; the next hourly pass (minute 17)
runs it, or run it now:
`docker exec power-ens-lab-agent-01-1 /opt/oscompliance/oscompliance-agent`.
Rule change in `catalog/wazuh/`: `make manager`.

## Configuration

`lab.conf` holds paths, versions, ports and lab-only credentials. Local
overrides go in `lab.conf.local` (not versioned).

| Variable | Default | Purpose |
|---|---|---|
| `COMPOSE_PROJECT_NAME` | `power-ens-lab` | Prefix for containers, volumes and network |
| `WAZUH_VERSION` | `4.14.7` | Wazuh images and agent package |
| `PLUGIN_SRC` | plugin repository path | Plugin source, mounted read-only |
| `CORE_SRC` | `oscompliance-ens` path | Agent source and manager rules (`catalog/wazuh/`) |
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
| `ens` group, OSCompliance rules, the engine's Wazuh API user | `scripts/manager-setup.sh` | Configuration valid, API user created |
| First configuration save, seeding, validation | `scripts/seed.sh` | `APPLIED` per control, document valid |
| OSCompliance engine, one pass every 5 minutes | `engine` service | Its region in the `ens` group configuration |
| Agent `lab-agent-01` | `agent-01` service | Agent active, OSCompliance facts (rule 119001) indexed, verdicts in `oscompliance-verdicts`, agent in inventory |

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
- The plugin is installed from its zip, as in a customer deployment.
- Sources are mounted read-only.
- The agent container runs rsyslog and sshd and makes one key-based login as
  `jperez` at startup, so `auth.log` carries a real login (op.acc.1 EV-03).
  `manager-setup.sh` adds `/var/log/auth.log` to the `ens` group for it.
- `oscompliance-agent` only runs: its `<localfile>` and the paths it reads
  reach it through the `ens` group `agent.conf`, which the engine writes from
  the ENS configuration through the Wazuh API (`-sync-apply`). Lab parameter
  values: `scripts/lab-parameters.json`.
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

- The manager sends no facts yet: its op.acc rows come out not evidenced.
- One agent.
- op.acc.1.5 and op.acc.1.r1.1 have no catalog evidence in plugin 1.4.0 and
  never pass.
