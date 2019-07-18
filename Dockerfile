FROM ubuntu:bionic

RUN add-apt-repository -y ppa:wireguard/wireguard \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends bash iptables wireguard \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

COPY scripts /scripts

ENTRYPOINT ["/bin/bash", "/scripts/docker-entrypoint.sh"]

CMD []