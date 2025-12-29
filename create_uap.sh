#!/bin/bash

# Check if the script is being run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

# Create the hostapd configuration file
HOSTAPD_CONF="/etc/hostapd.conf"
cat <<EOF > "$HOSTAPD_CONF"
interface=uap0
ssid=torizon
hw_mode=a
channel=40
ieee80211n=1
country_code=BR
own_ip_addr=192.168.12.1
wpa=2
wpa_passphrase=12345678
EOF

echo "hostapd.conf file created at $HOSTAPD_CONF"

# Create the network configuration file for DHCP via systemd-networkd
NETWORK_CONF="/etc/systemd/network/80-wifi-ap.network"
mkdir -p "$(dirname "$NETWORK_CONF")"  # Ensure the directory exists

cat <<EOF > "$NETWORK_CONF"
[Match]
Name=uap0
Type=wlan
WLANInterfaceType=ap

[Network]
Address=192.168.12.1/24
DHCPServer=yes

[DHCPServer]
PoolOffset=10
PoolSize=30
EOF

echo "Network configuration file created at $NETWORK_CONF"

# Reboot the machine to apply the configurations
echo "Rebooting the system to apply the configurations..."
reboot now
