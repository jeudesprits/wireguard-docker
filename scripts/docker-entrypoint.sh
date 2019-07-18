#!/bin/bash

set -e

function install () {
    # Install Wireguard. This has to be done dynamically since the kernel
    # module depends on the host kernel version.
    add-apt-repository -y ppa:wireguard/wireguard 
    apt-get update -y
    apt-get install -y linux-headers-"$(uname -r)"
    apt-get install -y wireguard
    apt-get autoremove -y
    apt-get clean -y
    rm -rf /var/lib/apt/lists/*
}

function generateConfigs () { 
    # Detect public interface and pre-fill for the user
    SERVER_PUB_IPV4=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
    read -rp "IPv4 or IPv6 public address: " -e -i "$SERVER_PUB_IPV4" SERVER_PUB_IP 

    SERVER_PUB_NIC="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"

    SERVER_WG_NIC="wg0"

    SERVER_WG_IPV4="10.66.66.1"

    SERVER_PORT="1194"
    read -rp "Server's WireGuard port " -e -i "$SERVER_PORT" SERVER_PORT

    CLIENT_WG_IPV4="10.66.66.2"

    echo "Tell me a name for the client."
	echo "Use one word only, no special characters."
	until [[ "$CLIENT" =~ ^[a-zA-Z0-9_-]+$ ]]; do
		read -rp "Client name: " -e CLIENT
	done

    CLIENT_DNS_1="8.8.8.8"
    read -rp "First DNS resolver to use for the client: " -e -i "$CLIENT_DNS_1" CLIENT_DNS_1

    CLIENT_DNS_2="8.8.4.4"
    read -rp "Second DNS resolver to use for the client: " -e -i "$CLIENT_DNS_2" CLIENT_DNS_2

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
Address = $SERVER_WG_IPV4/24
ListenPort = $SERVER_PORT
PrivateKey = $SERVER_PRIV_KEY
PostUp = iptables -t nat -A POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE; ip6tables -t nat -A POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE; ip6tables -t nat -D POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE" > "/etc/wireguard/$SERVER_WG_NIC.conf"

    # Add the client as a peer to the server
    echo "[Peer]
PublicKey = $CLIENT_PUB_KEY
AllowedIPs = $CLIENT_WG_IPV4/32" >> "/etc/wireguard/$SERVER_WG_NIC.conf"

    # Create client file with interface
    echo "[Interface]
PrivateKey = $CLIENT_PRIV_KEY
Address = $CLIENT_WG_IPV4/24
DNS = $CLIENT_DNS_1,$CLIENT_DNS_2" > "/etc/wireguard/$CLIENT-client.conf"

    # Add the server as a peer to the client
    echo "[Peer]
PublicKey = $SERVER_PUB_KEY
Endpoint = $ENDPOINT
AllowedIPs = 0.0.0.0/0" >> "/etc/wireguard/$CLIENT-client.conf"

    # Add pre shared symmetric key to respective files
    CLIENT_SYMM_PRE_KEY=$( wg genpsk )
    echo "PresharedKey = $CLIENT_SYMM_PRE_KEY" >> "/etc/wireguard/$SERVER_WG_NIC.conf"
    echo "PresharedKey = $CLIENT_SYMM_PRE_KEY" >> "/etc/wireguard/$CLIENT-client.conf"
 
    chmod 600 -R /etc/wireguard/
}

function shutdown () {
    echo "Shutting down Wireguard"
    wg-quick down "$SERVER_WG_NIC"
    exit 0
}

install "$@"

generateConfigs "$@"

echo "Starting Wireguard"
wg-quick up "$SERVER_WG_NIC"

# Handle shutdown behavior
trap shutdown SIGTERM SIGINT SIGQUIT

sleep infinity &
wait $!