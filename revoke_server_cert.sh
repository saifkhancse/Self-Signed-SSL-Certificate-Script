#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# === Configuration ===
WORKDIR="${HOME}/tls_project"
SUB_CA_DIR="$WORKDIR/ca/sub-ca"
SUB_CA_CONF="$WORKDIR/ca/sub-ca.conf"
SERVER_CERT="$WORKDIR/ca/server/certs/server.crt"
CRL_FILE="crl.pem"
WEB_CRL_DIR="/opt/lampp/htdocs/crl"
CRL_NUMBER_FILE="$SUB_CA_DIR/crlnumber"

echo "🔒 Starting Server Certificate Revocation..."

# === Validation Checks ===
[[ -d "$SUB_CA_DIR" ]] || { echo "❌ Sub CA directory not found: $SUB_CA_DIR"; exit 1; }
[[ -f "$SUB_CA_CONF" ]] || { echo "❌ Config file not found: $SUB_CA_CONF"; exit 1; }
[[ -f "$SERVER_CERT" ]] || { echo "❌ Server certificate not found: $SERVER_CERT"; exit 1; }

cd "$SUB_CA_DIR"

# === Create crlnumber file if missing ===
if [[ ! -f "$CRL_NUMBER_FILE" ]]; then
    echo "⚙️ Creating missing crlnumber file..."
    echo 1000 > "$CRL_NUMBER_FILE"
fi

# === Check if certificate exists in sub-CA database ===
SERIAL=$(openssl x509 -serial -noout -in "$SERVER_CERT" | cut -d= -f2)
if ! grep -q "$SERIAL" index.txt; then
    echo "❌ Serial $SERIAL not found in index.txt. Certificate may not have been issued by this CA."
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
