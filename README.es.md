# wazuh-lab-docker

[English version](README.md)

Un entorno local de pruebas de extremo a extremo para Power ENS. Ejecuta Wazuh 4.14.7 (indexer, manager y dashboard) con el plugin Power ENS, las reglas de OSCompliance, un contenedor con el motor y un agente Ubuntu con `oscompliance-agent`. Todo se compila desde las fuentes locales.

Es para desarrollo. Sus credenciales son públicas y tiene un solo agente.

## Requisitos

- Docker con Compose v2 y 12 GB de memoria. Probado en OrbStack sobre Apple Silicon.
- Go, para compilar el agente y el motor.
- Los repositorios power-ens y oscompliance-ens junto a este, o en las rutas indicadas en `lab.conf.local`.
- La imagen de compilación del plugin. En el repositorio power-ens, ejecuta una vez `ci/build-zip.sh 2.19.5`.

## Uso

Arranca el laboratorio. Desde cero tarda unos 3 minutos.

```bash
make up
```

El dashboard está en https://localhost:8443, usuario `admin`, contraseña `SecretPassword`. Su certificado está firmado por la CA del laboratorio.

Comprueba los contenedores, los agentes y los hechos recibidos.

```bash
make status
```

Elimina los contenedores, los volúmenes y los certificados.

```bash
make down
```

`make logs S=<servicio>` sigue el registro de un servicio. `make seed` repite la carga y la validación de la configuración.

## Aplicar un cambio

Plugin: `REBUILD=1 make up`. `make build-plugin` solo compila el zip.

Reglas de `catalog/wazuh/`: `make manager`.

Motor: `bash scripts/build-core.sh` y después `docker restart power-ens-lab-engine-1`.

Agente: `bash scripts/build-core.sh`. Lo ejecuta la siguiente pasada horaria, en el minuto 17. Para ejecutarlo ya:

```bash
docker exec power-ens-lab-agent-01-1 oscompliance-agent
```

## Configuración

`lab.conf` guarda rutas, versiones, puertos y credenciales del laboratorio. Los cambios locales van en `lab.conf.local`, que no se versiona. Los habituales son `PLUGIN_SRC` y `CORE_SRC` (las rutas de las fuentes), `WAZUH_VERSION` y `DASHBOARD_PORT`.

## Qué hace make up

Cada paso es un script de `scripts/`, y todos se pueden repetir.

1. `certs.sh` crea la CA del laboratorio y los certificados en `certs/`.
2. `build-plugin.sh` compila el zip del plugin en `build/`.
3. `build-core.sh` compila el agente y el motor en `build/oscompliance/`. Siempre los recompila.
4. `docker-compose.yml` arranca el indexer, el manager y el dashboard.
5. `dashboard-setup.sh` pone el intervalo de inventario de agentes en 60 segundos. El plugin lee los agentes de `wazuh-monitoring-*`, que por defecto se escribe cada 900 segundos.
6. `manager-setup.sh` crea el grupo `ens`, las reglas y el usuario de API del motor.
7. `seed.sh` guarda la primera configuración y la valida.
8. El servicio `engine` hace una pasada cada 5 minutos y escribe su bloque en la configuración del grupo.
9. El servicio `agent-01` se registra, y sus hechos llegan al índice con la regla 119001.

## En qué se diferencia de wazuh-docker

El laboratorio parte del despliegue single-node oficial de wazuh-docker 4.14.7. El dashboard y el manager usan las imágenes de `images/`, un servicio `agent-01` ejecuta Ubuntu con el agente de Wazuh y `oscompliance-agent`, y solo se publica el dashboard, en `127.0.0.1`. Así el laboratorio puede convivir con otros despliegues de Wazuh en el mismo host.

Las fuentes se montan en solo lectura y el plugin se instala desde su zip, como en un despliegue real. Los valores de los parámetros del laboratorio están en `scripts/lab-parameters.json`.

El contenedor del agente ejecuta rsyslog y sshd y hace un inicio de sesión con clave como `jperez` al arrancar, para que `auth.log` contenga un inicio de sesión real para op.acc.1 EV-03.

## Problemas conocidos

En macOS, el generador de certificados deja `certs/` en solo lectura y omite `root-ca-manager.*`. `scripts/certs.sh` lo resuelve.

Un agente recreado sin su `client.keys` se rechaza por nombre duplicado. Por eso el `/var/ossec/etc` del agente es un volumen.

logcollector se salta el contenido existente de un fichero recién descubierto, así que el agente crea sus ficheros de hechos vacíos antes de arrancar.
