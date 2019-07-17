FROM ubuntu:bionic

RUN apt update -y \
    && apt install -y software-properties-common iptables curl iproute2 ifupdown iputils-ping \
    && echo resolvconf resolvconf/linkify-resolvconf boolean false | debconf-set-selections \
    && echo "REPORT_ABSENT_SYMLINK=no" >> /etc/default/resolvconf \
    && add-apt-repository --yes ppa:wireguard/wireguard \
    && apt install resolvconf \
    && apt autoremove -y \
    && apt clean -y \
    && rm -rf /var/lib/apt/lists/*

COPY scripts /scripts

ENTRYPOINT ["sh", "/scripts/docker-entrypoint.sh", "jeudesprits-iOS"]