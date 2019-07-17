#!/bin/bash

set -e

install () {
    # Install Wireguard. This has to be done dynamically since the kernel
    # module depends on the host kernel version.
    apt update
    apt install -y linux-headers-"$(uname -r)"
    apt install -y wireguard
}

generateConfigs () { 
    # Detect public IPv4 address and pre-fill for the user
    SERVER_PUB_IP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)

    # Detect public interface and pre-fill for the user
    SERVER_PUB_NIC="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"

    SERVER_WG_NIC="wg0"

    SERVER_WG_IPV4="10.66.66.1"

    SERVER_WG_IPV6="fd42:42:42::1"

    SERVER_PORT=1194

    CLIENT_WG_IPV4="10.66.66.2"

    CLIENT_WG_IPV6="fd42:42:42::2"

    CLIENT_DNS_1="8.8.8.8"

    CLIENT_DNS_2="8.8.4.4"

    if [[ $SERVER_PUB_IP =~ .*:.* ]]
    then
    ENDPOINT="[$SERVER_PUB_IP]:$SERVER_PORT"
    else
    ENDPOINT="$SERVER_PUB_IP:$SERVER_PORT"
    fi

    # Generate key pair for the server
    SERVER_PRIV_KEY=$(wg genkey)
    SERVER_PUB_KEY=$(echo "$SERVER_PRIV_KEY" | wg pubkey)

    # Generate key pair for the server
    CLIENT_PRIV_KEY=$(wg genkey)
    CLIENT_PUB_KEY=$(echo "$CLIENT_PRIV_KEY" | wg pubkey)

    # Add server interface
    echo "[Interface]
    Address = $SERVER_WG_IPV4/24,$SERVER_WG_IPV6/64
    ListenPort = $SERVER_PORT
    PrivateKey = $SERVER_PRIV_KEY
    PostUp = iptables -t nat -A POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE; ip6tables -t nat -A POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE
    PostDown = iptables -t nat -D POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE; ip6tables -t nat -D POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE" > "/etc/wireguard/$SERVER_WG_NIC.conf"

    # Add the client as a peer to the server
    echo "[Peer]
    PublicKey = $CLIENT_PUB_KEY
    AllowedIPs = $CLIENT_WG_IPV4/32,$CLIENT_WG_IPV6/128" >> "/etc/wireguard/$SERVER_WG_NIC.conf"

    # Create client file with interface
    echo "[Interface]
    PrivateKey = $CLIENT_PRIV_KEY
    Address = $CLIENT_WG_IPV4/24,$CLIENT_WG_IPV6/64
    DNS = $CLIENT_DNS_1,$CLIENT_DNS_2" > "/etc/wireguard/$1-client.conf"

    # Add the server as a peer to the client
    echo "[Peer]
    PublicKey = $SERVER_PUB_KEY
    Endpoint = $ENDPOINT
    AllowedIPs = 0.0.0.0/0,::/0" >> "/etc/wireguard/$1-client.conf"

    # Add pre shared symmetric key to respective files
    CLIENT_SYMM_PRE_KEY=$( wg genpsk )
    echo "PresharedKey = $CLIENT_SYMM_PRE_KEY" >> "/etc/wireguard/$SERVER_WG_NIC.conf"
    echo "PresharedKey = $CLIENT_SYMM_PRE_KEY" >> "/etc/wireguard/$1-client.conf"
 
    chmod 600 -R /etc/wireguard/
}

shutdown () {
    echo "$(date): Shutting down Wireguard"
    wg-quick down "$interface"
    exit 0
}

install "$@"

generateConfigs "$@"

echo "$(date): Starting Wireguard"
wg-quick up "$SERVER_WG_NIC"

# Handle shutdown behavior
trap shutdown SIGTERM SIGINT SIGQUIT

sleep infinity &
wait $!