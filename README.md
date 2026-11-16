# wazuh-lab-docker

[Versión en español](README.es.md)

A local end-to-end test environment for Power ENS. It runs Wazuh 4.14.7 (indexer, manager and dashboard) with the Power ENS plugin, the OSCompliance rules, an engine container and an Ubuntu agent running `oscompliance-agent`. Everything is built from the local sources.

It is for development. Its credentials are public and it has one agent.

## Requirements

- Docker with Compose v2, with 12 GB of memory. Tested on OrbStack on Apple Silicon.
- Go, to build the agent and the engine.
- The power-ens-wazuh and oscompliance-ens-wazuh repositories next to this one, or at the paths set in `lab.conf.local`.
- The plugin builder image. In the power-ens-wazuh repository, run `ci/build-zip.sh 2.19.5` once.

## Use

Start the lab. From scratch it takes about 3 minutes.

```bash
make up
```

The dashboard is at https://localhost:8443, user `admin`, password `SecretPassword`. Its certificate is signed by the lab CA.

Check the containers, the agents and the facts received.

```bash
make status
```

Remove the containers, the volumes and the certificates.

```bash
make down
```

`make logs S=<service>` follows a service log. `make seed` repeats the configuration seeding and validation.

## Apply a change

Plugin: `REBUILD=1 make up`. `make build-plugin` only builds the zip.

Rules in `catalog/wazuh/`: `make manager`.

Engine: `bash scripts/build-core.sh`, then `docker restart power-ens-lab-engine-1`.

Agent: `bash scripts/build-core.sh`. The next hourly pass, at minute 17, runs it. To run it now:

```bash
docker exec power-ens-lab-agent-01-1 oscompliance-agent
```

## Configuration

`lab.conf` holds paths, versions, ports and lab credentials. Local overrides go in `lab.conf.local`, which is not versioned. The usual ones are `PLUGIN_SRC` and `CORE_SRC` (the source paths), `WAZUH_VERSION` and `DASHBOARD_PORT`.

## What make up does

Each step is a script in `scripts/`, and all of them can be repeated.

1. `certs.sh` creates the lab CA and the certificates in `certs/`.
2. `build-plugin.sh` builds the plugin zip in `build/`.
3. `build-core.sh` builds the agent and the engine in `build/oscompliance/`. It always rebuilds them.
4. `docker-compose.yml` starts the indexer, the manager and the dashboard.
5. `dashboard-setup.sh` sets the agent inventory interval to 60 seconds. The plugin reads agents from `wazuh-monitoring-*`, written every 900 seconds by default.
6. `manager-setup.sh` creates the `ens` group, the rules and the engine's API user.
7. `seed.sh` saves the first configuration and validates it.
8. The `engine` service runs a pass every 5 minutes and writes its block in the group configuration.
9. The `agent-01` service enrols, and its facts reach the index as rule 119001.

## How it differs from wazuh-docker

The lab starts from the official wazuh-docker 4.14.7 single-node deployment. The dashboard and the manager use the images in `images/`, an `agent-01` service runs Ubuntu with the Wazuh agent and `oscompliance-agent`, and only the dashboard is published, on `127.0.0.1`. That lets the lab run next to other Wazuh deployments on the same host.

The sources are mounted read-only and the plugin is installed from its zip, as in a real deployment. Lab parameter values are in `scripts/lab-parameters.json`.

The agent container runs rsyslog and sshd and makes one key-based login as `jperez` at startup, so `auth.log` holds a real login for op.acc.1 EV-03.

## Known issues

On macOS, the certificate generator leaves `certs/` read-only and omits `root-ca-manager.*`. `scripts/certs.sh` handles it.

A recreated agent without its `client.keys` is rejected as a duplicate name. The agent's `/var/ossec/etc` is a volume for that reason.

logcollector skips the existing content of a newly discovered file, so the agent creates its fact files empty before starting.

## License

Copyright (c) 2026 Arsenite.

wazuh-lab-docker is licensed under the GNU Affero General Public License version 3 (AGPL-3.0-only). See [LICENSE](LICENSE). The Wazuh configuration files in `config/` come from wazuh-docker and keep their original licenses, GPL-2.0 and Apache-2.0. See [config/NOTICE](config/NOTICE).

Arsenite also offers wazuh-lab-docker under a commercial license, for organisations that cannot meet the obligations of the AGPL, such as keeping changes private in a product or a network service. Contact devqs@quersystem.com for terms.
