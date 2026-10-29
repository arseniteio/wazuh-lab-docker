# Audited machine of the lab: Ubuntu 24.04 with wazuh-agent and cron, which runs
# oscompliance-agent.
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
 # The package reads WAZUH_MANAGER and WAZUH_AGENT_GROUP at install time and
 # writes them to ossec.conf: the agent enrolls by itself, in the ens group.
 && WAZUH_MANAGER=wazuh.manager WAZUH_AGENT_GROUP=ens \
      apt-get install -y wazuh-agent=${WAZUH_VERSION}-1 \
 && rm -rf /var/lib/apt/lists/*

# sshd and rsyslog for op.acc.1 EV-03 (an auth.log with real logins). In
# their own layer AFTER wazuh-agent: their system users must not shift the
# wazuh UID/GID, which the agent01_ossec_etc volume keeps from earlier builds.
# No kernel log in a container: rsyslog would only complain about imklog.
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-server openssh-client rsyslog \
 && rm -rf /var/lib/apt/lists/* \
 && sed -i 's/^module(load="imklog"/#&/' /etc/rsyslog.conf

# Person accounts so op.acc.1 has something to observe.
RUN useradd -m -s /bin/bash -u 1001 jperez \
 && useradd -m -s /bin/bash -u 1002 mgarcia

COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
