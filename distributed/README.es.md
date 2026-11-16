# Laboratorio Wazuh distribuido

[English version](README.md)

Un despliegue local distribuido de Wazuh 4.14.9 instalado desde los paquetes oficiales con el asistente de instalación oficial. Reproduce la topología de un cliente con un contenedor por host, cada uno con su nombre, su dirección IP y systemd como PID 1. Sirve para probar instaladores que deben detectar el papel de cada host.

Es para desarrollo. Las contraseñas se generan durante la instalación y no salen de esta máquina.

## Topología

| Host | IP | SO | Papel |
| --- | --- | --- | --- |
| wazuh-idx-01 | 192.168.250.11 | Rocky Linux 9 | Indexer |
| wazuh-idx-02 | 192.168.250.12 | Rocky Linux 9 | Indexer |
| wazuh-idx-03 | 192.168.250.13 | Rocky Linux 9 | Indexer |
| wazuh-mgr-01 | 192.168.250.21 | Rocky Linux 9 | Manager, maestro del clúster |
| wazuh-mgr-02 | 192.168.250.22 | Rocky Linux 9 | Manager, worker del clúster |
| wazuh-dash-01 | 192.168.250.31 | Rocky Linux 9 | Dashboard, https://localhost:8453 |
| wazuh-dash-02 | 192.168.250.32 | Rocky Linux 9 | Dashboard, https://localhost:8454 |
| agent-01 | 192.168.250.41 | Rocky Linux 9 | Agente, reporta a wazuh-mgr-01 |
| agent-02 | 192.168.250.42 | Ubuntu 22.04 | Agente, reporta a wazuh-mgr-02 |

La API del manager de wazuh-mgr-01 está publicada en https://localhost:55010. Las rutas son las de los paquetes: `/var/ossec`, `/etc/filebeat`, `/etc/wazuh-indexer`, `/usr/share/wazuh-dashboard`. Filebeat apunta en cada manager a los tres indexers.

## Requisitos

- Docker con Compose v2, unos 6 GB de memoria libre y 40 GB de disco libre. Probado en OrbStack sobre Apple Silicon.
- Acceso a internet durante la instalación, para los paquetes y el asistente.

## Uso

Arranca el laboratorio. Sin imágenes de snapshot instala Wazuh primero, lo que tarda unos 15 minutos.

```bash
make up
```

Entra en un dashboard como `admin`. La contraseña está en `wazuh-passwords.txt`, que no se versiona.

Comprueba systemd, el clúster de indexers, el clúster de managers, los agentes y los dashboards.

```bash
make status
```

Devuelve todos los hosts al estado limpio de Wazuh después de una prueba.

```bash
make reset
```

Abre una shell en un host o ejecuta un script en él.

```bash
docker exec -it power-ens-dist-wazuh-mgr-01-1 bash
docker cp ./installer power-ens-dist-wazuh-mgr-01-1:/root/installer
docker exec -it power-ens-dist-wazuh-mgr-01-1 bash /root/installer/install.sh server
```

Elimina los contenedores. Las imágenes de snapshot y las contraseñas se conservan.

```bash
make down
```

## Objetivos

- `make up` arranca los hosts desde las imágenes de snapshot, o ejecuta `make install` si no existen.
- `make install` recrea los hosts desde las imágenes base, instala Wazuh y toma un snapshot nuevo.
- `make snapshot` para los hosts y guarda cada uno en `power-ens-dist/<host>:wazuh`.
- `make reset` recrea los hosts desde las imágenes de snapshot.
- `make status` muestra el estado del despliegue.
- `make down` elimina los contenedores.

## Qué hace make install

1. Construye `wazuh-install.sh` desde la etiqueta `v4.14.9` de wazuh-installation-assistant. El script de packages.wazuh.com instala siempre la última versión 4.14.
2. Ejecuta `--generate-config-files` con `config/config.yml` en wazuh-mgr-01. `wazuh-install-files.tar` se comparte con todos los hosts a través de `shared/`, montado en `/lab`.
3. Ejecuta `--wazuh-indexer` en los tres indexers, fija el heap de la JVM en 512 MB y ejecuta `--start-cluster`.
4. Ejecuta `--wazuh-server` en los dos managers y `--wazuh-dashboard` en los dos dashboards.
5. Instala los agentes desde el repositorio de Wazuh con `WAZUH_MANAGER`, junto con auditd y cron.
6. Espera a que el despliegue esté sano, borra los core dumps y toma el snapshot.

Los logs del asistente están en `shared/logs/`.

## Problemas conocidos

- auditd está instalado y habilitado en los agentes, pero no arranca. El kernel solo acepta peticiones de auditoría desde el espacio de nombres de PID inicial, así que `systemctl is-system-running` devuelve `degraded` en los agentes.
- Cada manager descarga unos 9 GB de contenido de vulnerabilidades en `/var/ossec/queue/vd`, así que su imagen de snapshot ocupa unos 10 GB y guardarla tarda unos minutos.
- Los hosts son contenedores privilegiados. No los expongas fuera de la máquina.
