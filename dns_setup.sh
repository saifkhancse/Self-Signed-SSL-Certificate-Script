#!/bin/bash

set -e

usage() {
  echo "Usage: $0 {server|client}"
  echo "  server  - Setup BIND DNS server"
  echo "  client  - Configure client to use BIND DNS server"
  exit 1
}

if [ $# -ne 1 ]; then
  usage
fi

MODE=$1

# Common defaults
DEFAULT_DOMAIN="verysecureserver.com"
DEFAULT_HOSTNAME=$(hostname)
DEFAULT_IP_CIDR=$(ip -o -f inet addr show | awk '/scope global/ {print $4; exit}')
DEFAULT_IP=${DEFAULT_IP_CIDR%/*}
DEFAULT_NETMASK=${DEFAULT_IP_CIDR#*/}
DEFAULT_GATEWAY=$(ip route | awk '/default/ {print $3; exit}')

if [ "$MODE" == "server" ]; then
  echo "=========================="
  echo " BIND DNS Server Setup"
  echo "=========================="

  read -rp "Enter domain name [${DEFAULT_DOMAIN}]: " DOMAIN
  DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}

  HOSTNAME=$DEFAULT_HOSTNAME
  IP=$DEFAULT_IP
  NETMASK=$DEFAULT_NETMASK
  GATEWAY=$DEFAULT_GATEWAY
  FQDN="${HOSTNAME}.${DOMAIN}"

  echo "🔧 Domain: $DOMAIN"
  echo "🖥 Hostname: $HOSTNAME"
  echo "🌐 FQDN: $FQDN"
  echo "🌍 IP: $IP/$NETMASK"
  echo "🚪 Gateway: $GATEWAY"

  HOSTS_FILE="/etc/hosts"
  BIND_DIR="/etc/bind"
  FORWARD_ZONE_FILE="$BIND_DIR/db.$DOMAIN"
  REVERSE_ZONE_FILE="$BIND_DIR/db.${IP//./_}"
  REVERSE_ZONE=$(echo $IP | awk -F. '{print $3"."$2"."$1}')
  PTR_LAST_OCTET=$(echo $IP | awk -F. '{print $4}')

  echo "🛠 Updating /etc/hosts..."
  sudo sed -i "/$FQDN/d" $HOSTS_FILE
  echo "$IP $FQDN $HOSTNAME www.$DOMAIN" | sudo tee -a $HOSTS_FILE

  echo "🛠 Configuring named.conf.options..."
  sudo tee $BIND_DIR/named.conf.options > /dev/null <<EOF
options {
    directory "/var/cache/bind";
    recursion no;
    allow-query { any; };
    listen-on { any; };
    listen-on-v6 { any; };
    dnssec-validation auto;
    auth-nxdomain no;
};
EOF

  echo "🛠 Configuring named.conf.local..."
  sudo tee $BIND_DIR/named.conf.local > /dev/null <<EOF
zone "$DOMAIN" {
    type master;
    file "$FORWARD_ZONE_FILE";
    allow-update { none; };
};

zone "${REVERSE_ZONE}.in-addr.arpa" {
    type master;
    file "$REVERSE_ZONE_FILE";
    allow-update { none; };
};
EOF

  echo "🛠 Creating forward zone file..."
  SERIAL=$(date +%Y%m%d01)
  sudo tee $FORWARD_ZONE_FILE > /dev/null <<EOF
\$TTL 604800
@       IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. (
                        $SERIAL ; Serial
                        604800 ; Refresh
                        86400 ; Retry
                        2419200 ; Expire
                        604800 ) ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMAIN.
ns1     IN      A       $IP
$HOSTNAME IN    A       $IP
www     IN      A       $IP
EOF

  echo "🛠 Creating reverse zone file..."
  sudo tee $REVERSE_ZONE_FILE > /dev/null <<EOF
\$TTL 604800
@       IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. (
                        $SERIAL ; Serial
                        604800 ; Refresh
                        86400 ; Retry
                        2419200 ; Expire
                        604800 ) ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMAIN.
$PTR_LAST_OCTET IN      PTR     $FQDN.
EOF

  echo "🚀 Restarting BIND9..."
  sudo systemctl restart bind9
  sleep 2
  sudo systemctl status bind9 --no-pager | head -n 10

  echo "🛠 Configuring /etc/resolv.conf with actual IP..."
  sudo rm -f /etc/resolv.conf
  echo -e "nameserver $IP\nsearch $DOMAIN" | sudo tee /etc/resolv.conf

  echo "🔄 Flushing DNS cache..."
  sudo systemd-resolve --flush-caches || true
  sudo systemctl restart systemd-resolved || true

  echo "🔍 Testing authoritative DNS resolution..."
  dig @$IP www.$DOMAIN +short
  dig @$IP www.$DOMAIN

  echo "✅ Server DNS setup complete."

elif [ "$MODE" == "client" ]; then
  echo "==========================="
  echo " DNS Client Configuration"
  echo "==========================="

  read -rp "Enter DNS Server IP [${DEFAULT_IP}]: " DNS_IP
  DNS_IP=${DNS_IP:-$DEFAULT_IP}

  read -rp "Enter search domain [${DEFAULT_DOMAIN}]: " DOMAIN
  DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}

  echo "🛠 Disabling systemd-resolved..."
  sudo systemctl stop systemd-resolved
  sudo systemctl disable systemd-resolved

  [ -L /etc/resolv.conf ] && sudo rm /etc/resolv.conf

  echo -e "nameserver $DNS_IP\nsearch $DOMAIN" | sudo tee /etc/resolv.conf

  echo "🔄 Flushing DNS cache..."
  sudo systemd-resolve --flush-caches || true

  echo "🔍 Testing client DNS resolution..."
  dig www.$DOMAIN +short
  ping -c3 www.$DOMAIN

  echo "✅ Client DNS setup complete."

else
  usage
fi
