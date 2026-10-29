# Wazuh manager of the lab, audited like any other machine: oscompliance-agent
# (mounted at /opt/oscompliance) runs every hour, and sshd and rsyslog leave a
# real authentication log for Wazuh to read.
ARG WAZUH_VERSION
FROM wazuh/wazuh-manager:${WAZUH_VERSION}

RUN dnf install -y rsyslog openssh-server openssh-clients procps-ng shadow-utils passwd sudo \
 && dnf clean all \
 && sed -i 's/SysSock.Use="off"/SysSock.Use="on"/; /^module(load="imjournal"/,/StateFile/d' /etc/rsyslog.conf \
 && ssh-keygen -A

# The fact file exists empty before logcollector first looks: it skips what a file already holds then.
RUN install -d -m 750 /var/log/oscompliance && install -m 640 /dev/null /var/log/oscompliance/facts.ndjson

COPY services/ /etc/services.d/
RUN chmod 755 /etc/services.d/*/run
