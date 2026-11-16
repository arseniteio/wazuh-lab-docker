FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends systemd systemd-sysv dbus procps \
        iproute2 curl ca-certificates gnupg lsb-release less \
    && rm -rf /var/lib/apt/lists/* \
    && systemctl mask systemd-logind.service getty.target console-getty.service \
        sys-kernel-debug.mount dev-hugepages.mount systemd-remount-fs.service \
    && systemctl set-default multi-user.target

STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
