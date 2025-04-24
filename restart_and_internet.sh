#!/bin/bash

# Verifica se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute como root."
  exit 1
fi

# Reinicia o serviço hostapd
echo "Reiniciando o serviço hostapd..."
sudo systemctl restart hostapd.service

# Verifica se o comando anterior teve sucesso
if [ $? -ne 0 ]; then
  echo "Erro ao reiniciar o hostapd. Abortando."
  exit 1
fi

# Aguarda o usuário apertar uma tecla antes de continuar
read -n 1 -s -r -p "hostapd reiniciado. Pressione qualquer tecla para continuar..."
echo ""

# Cria o arquivo de configuração para habilitar o encaminhamento de pacotes
IPFORWARD_CONF="/etc/sysctl.d/30-ipforward.conf"
cat <<EOF | sudo tee "$IPFORWARD_CONF" > /dev/null
net.ipv4.ip_forward=1
net.ipv6.conf.default.forwarding=1
net.ipv6.conf.all.forwarding=1
EOF

echo "Arquivo de configuração criado em $IPFORWARD_CONF"

# Configura NAT com iptables
echo "Configurando iptables para NAT..."
sudo iptables -t nat -A POSTROUTING -o ethernet0 -j MASQUERADE
sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i uap0 -o ethernet0 -j ACCEPT

# Salva as regras iptables
echo "Salvando regras do iptables..."
sudo mkdir -p /etc/iptables/
sudo iptables-save | sudo tee /etc/iptables/iptables.rules > /dev/null

# Cria o serviço systemd para restaurar as regras no boot
IPTABLES_SERVICE="/etc/systemd/iptables.service"
echo "Criando serviço systemd em $IPTABLES_SERVICE..."
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

# Ativa o serviço systemd
echo "Recarregando serviços systemd e ativando iptables.service..."
sudo systemctl --system daemon-reload
sudo systemctl enable iptables

echo "Configuração concluída com sucesso!"
