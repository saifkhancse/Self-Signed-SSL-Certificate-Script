#!/bin/bash
echo "📡 Starting Snort to monitor potential DoS attacks..."

INTERFACE=$(ip -o link show | awk -F': ' '!/lo/ {print $2; exit}')
SNORT_CONF="/etc/snort/snort.conf"
RULE_FILE="/etc/snort/rules/local.rules"
UPDATED_RULE='alert tcp any any -> $HOME_NET 443 (msg:"DoS flood on HTTPS port"; flags:S; threshold:type threshold, track by_dst, count 100, seconds 5; sid:1000002; rev:1;)'

echo "📝 Checking if updated DoS detection rule exists in $RULE_FILE..."

if ! grep -qF "$UPDATED_RULE" "$RULE_FILE"; then
  echo "➕ Adding improved DoS detection rule (track by_dst, count 100, 5s)..."
  echo "$UPDATED_RULE" >> "$RULE_FILE"
else
  echo "✅ DoS detection rule already present."
fi

echo "🧪 Testing Snort configuration..."
sudo snort -T -i "$INTERFACE" -c "$SNORT_CONF"

echo "🚀 Starting Snort with live alerts..."
sudo pkill -f snort || true
sudo snort -A console -q -c "$SNORT_CONF" -i "$INTERFACE"
