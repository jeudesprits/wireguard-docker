#!/bin/bash

 # Detect public interface and pre-fill for the user
SERVER_PUB_IPV4=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
read -rp "IPv4 or IPv6 public address: " -e -i "$SERVER_PUB_IPV4" SERVER_PUB_IP 

SERVER_WG_NIC="wg0"

echo "Tell me a name for the client."
echo "Use one word only, no special characters."
until [[ "$CLIENT" =~ ^[a-zA-Z0-9_-]+$ ]]; do
    read -rp "Client name: " -e CLIENT
done

# Generate peer keys
CLIENT_PRIV_KEY="$(wg genkey)"

CLIENT_PUB_KEY="$(echo "$CLIENT_PRIV_KEY" | wg pubkey)"

CLIENT_SYMM_PRE_KEY="$(wg genpsk)"
# Read server key from interface
SERVER_PUB_KEY="$(wg show "$SERVER_WG_NIC" public-key)"
# Get next free peer IP (This will break after x.x.x.255)
PEER_ADDRESS="$(wg show "$SERVER_WG_NIC" allowed-ips | cut -f 2 | awk -F'[./]' '{print $1"."$2"."$3"."1+$4"/"$5}' | sort -t '.' -k 1,1 -k 2,2 -k 3,3 -k 4,4 -n | tail -n1)"

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

# Create client file with interface
echo "[Interface]
PrivateKey = $CLIENT_PRIV_KEY
Address = $PEER_ADDRESS
DNS = $CLIENT_DNS_1,$CLIENT_DNS_2" > "/etc/wireguard/$CLIENT-client.conf"

# Add the server as a peer to the client
echo "[Peer]
PublicKey = $SERVER_PUB_KEY
Endpoint = $ENDPOINT
AllowedIPs = 0.0.0.0/0" >> "/etc/wireguard/$CLIENT-client.conf"

# Add pre shared symmetric key to respective files
echo "PresharedKey = $CLIENT_SYMM_PRE_KEY" >> "/etc/wireguard/$SERVER_WG_NIC.conf"
echo "PresharedKey = $CLIENT_SYMM_PRE_KEY" >> "/etc/wireguard/$CLIENT-client.conf"

# Add peer
wg set SERVER_WG_NIC peer CLIENT_PUB_KEY preshared-key <(echo "$CLIENT_SYMM_PRE_KEY") allowed-ips PEER_ADDRESS

# Logging
echo "Added peer $PEER_ADDRESS with public key $CLIENT_PUB_KEY"