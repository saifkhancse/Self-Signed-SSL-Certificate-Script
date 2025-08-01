#!/bin/bash
echo "📡 Starting Snort to monitor potential DoS attacks..."

INTERFACE=$(ip -o link show | awk -F': ' '!/lo/ {print $2; exit}')
SNORT_CONF="/etc/snort/snort.conf"
RULE_FILE="/etc/snort/rules/local.rules"
USER_HOME="/home/$(logname)"
BLOCKED_LOG="$USER_HOME/Downloads/blocked_ips.txt"
TEMP_ALERTS="/tmp/snort_alerts.log"
UPDATED_RULE='alert tcp any any -> $HOME_NET 443 (msg:"DoS flood on HTTPS port"; flags:S; threshold:type threshold, track by_dst, count 100, seconds 5; sid:1000002; rev:1;)'

# Add detection rule if missing
echo "📝 Checking if updated DoS detection rule exists in $RULE_FILE..."
if ! grep -qF "$UPDATED_RULE" "$RULE_FILE"; then
  echo "➕ Adding improved DoS detection rule..."
  echo "$UPDATED_RULE" | sudo tee -a "$RULE_FILE" > /dev/null
else
  echo "✅ Detection rule already present."
fi

# Ensure Downloads directory exists and blocked IP log file exists
mkdir -p "$USER_HOME/Downloads"
touch "$BLOCKED_LOG"
> "$TEMP_ALERTS"  # clear temp alerts log

# Kill any running Snort instance
sudo pkill -f snort || true

echo "🧪 Testing Snort configuration..."
sudo snort -T -i "$INTERFACE" -c "$SNORT_CONF" || { echo "❌ Snort test failed!"; exit 1; }

echo "🚀 Starting Snort with live alerts..."
# Capture both stdout and stderr to temp alerts log
sudo snort -A console -q -c "$SNORT_CONF" -i "$INTERFACE" > "$TEMP_ALERTS" 2>&1 &

echo "🛡️ Monitoring for attacks and blocking malicious IPs..."
tail -n0 -F "$TEMP_ALERTS" | while read -r line; do
  if echo "$line" | grep -q "DoS flood on HTTPS port"; then
    ATTACKER_IP=$(echo "$line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)
    if [ -n "$ATTACKER_IP" ] && ! grep -qw "$ATTACKER_IP" "$BLOCKED_LOG"; then
      TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
      REASON="DoS flood on HTTPS port detected"
      echo "🚫 Blocking IP: $ATTACKER_IP"
      sudo iptables -A INPUT -s "$ATTACKER_IP" -j DROP
      echo "$TIMESTAMP - $ATTACKER_IP - $REASON" | tee -a "$BLOCKED_LOG"
    fi
  fi
done
