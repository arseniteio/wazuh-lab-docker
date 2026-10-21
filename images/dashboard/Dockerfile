# Wazuh dashboard with ENSFácil installed, as in plugin guide 06 §3.
# scripts/up.sh copies the zip here as ensfacil-2.19.5.zip before building.
ARG WAZUH_VERSION
FROM wazuh/wazuh-dashboard:${WAZUH_VERSION}
ARG ENSFACIL_VERSION
COPY --chown=wazuh-dashboard:wazuh-dashboard ensfacil-2.19.5.zip /tmp/ensfacil-2.19.5.zip
RUN /usr/share/wazuh-dashboard/bin/opensearch-dashboards-plugin install file:///tmp/ensfacil-2.19.5.zip \
 && rm /tmp/ensfacil-2.19.5.zip
# build.number = the official one + X*10000 + Y*100 + Z: every ENSFácil version
# changes it, so browsers never serve files of the previous one from cache.
USER root
RUN python3 -c "import json,sys; f='/usr/share/wazuh-dashboard/package.json'; p=json.load(open(f)); v=[int(x) for x in sys.argv[1].split('.')]; p['build']['number']=str(int(p['build']['number'])+v[0]*10000+v[1]*100+v[2]); json.dump(p, open(f,'w'), indent=2); print('build.number', p['build']['number'])" "$ENSFACIL_VERSION"
USER wazuh-dashboard
