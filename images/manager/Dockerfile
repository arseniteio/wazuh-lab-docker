# Wazuh manager with what the runbooks' install-manager.sh and emitter need
# and the official image lacks (plugin guide 06 §13.1-13.2):
#   jq              installers and emitter
#   util-linux-core flock, so the emitter never interleaves lines
#   hostname        `host` field of every fact
ARG WAZUH_VERSION
FROM wazuh/wazuh-manager:${WAZUH_VERSION}
RUN dnf install -y jq util-linux-core hostname && dnf clean all
