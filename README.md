# 📜 About
Simple Docker container with WireGuard VPN and the ability to add new users. *Zero* dependencies to work with WireGuard in the system. Everything you need inside the container.

# 🏗 Setup
1. Clone this repo: `git clone https://github.com/jeudesprits/wireguard-docker`
2. Go to folder: `cd wireguard-docker`
3. Build docker container: `docker build --tag=jeudesprits/wireguard-docker .`
4. Run docker container. Be sure that you specify the correct port for VPN. 
```
docker run -it --rm --cap-add net_admin --cap-add sys_module \
           -v $HOME/.wireguard:/etc/wireguard -v /lib/modules:/lib/modules \
           -p 1194:1194/udp \
            jeudesprits/wireguard-docker:latest
```
5. Answer the questions. Example:
```
IPv4 or IPv6 public address: ec2-13-48-3-139.eu-north-1.compute.amazonaws.com
Server's WireGuard port 1194
Tell me a name for the client.
Use one word only, no special characters.
Client name: jeudesprits-iOS
First DNS resolver to use for the client: 8.8.8.8
Second DNS resolver to use for the client: 8.8.4.4
```
6. If everything went well, you will see a similar:
```
Starting Wireguard
[#] ip link add wg0 type wireguard
[#] wg setconf wg0 /dev/fd/63
[#] ip -4 address add 10.66.66.1/24 dev wg0
[#] ip link set mtu 1420 up dev wg0
[#] iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```
7. Press `Control+P Control+Q`.
8. PROFIT!

# 🆘 Tips
1. All created VPN configs in `$HOME/.wireguard` folder.
2. To add a user type `docker exec -it YOUR-CONTAINER-ID bash /scripts/add-user.sh` Remember answer the questions. 