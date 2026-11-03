ARG WAZUH_VERSION
FROM wazuh/wazuh-dashboard:${WAZUH_VERSION}
ARG POWER_ENS_VERSION
COPY --chown=wazuh-dashboard:wazuh-dashboard power-ens-2.19.5.zip /tmp/power-ens-2.19.5.zip
RUN /usr/share/wazuh-dashboard/bin/opensearch-dashboards-plugin install file:///tmp/power-ens-2.19.5.zip \
 && rm /tmp/power-ens-2.19.5.zip
USER root
RUN python3 -c "import json,time; f='/usr/share/wazuh-dashboard/package.json'; p=json.load(open(f)); p['build']['number']=str(int(p['build']['number'])+int(time.time())//60%1000000); json.dump(p,open(f,'w'),indent=2)"
USER wazuh-dashboard
