ARG WAZUH_VERSION
FROM wazuh/wazuh-manager:${WAZUH_VERSION}

RUN dnf install -y rsyslog openssh-server openssh-clients procps-ng shadow-utils passwd sudo \
 && dnf clean all \
 && sed -i 's/SysSock.Use="off"/SysSock.Use="on"/; /^module(load="imjournal"/,/StateFile/d' /etc/rsyslog.conf \
 && ssh-keygen -A

RUN install -d -m 750 /var/log/oscompliance && install -m 640 /dev/null /var/log/oscompliance/facts.ndjson

COPY services/ /etc/services.d/
RUN chmod 755 /etc/services.d/*/run
