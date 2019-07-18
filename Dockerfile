FROM ubuntu:bionic

RUN apt-get update -y \
    && apt-get install -y software-properties-common apt-utils iptables curl iproute2 ifupdown iputils-ping bash \
    && echo resolvconf resolvconf/linkify-resolvconf boolean false | debconf-set-selections \
    && echo "REPORT_ABSENT_SYMLINK=no" >> /etc/default/resolvconf \
    && add-apt-repository --yes ppa:wireguard/wireguard \
    && apt-get install resolvconf \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

COPY scripts /scripts

ENTRYPOINT ["/bin/bash", "/scripts/docker-entrypoint.sh"]

CMD ["jeudesprits-iOS"]