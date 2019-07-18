FROM ubuntu:bionic

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends software-properties-common bash curl iptables iproute2 \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

COPY scripts /scripts

ENTRYPOINT ["bash", "/scripts/docker-entrypoint.sh"]

CMD []