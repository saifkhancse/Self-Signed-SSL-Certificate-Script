#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

WORKDIR="${HOME}/tls_project"
SUB_CA_DIR="$WORKDIR/ca/sub-ca"
SERVER_CERT="$WORKDIR/ca/server/certs/server.crt"

echo "🔒 Revoking Server Certificate..."

cd "$SUB_CA_DIR" || { echo "Sub CA directory not found!"; exit 1; }

echo "⚠️ Revoke command (requires passphrase: 1111)"
openssl ca -config sub-ca.conf -revoke "$SERVER_CERT" -passin pass:1111

echo "🔁 Regenerating CRL..."
openssl ca -config sub-ca.conf -gencrl -out crl.pem -passin pass:1111

echo "📂 Copying updated CRL to web directory..."
sudo mkdir -p /opt/lampp/htdocs/crl
sudo cp crl.pem /opt/lampp/htdocs/crl/sub-crl.pem

echo "✅ Server certificate revoked and CRL updated."
