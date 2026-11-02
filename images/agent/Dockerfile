FROM ubuntu:24.04
ARG WAZUH_VERSION
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg cron jq python3 util-linux passwd acl procps sudo \
 && curl -fsSL https://packages.wazuh.com/key/GPG-KEY-WAZUH \
      | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
      > /etc/apt/sources.list.d/wazuh.list \
 && apt-get update \
 && WAZUH_MANAGER=wazuh.manager WAZUH_AGENT_GROUP=ens \
      apt-get install -y wazuh-agent=${WAZUH_VERSION}-1 \
 && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-server openssh-client rsyslog \
 && rm -rf /var/lib/apt/lists/* \
 && sed -i 's/^module(load="imklog"/#&/' /etc/rsyslog.conf

RUN apt-get update \
 && apt-get install -y --no-install-recommends clamav clamav-daemon clamav-freshclam clamdscan \
 && rm -rf /var/lib/apt/lists/* \
 && sed -i 's/^LogSyslog false/LogSyslog true/' /etc/clamav/clamd.conf

RUN useradd -m -s /bin/bash -u 1001 jperez \
 && useradd -m -s /bin/bash -u 1002 mgarcia

COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
