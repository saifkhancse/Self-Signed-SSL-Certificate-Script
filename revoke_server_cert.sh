#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# === Configuration ===
WORKDIR="${HOME}/tls_project"
SUB_CA_DIR="$WORKDIR/ca/sub-ca"
SUB_CA_CONF="$WORKDIR/ca/sub-ca.conf"  # ✅ Corrected path
SERVER_CERT="$WORKDIR/ca/server/certs/server.crt"
CRL_FILE="crl.pem"
WEB_CRL_DIR="/opt/lampp/htdocs/crl"

echo "🔒 Revoking Server Certificate..."

# === Check paths ===
if [[ ! -d "$SUB_CA_DIR" ]]; then
    echo "❌ Sub CA directory not found: $SUB_CA_DIR"
    exit 1
fi

if [[ ! -f "$SUB_CA_CONF" ]]; then
    echo "❌ Config file not found: $SUB_CA_CONF"
    exit 1
fi

if [[ ! -f "$SERVER_CERT" ]]; then
    echo "❌ Server certificate not found: $SERVER_CERT"
    exit 1
fi

cd "$SUB_CA_DIR"

# === Check if certificate was issued by this CA ===
SERIAL=$(openssl x509 -serial -noout -in "$SERVER_CERT" | cut -d= -f2)
if ! grep -q "$SERIAL" index.txt; then
    echo "❌ Serial $SERIAL not found in index.txt. Certificate not issued by this CA."
    exit 1
fi

echo "⚠️ Revoking certificate (passphrase: 1111)..."
openssl ca -config "$SUB_CA_CONF" -revoke "$SERVER_CERT" -passin pass:1111

echo "🔁 Generating CRL..."
openssl ca -config "$SUB_CA_CONF" -gencrl -out "$CRL_FILE" -passin pass:1111

echo "📂 Copying CRL to web server directory..."
sudo mkdir -p "$WEB_CRL_DIR"
sudo cp "$CRL_FILE" "$WEB_CRL_DIR/sub-crl.pem"
sudo chmod 644 "$WEB_CRL_DIR/sub-crl.pem"

echo "✅ Server certificate revoked and CRL published at: $WEB_CRL_DIR/sub-crl.pem"
