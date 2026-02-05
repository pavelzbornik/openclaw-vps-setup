FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV container=docker

# systemd + sshd + python for Ansible
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        systemd \
        systemd-sysv \
        dbus \
        openssh-server \
        python3 \
        python3-apt \
        locales \
        sudo \
        ca-certificates \
        curl \
        iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Minimal sshd setup (dev-only)
RUN mkdir -p /var/run/sshd /root/.ssh \
    && chmod 700 /root/.ssh \
    && sed -ri 's/^#?PermitRootLogin\s+.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config \
    && sed -ri 's/^#?PasswordAuthentication\s+.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -ri 's/^#?PubkeyAuthentication\s+.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Enable ssh service when systemd boots
RUN ln -sf /lib/systemd/system/ssh.service /etc/systemd/system/multi-user.target.wants/ssh.service

# Avoid some noisy/unsupported units in containers
RUN systemctl mask \
      dev-hugepages.mount \
      sys-fs-fuse-connections.mount \
      sys-kernel-config.mount \
      sys-kernel-debug.mount \
      systemd-modules-load.service \
      systemd-remount-fs.service \
      systemd-udevd.service \
      systemd-udevd-control.socket \
      systemd-udevd-kernel.socket \
      systemd-logind.service \
      getty.target \
      console-getty.service \
      || true

STOPSIGNAL SIGRTMIN+3

CMD ["/lib/systemd/systemd"]
