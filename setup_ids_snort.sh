#!/bin/bash
# setup_ids_snort.sh - Automated IDS setup on host/server

set -euo pipefail
IFS=$'\n\t'

if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run this script as root."
  exit 1
fi

INTERFACE=$(ip -o link show | awk -F': ' '!/lo/ {print $2; exit}')
IPADDR=$(hostname -I | awk '{print $1}')

echo "🛡️ Setting up Snort IDS on interface: $INTERFACE, IP: $IPADDR"

apt-get update -y
apt-get install -y snort

SNORT_CONF="/etc/snort/snort.conf"
echo "🔧 Updating HOME_NET in Snort config..."
sed -i "s/^ipvar HOME_NET .*/ipvar HOME_NET ${IPADDR}\/24/" "$SNORT_CONF"

LOCAL_RULES="/etc/snort/rules/local.rules"
DOS_RULE='alert tcp any any -> $HOME_NET 443 (msg:"Possible DoS Attack on HTTPS"; flags:S; threshold:type threshold, track by_src, count 70, seconds 10; sid:1000001; rev:1;)'
if ! grep -q "$DOS_RULE" "$LOCAL_RULES"; then
  echo "➕ Adding custom DoS detection rule..."
  echo "$DOS_RULE" >> "$LOCAL_RULES"
else
  echo "✅ DoS rule already present."
fi

echo "✅ Testing Snort configuration..."
snort -T -i "$INTERFACE" -c "$SNORT_CONF"

pkill -f snort || true

echo "🚀 Starting Snort in background (logged to /var/log/snort.log)..."
nohup snort -A console -q -c "$SNORT_CONF" -i "$INTERFACE" > /var/log/snort.log 2>&1 &

echo "✅ Snort is now running and monitoring interface $INTERFACE."