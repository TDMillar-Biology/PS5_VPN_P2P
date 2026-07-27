#!/bin/bash

# ==============================================================================
# CONFIGURATION VARIABLES
# ==============================================================================
PS5_IP="10.42.0.X"         # Your console's local IP address (Check console settings)
PROTON_PORT="3074"         # The active forwarded port given by Proton VPN
GAME_PORT="3074"           # The default game port (BO2 uses 3074)
VPN_INTERFACE="tun0"       # Active VPN interface (commonly tun0 or wg0)

# ==============================================================================
# SAFEGUARDS & VALIDATION
# ==============================================================================
# 1. Ensure the script is run as root so sudo doesn't prompt multiple times
if [ "$EUID" -ne 0 ]; then 
  echo "❌ Error: Please run this script as root (use sudo ./bo2_tunnel.sh)"
  exit 1
fi

# 2. Prevent the script from running if the IP placeholder wasn't updated
if [[ "$PS5_IP" == *"X"* ]]; then
  echo "❌ Error: You forgot to update the PS5_IP variable! Please edit the script."
  exit 1
fi

# ==============================================================================
# INITIALIZATION
# ==============================================================================
echo "=========================================="
echo "🚀 Initializing Black Ops II Network Tunnel"
echo "=========================================="
echo "📍 PS5 IP Target:     $PS5_IP"
echo "🔌 Proton VPN Port:   $PROTON_PORT"
echo "🎮 Game Target Port:  $GAME_PORT"
echo "🌐 VPN Interface:     $VPN_INTERFACE"
echo "------------------------------------------"

# Ensure Linux Kernel Packet Forwarding is enabled globally
echo "🔄 Enabling system packet forwarding..."
sysctl -w net.ipv4.ip_forward=1 > /dev/null

# ==============================================================================
# FIREWALL ROUTING RULES (IPTABLES)
# ==============================================================================
# Note: We are NOT flushing the NAT table here, so we don't break Ubuntu's 
# existing "Share to other computers" connection.

# 1. Forward incoming traffic from the VPN Port to the Game's default port
echo "Routing inbound UDP/TCP traffic..."
iptables -t nat -A PREROUTING -i $VPN_INTERFACE -p udp --dport $PROTON_PORT -j DNAT --to-destination $PS5_IP:$GAME_PORT
iptables -t nat -A PREROUTING -i $VPN_INTERFACE -p tcp --dport $PROTON_PORT -j DNAT --to-destination $PS5_IP:$GAME_PORT

# 2. Explicitly allow the game traffic through the Linux forwarding chain
echo "Updating firewall forwarding permissions..."
iptables -A FORWARD -p udp -d $PS5_IP --dport $GAME_PORT -j ACCEPT
iptables -A FORWARD -p tcp -d $PS5_IP --dport $GAME_PORT -j ACCEPT

# 3. Outbound VPN Port Mapping (Symmetric NAT Bypass)
# This forces the PS5's outbound game traffic to match the exact port Proton gave you.
echo "Locking outbound ports to Proton Port..."
iptables -t nat -A POSTROUTING -o $VPN_INTERFACE -p udp --sport $GAME_PORT -j SNAT --to-source :$PROTON_PORT
iptables -t nat -A POSTROUTING -o $VPN_INTERFACE -p tcp --sport $GAME_PORT -j SNAT --to-source :$PROTON_PORT

echo "------------------------------------------"
echo "Tunnel configuration updated successfully!"
echo "Run 'Test Internet Connection' on your console, then open your game."
echo "=========================================="