#!/bin/bash

# Verifica se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute como root."
  exit 1
fi

# Cria o arquivo de configuração do hostapd
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

echo "Arquivo hostapd.conf criado em $HOSTAPD_CONF"

# Cria o arquivo de configuração de rede para DHCP via systemd-networkd
NETWORK_CONF="/etc/systemd/network/80-wifi-ap.network"
mkdir -p "$(dirname "$NETWORK_CONF")"  # Garante que o diretório exista

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

echo "Arquivo de configuração de rede criado em $NETWORK_CONF"

# Reinicializa a máquina para aplicar as configurações
echo "Reiniciando o sistema para aplicar as configurações..."
reboot now
