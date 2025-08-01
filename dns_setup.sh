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
DEFAULT_HOSTNAME="ubuntu1804"
DEFAULT_IP="192.168.0.31"
DEFAULT_NETMASK="24"
DEFAULT_GATEWAY="192.168.0.1"

if [ "$MODE" == "server" ]; then
  echo "=========================="
  echo " BIND DNS Setup Script"
  echo "=========================="

  # Prompt user for inputs with defaults
  read -rp "Enter domain name [${DEFAULT_DOMAIN}]: " DOMAIN
  DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}

  read -rp "Enter hostname [${DEFAULT_HOSTNAME}]: " HOSTNAME
  HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}

  read -rp "Enter IPv4 address with CIDR (e.g. 192.168.0.31/24) [${DEFAULT_IP}/${DEFAULT_NETMASK}]: " IP_CIDR
  IP_CIDR=${IP_CIDR:-${DEFAULT_IP}/${DEFAULT_NETMASK}}

  read -rp "Enter default gateway IP [${DEFAULT_GATEWAY}]: " GATEWAY
  GATEWAY=${GATEWAY:-$DEFAULT_GATEWAY}

  # Extract IP and mask separately
  IP="${IP_CIDR%/*}"
  NETMASK="${IP_CIDR#*/}"

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

  # --- Step 1: Update /etc/hosts ---

  echo "🛠 Updating $HOSTS_FILE..."

  sudo cp $HOSTS_FILE "${HOSTS_FILE}.bak_$(date +%F_%T)"

  # Remove any existing entries for hostname and www domain that use 127.0.0.*
  sudo sed -i "/127\.0\.0\.[0-9]*.*\b$FQDN\b/d" $HOSTS_FILE
  sudo sed -i "/127\.0\.0\.[0-9]*.*\bwww\.$DOMAIN\b/d" $HOSTS_FILE

  # Remove any entries with hostname or www.domain to avoid duplicates
  sudo sed -i "/\b$FQDN\b/d" $HOSTS_FILE
  sudo sed -i "/\bwww\.$DOMAIN\b/d" $HOSTS_FILE

  # Add correct mapping
  echo -e "$IP\t$FQDN $HOSTNAME www.$DOMAIN" | sudo tee -a $HOSTS_FILE

  echo "$HOSTS_FILE updated:"
  tail -n 5 $HOSTS_FILE
  echo

  # --- Step 2: Configure BIND named.conf.options ---

  NAMED_OPTIONS="$BIND_DIR/named.conf.options"

  echo "🛠 Configuring $NAMED_OPTIONS..."

  sudo cp $NAMED_OPTIONS "${NAMED_OPTIONS}.bak_$(date +%F_%T)"

  sudo tee $NAMED_OPTIONS > /dev/null <<EOF
options {
    directory "/var/cache/bind";

    recursion yes;
    allow-query { any; };
    listen-on { any; };

    forwarders {
        8.8.8.8;
        8.8.4.4;
    };

    dnssec-validation auto;

    auth-nxdomain no;    # conform to RFC1035
    listen-on-v6 { any; };
};
EOF

  echo "$NAMED_OPTIONS configured."
  echo

  # --- Step 3: Configure named.conf.local for zones ---

  NAMED_LOCAL="$BIND_DIR/named.conf.local"

  echo "🛠 Configuring $NAMED_LOCAL..."

  sudo cp $NAMED_LOCAL "${NAMED_LOCAL}.bak_$(date +%F_%T)"

  # Reverse zone in-addr.arpa format (e.g. 0.168.192.in-addr.arpa)
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

  echo "$NAMED_LOCAL configured."
  echo

  # --- Step 4: Create forward zone file ---

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

  echo "Forward zone file created and verified."
  echo

  # --- Step 5: Create reverse zone file ---

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

  echo "Reverse zone file created and verified."
  echo

  # --- Step 6: Restart BIND9 service ---

  echo "🚀 Restarting bind9 service..."

  sudo systemctl restart bind9

  sleep 2

  sudo systemctl status bind9 --no-pager | head -n 12

  echo

  # --- Step 7: Configure /etc/resolv.conf ---

  echo "🛠 Configuring /etc/resolv.conf to use localhost DNS (BIND)..."

  sudo cp /etc/resolv.conf "/etc/resolv.conf.bak_$(date +%F_%T)"

  sudo tee /etc/resolv.conf > /dev/null <<EOF
nameserver 127.0.0.1
search $DOMAIN
EOF

  echo "/etc/resolv.conf updated:"
  cat /etc/resolv.conf
  echo

  # --- Step 8: Flush systemd-resolved cache (if running) ---

  if systemctl is-active --quiet systemd-resolved; then
      echo "Flushing systemd-resolved DNS cache..."
      sudo systemd-resolve --flush-caches
      sudo systemctl restart systemd-resolved
      echo "systemd-resolved restarted."
  fi
  echo

  # --- Step 9: Test DNS resolution and ping ---

  echo "Running DNS lookups and ping tests..."

  echo -e "\nnslookup $HOSTNAME:"
  nslookup $HOSTNAME

  echo -e "\nnslookup www.$DOMAIN:"
  nslookup www.$DOMAIN

  echo -e "\nping -c3 www.$DOMAIN:"
  ping -c3 www.$DOMAIN

  echo
  echo "Server setup completed successfully."

elif [ "$MODE" == "client" ]; then

  # Client mode: Disable systemd-resolved and point resolv.conf to BIND server

  echo "==============================="
  echo " Client DNS Configuration Script"
  echo "==============================="

  read -rp "Enter BIND DNS server IP [${DEFAULT_IP}]: " BIND_DNS_IP
  BIND_DNS_IP=${BIND_DNS_IP:-$DEFAULT_IP}

  read -rp "Enter search domain [${DEFAULT_DOMAIN}]: " DOMAIN
  DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}

  echo "Disabling systemd-resolved to avoid 127.0.0.53 stub resolver..."

  sudo systemctl disable systemd-resolved.service
  sudo systemctl stop systemd-resolved.service

  # Remove symlink /etc/resolv.conf if exists
  if [ -L /etc/resolv.conf ]; then
      echo "Removing /etc/resolv.conf symlink..."
      sudo rm /etc/resolv.conf
  fi

  echo "Creating /etc/resolv.conf with nameserver $BIND_DNS_IP and search domain $DOMAIN..."

  sudo tee /etc/resolv.conf > /dev/null <<EOF
nameserver $BIND_DNS_IP
search $DOMAIN
EOF

  echo "/etc/resolv.conf content:"
  cat /etc/resolv.conf
  echo

  echo "Testing DNS resolution..."

  echo -e "\nnslookup www.$DOMAIN"
  nslookup www.$DOMAIN

  echo -e "\nping -c3 www.$DOMAIN"
  ping -c3 www.$DOMAIN

  echo
  echo "Client DNS configuration completed successfully."

else
  usage
fi
