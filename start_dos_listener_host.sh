#!/bin/bash
echo "📡 Starting Snort to monitor potential DoS attacks..."

INTERFACE=$(ip -o link show | awk -F': ' '!/lo/ {print $2; exit}')
SNORT_CONF="/etc/snort/snort.conf"
RULE_FILE="/etc/snort/rules/local.rules"
BLOCKED_LOG="$HOME/Downloads/blocked_ips.txt"
TEMP_ALERTS="/tmp/snort_alerts.log"
UPDATED_RULE='alert tcp any any -> $HOME_NET 443 (msg:"DoS flood on HTTPS port"; flags:S; threshold:type threshold, track by_dst, count 100, seconds 5; sid:1000002; rev:1;)'

# Add detection rule if missing
echo "📝 Checking if updated DoS detection rule exists in $RULE_FILE..."
if ! grep -qF "$UPDATED_RULE" "$RULE_FILE"; then
  echo "➕ Adding improved DoS detection rule..."
  echo "$UPDATED_RULE" >> "$RULE_FILE"
else
  echo "✅ Detection rule already present."
fi

# Ensure log file exists
touch "$BLOCKED_LOG"

# Kill any running Snort instance
sudo pkill -f snort || true

echo "🧪 Testing Snort configuration..."
sudo snort -T -i "$INTERFACE" -c "$SNORT_CONF" || { echo "❌ Snort test failed!"; exit 1; }

# Launch snort and capture alerts
echo "🚀 Starting Snort with live alerts..."
sudo snort -A console -q -c "$SNORT_CONF" -i "$INTERFACE" > "$TEMP_ALERTS" &

# Monitor alerts and auto-block IPs
echo "🛡️ Monitoring for attacks and blocking malicious IPs..."
tail -n0 -F "$TEMP_ALERTS" | while read -r line; do
  if echo "$line" | grep -q "DoS flood on HTTPS port"; then
    ATTACKER_IP=$(echo "$line" | grep -oP '(?<=\[**\] )\d{1,3}(\.\d{1,3}){3}' | head -n1)
    if [ -n "$ATTACKER_IP" ] && ! grep -q "$ATTACKER_IP" "$BLOCKED_LOG"; then
      echo "🚫 Blocking IP: $ATTACKER_IP"
      sudo iptables -A INPUT -s "$ATTACKER_IP" -j DROP
      echo "$ATTACKER_IP" >> "$BLOCKED_LOG"
    fi
  fi
done
