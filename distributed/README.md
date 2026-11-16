# Distributed Wazuh lab

[Versión en español](README.es.md)

A local distributed Wazuh 4.14.9 deployment installed from the official packages with the official installation assistant. It mirrors a customer topology with one container per host, each with its own hostname, IP address and systemd as PID 1. It is for testing installers that must detect the role of each host.

It is for development. The passwords are generated at install time and stay on this machine.

## Topology

| Host | IP | OS | Role |
| --- | --- | --- | --- |
| wazuh-idx-01 | 192.168.250.11 | Rocky Linux 9 | Indexer |
| wazuh-idx-02 | 192.168.250.12 | Rocky Linux 9 | Indexer |
| wazuh-idx-03 | 192.168.250.13 | Rocky Linux 9 | Indexer |
| wazuh-mgr-01 | 192.168.250.21 | Rocky Linux 9 | Manager, cluster master |
| wazuh-mgr-02 | 192.168.250.22 | Rocky Linux 9 | Manager, cluster worker |
| wazuh-dash-01 | 192.168.250.31 | Rocky Linux 9 | Dashboard, https://localhost:8453 |
| wazuh-dash-02 | 192.168.250.32 | Rocky Linux 9 | Dashboard, https://localhost:8454 |
| agent-01 | 192.168.250.41 | Rocky Linux 9 | Agent, reports to wazuh-mgr-01 |
| agent-02 | 192.168.250.42 | Ubuntu 22.04 | Agent, reports to wazuh-mgr-02 |

The manager API of wazuh-mgr-01 is published on https://localhost:55010. Paths are the package defaults: `/var/ossec`, `/etc/filebeat`, `/etc/wazuh-indexer`, `/usr/share/wazuh-dashboard`. Filebeat on each manager points at the three indexers.

## Requirements

- Docker with Compose v2, about 6 GB of free memory and 40 GB of free disk. Tested on OrbStack on Apple Silicon.
- Internet access during the installation, for the packages and the assistant.

## Use

Start the lab. Without snapshot images, it installs Wazuh first, which takes about 15 minutes.

```bash
make up
```

Log in to a dashboard as `admin`. The password is in `wazuh-passwords.txt`, which is not versioned.

Check systemd, the indexer cluster, the manager cluster, the agents and the dashboards.

```bash
make status
```

Return every host to the clean Wazuh state after a test.

```bash
make reset
```

Open a shell on a host, or run a script on it.

```bash
docker exec -it power-ens-dist-wazuh-mgr-01-1 bash
docker cp ./installer power-ens-dist-wazuh-mgr-01-1:/root/installer
docker exec -it power-ens-dist-wazuh-mgr-01-1 bash /root/installer/install.sh server
```

Remove the containers. The snapshot images and the passwords are kept.

```bash
make down
```

## Targets

- `make up` starts the hosts from the snapshot images, or runs `make install` when they do not exist.
- `make install` recreates the hosts from the base images, installs Wazuh and takes a new snapshot.
- `make snapshot` stops the hosts and commits each one to `power-ens-dist/<host>:wazuh`.
- `make reset` recreates the hosts from the snapshot images.
- `make status` shows the state of the deployment.
- `make down` removes the containers.

## What make install does

1. Builds `wazuh-install.sh` from the `v4.14.9` tag of wazuh-installation-assistant. The script on packages.wazuh.com always installs the latest 4.14 release.
2. Runs `--generate-config-files` with `config/config.yml` on wazuh-mgr-01. `wazuh-install-files.tar` is shared with every host through `shared/`, mounted on `/lab`.
3. Runs `--wazuh-indexer` on the three indexers, sets the JVM heap to 512 MB and runs `--start-cluster`.
4. Runs `--wazuh-server` on both managers and `--wazuh-dashboard` on both dashboards.
5. Installs the agents from the Wazuh repository with `WAZUH_MANAGER` set, plus auditd and cron.
6. Waits for a healthy deployment, removes core dumps and takes the snapshot.

Assistant logs are in `shared/logs/`.

## Known issues

- auditd is installed and enabled on the agents but does not run. The kernel accepts audit requests only from the initial PID namespace, so `systemctl is-system-running` reports `degraded` on the agents.
- Each manager downloads about 9 GB of vulnerability content to `/var/ossec/queue/vd`, so its snapshot image is about 10 GB and committing it takes a few minutes.
- The hosts are privileged containers. Do not expose them outside the machine.
