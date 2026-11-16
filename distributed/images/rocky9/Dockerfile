FROM rockylinux:9

RUN dnf -y install --allowerasing coreutils curl \
    && dnf -y install systemd procps-ng iproute hostname which findutils tar gzip \
        openssl sudo less cronie \
    && dnf clean all \
    && systemctl mask systemd-logind.service getty.target console-getty.service \
        sys-kernel-debug.mount dev-hugepages.mount systemd-remount-fs.service \
    && systemctl enable crond.service \
    && systemctl set-default multi-user.target

STOPSIGNAL SIGRTMIN+3
CMD ["/usr/sbin/init"]
