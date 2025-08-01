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

# Auto-detect IP/CIDR and gateway
DEFAULT_IP_CIDR=$(ip -o -f inet addr show | awk '/scope global/ {print $4; exit}')
DEFAULT_IP=${DEFAULT_IP_CIDR%/*}
DEFAULT_NETMASK=${DEFAULT_IP_CIDR#*/}
DEFAULT_GATEWAY=$(ip route | awk '/default/ {print $3; exit}')

if [ "$MODE" == "server" ]; then
  echo "=========================="
  echo " BIND DNS Setup Script"
  echo "=========================="

  read -rp "Enter domain name [${DEFAULT_DOMAIN}]: " DOMAIN
  DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}

  HOSTNAME=$DEFAULT_HOSTNAME
  IP=$DEFAULT_IP
  NETMASK=$DEFAULT_NETMASK
  GATEWAY=$DEFAULT_GATEWAY
  FQDN="${HOSTNAME}.${DOMAIN}"

  echo
  echo "🔧 Domain: $DOMAIN"
  echo "🖥 Hostname: $HOSTNAME"
  echo "🌐 FQDN: $FQDN"
  echo "🌍 IPv4 Address: $IP/$NETMASK"
  echo "🚪 Default Gateway: $GATEWAY"
  echo

  HOSTS_FILE="/etc/hosts"
  BIND_DIR="/etc/bind"
  FORWARD_ZONE_FILE="$BIND_DIR/db.$DOMAIN"
  REVERSE_ZONE_FILE="$BIND_DIR/db.${IP//./_}"

  echo "🛠 Updating $HOSTS_FILE..."
  sudo cp $HOSTS_FILE "${HOSTS_FILE}.bak_$(date +%F_%T)"
  sudo sed -i "/\b$FQDN\b/d;/\bwww\.$DOMAIN\b/d" $HOSTS_FILE
  echo -e "$IP\t$FQDN $HOSTNAME www.$DOMAIN" | sudo tee -a $HOSTS_FILE
  tail -n 5 $HOSTS_FILE

  NAMED_OPTIONS="$BIND_DIR/named.conf.options"
  echo "🛠 Configuring $NAMED_OPTIONS..."
  sudo cp $NAMED_OPTIONS "${NAMED_OPTIONS}.bak_$(date +%F_%T)"
  sudo tee $NAMED_OPTIONS > /dev/null <<EOF
options {
    directory "/var/cache/bind";
    recursion yes;
    allow-query { any; };
    listen-on { any; };
    forwarders { 8.8.8.8; 8.8.4.4; };
    dnssec-validation auto;
    auth-nxdomain no;
    listen-on-v6 { any; };
};
EOF

  NAMED_LOCAL="$BIND_DIR/named.conf.local"
  echo "🛠 Configuring $NAMED_LOCAL..."
  sudo cp $NAMED_LOCAL "${NAMED_LOCAL}.bak_$(date +%F_%T)"
  REVERSE_ZONE=$(echo $IP | awk -F. '{print $3"."$2"."$1}')
  sudo tee $NAMED_LOCAL > /dev/null <<EOF
zone "$DOMAIN" {
    type master;
    file "$FORWARD_ZONE_FILE";
};

zone "${REVERSE_ZONE}.in-addr.arpa" {
    type master;
    file "$REVERSE_ZONE_FILE";
};
EOF

  echo "🛠 Creating forward zone file $FORWARD_ZONE_FILE..."
  SERIAL=$(date +%Y%m%d01)
  sudo tee $FORWARD_ZONE_FILE > /dev/null <<EOF
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. (
                              $SERIAL ; Serial
                                  604800 ; Refresh
                                   86400 ; Retry
                                 2419200 ; Expire
                                  604800 ; Negative Cache TTL
)
;
@       IN      NS      ns1.$DOMAIN.
ns1     IN      A       $IP
$HOSTNAME    IN      A       $IP
www     IN      A       $IP
EOF

  echo "🛠 Creating reverse zone file $REVERSE_ZONE_FILE..."
  LAST_OCTET=$(echo $IP | awk -F. '{print $4}')
  sudo tee $REVERSE_ZONE_FILE > /dev/null <<EOF
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. (
                              $SERIAL ; Serial
                                  604800 ; Refresh
                                   86400 ; Retry
                                 2419200 ; Expire
                                  604800 ; Negative Cache TTL
)
;
@       IN      NS      ns1.$DOMAIN.
$LAST_OCTET     IN      PTR     $FQDN.
EOF

  echo "🚀 Restarting bind9 service..."
  sudo systemctl restart bind9
  sleep 2
  sudo systemctl status bind9 --no-pager | head -n 12

  echo "🛠 Configuring /etc/resolv.conf..."
  sudo cp /etc/resolv.conf "/etc/resolv.conf.bak_$(date +%F_%T)"
  sudo tee /etc/resolv.conf > /dev/null <<EOF
nameserver $IP
search $DOMAIN
EOF
  cat /etc/resolv.conf

  if systemctl is-active --quiet systemd-resolved; then
      echo "Flushing systemd-resolved DNS cache..."
      sudo systemd-resolve --flush-caches
      sudo systemctl restart systemd-resolved
  fi

  echo "🔍 Testing DNS resolution..."
  nslookup $HOSTNAME
  nslookup www.$DOMAIN
  ping -c3 www.$DOMAIN

  echo "✅ Server setup completed."

elif [ "$MODE" == "client" ]; then
  echo "==============================="
  echo " Client DNS Configuration Script"
  echo "==============================="

  read -rp "Enter BIND DNS server IP [${DEFAULT_IP}]: " BIND_DNS_IP
  BIND_DNS_IP=${BIND_DNS_IP:-$DEFAULT_IP}

  read -rp "Enter search domain [${DEFAULT_DOMAIN}]: " DOMAIN
  DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}

  echo "Disabling systemd-resolved..."
  sudo systemctl disable systemd-resolved.service
  sudo systemctl stop systemd-resolved.service

  if [ -L /etc/resolv.conf ]; then
      sudo rm /etc/resolv.conf
  fi

  echo "Creating /etc/resolv.conf..."
  sudo tee /etc/resolv.conf > /dev/null <<EOF
nameserver $BIND_DNS_IP
search $DOMAIN
EOF
  cat /etc/resolv.conf

  echo "🔍 Testing DNS resolution..."
  nslookup www.$DOMAIN
  ping -c3 www.$DOMAIN

  echo "✅ Client DNS configuration completed."

else
  usage
fi
