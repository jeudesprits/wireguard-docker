#!/bin/bash

cd "/etc/wireguard" || exit

LAST_CONFIG="$(ls -t | grep 'client' | head -n 1)"
SERVER_PUB_IP="$(grep -Po '(?<=Endpoint = )(.+)' "$LAST_CONFIG")"
FULL_IP="$(grep -Po '(?<=Address = )(.+)' "$LAST_CONFIG")" 
IP="${FULL_IP:: -3}"

function nextip () {
    IP_HEX=$(printf '%.2X%.2X%.2X%.2X\n' `echo "$IP" | sed -e 's/\./ /g'`)
    NEXT_IP_HEX=$(printf %.8X `echo $(( 0x"$IP_HEX" + 1 ))`)
    NEXT_IP=$(printf '%d.%d.%d.%d\n' `echo "$NEXT_IP_HEX" | sed -r 's/(..)/0x\1 /g'`)
}

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

nextip "$@"

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

# Add the client as a peer to the server
echo "
[Peer]
# $CLIENT
PublicKey = $CLIENT_PUB_KEY
AllowedIPs = $NEXT_IP/32" >> "/etc/wireguard/$SERVER_WG_NIC.conf"

# Create client file with interface
echo "[Interface]
PrivateKey = $CLIENT_PRIV_KEY
Address = $NEXT_IP/24
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
 
# Save to conf
wg-quick save wg0

# Logging
echo "Added peer $CLIENT with public key $CLIENT_PUB_KEY"