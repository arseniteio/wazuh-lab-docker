ARG WAZUH_VERSION
FROM wazuh/wazuh-dashboard:${WAZUH_VERSION}
ARG POWER_ENS_VERSION
COPY --chown=wazuh-dashboard:wazuh-dashboard power-ens-2.19.5.zip /tmp/power-ens-2.19.5.zip
RUN /usr/share/wazuh-dashboard/bin/opensearch-dashboards-plugin install file:///tmp/power-ens-2.19.5.zip \
 && rm /tmp/power-ens-2.19.5.zip
USER root
RUN python3 -c "import json,sys; f='/usr/share/wazuh-dashboard/package.json'; p=json.load(open(f)); v=[int(x) for x in sys.argv[1].split('.')]; p['build']['number']=str(int(p['build']['number'])+v[0]*10000+v[1]*100+v[2]); json.dump(p, open(f,'w'), indent=2); print('build.number', p['build']['number'])" "$POWER_ENS_VERSION"
USER wazuh-dashboard
