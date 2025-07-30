#!/bin/bash
echo "📡 Starting Snort to monitor potential DoS attacks..."

INTERFACE=$(ip -o link show | awk -F': ' '!/lo/ {print $2; exit}')
SNORT_CONF="/etc/snort/snort.conf"

echo "📝 Make sure your /etc/snort/rules/local.rules has a DoS detection rule like:"
echo 'alert tcp any any -> $HOME_NET 443 (msg:"Possible DoS Attack on HTTPS"; flags:S; threshold:type threshold, track by_src, count 70, seconds 10; sid:1000001; rev:1;)'
read -rp "Press Enter to continue..."

echo "🚀 Running Snort with live alerts..."
sudo snort -A console -q -c "$SNORT_CONF" -i "$INTERFACE"
