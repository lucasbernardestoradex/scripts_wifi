#!/bin/bash

# Check if the script is being run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

# Restart the hostapd service
echo "Restarting the hostapd service..."
sudo systemctl restart hostapd.service

# Check if the previous command was successful
if [ $? -ne 0 ]; then
  echo "Error restarting hostapd. Aborting."
  exit 1
fi

# Wait for the user to press a key before continuing
read -n 1 -s -r -p "hostapd restarted. Press any key to continue..."
echo ""

# Create the configuration file to enable packet forwarding
IPFORWARD_CONF="/etc/sysctl.d/30-ipforward.conf"
cat <<EOF | sudo tee "$IPFORWARD_CONF" > /dev/null
net.ipv4.ip_forward=1
net.ipv6.conf.default.forwarding=1
net.ipv6.conf.all.forwarding=1
EOF

echo "Configuration file created at $IPFORWARD_CONF"

# Configure NAT with iptables
echo "Configuring iptables for NAT..."
sudo iptables -t nat -A POSTROUTING -o ethernet0 -j MASQUERADE
sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i uap0 -o ethernet0 -j ACCEPT

# Save iptables rules
echo "Saving iptables rules..."
sudo mkdir -p /etc/iptables/
sudo iptables-save | sudo tee /etc/iptables/iptables.rules > /dev/null

# Create the systemd service to restore rules on boot
IPTABLES_SERVICE="/etc/systemd/iptables.service"
echo "Creating systemd service at $IPTABLES_SERVICE..."
cat <<EOF | sudo tee "$IPTABLES_SERVICE" > /dev/null
[Unit]
Description=IPv4 Packet Filtering Framework
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/iptables-restore /etc/iptables/iptables.rules
ExecReload=/usr/sbin/iptables-restore /etc/iptables/iptables.rules
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable the systemd service
echo "Reloading systemd services and enabling iptables.service..."
sudo systemctl --system daemon-reload
sudo systemctl enable iptables

echo "Configuration completed successfully!"
