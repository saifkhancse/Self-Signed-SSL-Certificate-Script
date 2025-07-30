#!/bin/bash
# Run with: sudo bash Self-Signed-SSL-Certificate-Script.sh
# Fully automated and robust TLS CA setup script with no interactive input
# Fixed key/cert mismatch, cleanup, error checking, and passphrase removal for server key
# Adapted to use XAMPP instead of system apache2

set -euo pipefail
IFS=$'\n\t'

LOGFILE="/var/log/tls_ca_setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== Starting TLS CA Setup === $(date)"

# Prompt for input
read -rp "Enter domain name (e.g., www.verysecureserver.com): " DOMAIN
read -rp "Enter organization name (e.g., Acme Corp): " ORG
read -rp "Enter country code (2 letters, e.g., BD): " COUNTRY
read -rp "Enter state/province (e.g., Dhaka): " STATE
read -rp "Enter city/locality (e.g., Dhaka): " CITY
read -rp "Enter email address: " EMAIL

# read -rp "Enter domain name [www.verysecureserver.com]: " DOMAIN
# DOMAIN=${DOMAIN:-www.verysecureserver.com}

# read -rp "Enter organization name [Acme]: " ORG
# ORG=${ORG:-Acme}

# read -rp "Enter country code [BD]: " COUNTRY
# COUNTRY=${COUNTRY:-BD}

# read -rp "Enter state/province [Dhaka]: " STATE
# STATE=${STATE:-Dhaka}

# read -rp "Enter city/locality [Dhaka]: " CITY
# CITY=${CITY:-Dhaka}

# read -rp "Enter email address [admin@verysecureserver.com]: " EMAIL
# EMAIL=${EMAIL:-admin@verysecureserver.com}


WORKDIR="${HOME}/tls_project"
echo "Using working directory: $WORKDIR"

# Clean previous run artifacts to start fresh
echo "Cleaning up old CA files..."
rm -rf "$WORKDIR/ca"
mkdir -p "$WORKDIR/ca"
cd "$WORKDIR"

# Avoid OpenSSL RNG warning
export RANDFILE="$WORKDIR/.rnd"

echo "Updating package lists and installing dependencies..."
echo "Checking for dpkg/apt lock and terminating any blocking processes..."

MAX_RETRIES=5
RETRY_DELAY=3
attempt=1

while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo "Attempt $attempt: Another process is using dpkg or apt. Killing it..."

    # Kill any apt or dpkg processes
    pkill -9 apt || true
    pkill -9 dpkg || true

    # Wait before retrying
    if [ $attempt -ge $MAX_RETRIES ]; then
        echo "ERROR: Could not acquire dpkg lock after $MAX_RETRIES attempts."
        exit 1
    fi

    sleep $RETRY_DELAY
    ((attempt++))
done
echo "Lock released. Proceeding with package update and installation..."
DEBIAN_FRONTEND=noninteractive apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y openssl ufw bind9 dnsutils net-tools php wget libnss3-tools

echo "Checking for XAMPP..."

if [ ! -d /opt/lampp ]; then
    echo "XAMPP not found. Downloading and installing..."

    XAMPP_INSTALLER="/tmp/xampp-installer.run"
    XAMPP_URL="https://www.apachefriends.org/xampp-files/8.2.12/xampp-linux-x64-8.2.12-0-installer.run"

    echo "Downloading XAMPP from: $XAMPP_URL"
    wget -O "$XAMPP_INSTALLER" "$XAMPP_URL"

    chmod +x "$XAMPP_INSTALLER"

    echo "Running XAMPP installer silently..."
    "$XAMPP_INSTALLER" --mode unattended

    if [ -d /opt/lampp ]; then
        echo "XAMPP installed successfully."
    else
        echo "❌ ERROR: XAMPP installation failed."
        exit 1
    fi
else
    echo "✅ XAMPP already installed at /opt/lampp"
fi

if ! pgrep -f lampp >/dev/null; then
    echo "Starting XAMPP..."
    /opt/lampp/lampp start
else
    echo "XAMPP is already running."
fi


echo "Configuring UFW firewall rules..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 53/tcp
ufw allow 53/udp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "Creating directory structure for CA and server..."
mkdir -p ca/root-ca/{private,certs,newcerts,crl,csr}
mkdir -p ca/sub-ca/{private,certs,newcerts,crl,csr}
mkdir -p ca/server/{private,certs,newcerts,crl,csr}

# Initialize index and serial files for Root and Sub CAs
for CA in root-ca sub-ca; do
    touch "ca/$CA/index.txt"

# With a random 16-digit hex serial (safe for dev use)
openssl rand -hex 8 > "ca/$CA/serial"

    echo "unique_subject = no" > "ca/$CA/index.txt.attr"
    chmod 644 "ca/$CA/index.txt" "ca/$CA/index.txt.attr" "ca/$CA/serial"
done

chmod 700 ca/root-ca/private ca/sub-ca/private ca/server/private

cd ca || exit 1

echo "Generating private keys..."
openssl genrsa -aes256 -passout pass:1111 -out root-ca/private/ca.key 4096
openssl genrsa -aes256 -passout pass:1111 -out sub-ca/private/sub-ca.key 4096
openssl genrsa -out server/private/server.key 2048
chmod 600 root-ca/private/ca.key sub-ca/private/sub-ca.key server/private/server.key

echo "Writing OpenSSL config files..."

# Root CA config
cat > root-ca/root-ca.conf <<EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = $WORKDIR/ca/root-ca
certs             = \$dir/certs
crl_dir           = \$dir/crl
database          = \$dir/index.txt
new_certs_dir     = \$dir/newcerts
serial            = \$dir/serial
private_key       = \$dir/private/ca.key
certificate       = \$dir/certs/ca.crt
default_md        = sha256
policy            = policy_strict
email_in_dn       = no
name_opt          = ca_default
cert_opt          = ca_default
copy_extensions   = copy
x509_extensions   = v3_ca
default_days      = 3650
preserve          = no
crlnumber         = \$dir/crlnumber
crl               = \$dir/crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

[ policy_strict ]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 4096
prompt             = no
distinguished_name  = req_distinguished_name
x509_extensions     = v3_ca
string_mask         = utf8only

[ req_distinguished_name ]
C  = $COUNTRY
ST = $STATE
L  = $CITY
O  = $ORG
CN = AcmeRootCA
emailAddress = $EMAIL

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical,CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ crl_ext ]
authorityKeyIdentifier=keyid:always
EOF

# Sub CA config (used when signing server certs)
cat > sub-ca.conf <<EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = $WORKDIR/ca/sub-ca
certs             = \$dir/certs
crl_dir           = \$dir/crl
database          = \$dir/index.txt
new_certs_dir     = \$dir/newcerts
serial            = \$dir/serial
private_key       = \$dir/private/sub-ca.key
certificate       = \$dir/certs/sub-ca.crt
default_md        = sha256
policy            = policy_loose
email_in_dn       = no
name_opt          = ca_default
cert_opt          = ca_default
copy_extensions   = copy
x509_extensions   = usr_cert
default_days      = 375
preserve          = no
crlnumber         = \$dir/crlnumber
crl               = \$dir/crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

[ policy_loose ]
countryName        = optional
stateOrProvinceName= optional
localityName       = optional
organizationName   = optional
organizationalUnitName = optional
commonName         = supplied
emailAddress       = optional

[ req ]
default_bits       = 4096
prompt             = no
distinguished_name = req_distinguished_name
string_mask        = utf8only
x509_extensions    = v3_intermediate_ca

[ req_distinguished_name ]
C  = $COUNTRY
ST = $STATE
L  = $CITY
O  = $ORG
CN = AcmeCA
emailAddress = $EMAIL

[ v3_intermediate_ca ]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints       = critical,CA:true,pathlen:0
keyUsage               = critical,digitalSignature,cRLSign,keyCertSign

[ server_cert ]
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
[ crl_ext ]
authorityKeyIdentifier=keyid:always
EOF

echo "Generating Root CA certificate..."
mkdir -p root-ca/newcerts root-ca/certs root-ca/crl
openssl req -config root-ca/root-ca.conf -key root-ca/private/ca.key -passin pass:1111 \
    -new -x509 -days 7305 -sha256 -extensions v3_ca \
    -out root-ca/certs/ca.crt

echo "Generating Sub CA CSR..."
mkdir -p sub-ca/newcerts sub-ca/csr sub-ca/certs

openssl req -config root-ca/root-ca.conf -key sub-ca/private/sub-ca.key -passin pass:1111 \
    -new -out sub-ca/csr/sub-ca.csr \
    -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/CN=AcmeCA/emailAddress=$EMAIL"
echo "Generating Server CSR..."
mkdir -p server/newcerts server/csr server/certs
openssl req -new -key server/private/server.key \
    -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/CN=$DOMAIN/emailAddress=$EMAIL" \
    -out server/csr/server.csr

echo "Preparing Sub CA serial and index files..."
mkdir -p "$WORKDIR/ca/sub-ca"
# Create index.txt if missing (required by openssl ca)
touch "$WORKDIR/ca/sub-ca/index.txt"
# Generate unique serial (if not exists or overwrite)
openssl rand -hex 8 | tr '[:lower:]' '[:upper:]' > "$WORKDIR/ca/sub-ca/serial"

echo "Signing Sub CA certificate with Root CA..."
openssl ca -config root-ca/root-ca.conf -passin pass:1111 -extensions v3_ca \
    -days 3652 -notext -verbose -in sub-ca/csr/sub-ca.csr -out sub-ca/certs/sub-ca.crt -batch

echo "Preparing Server serial and index files..."
mkdir -p "$WORKDIR/ca/server"
touch "$WORKDIR/ca/server/index.txt"
openssl rand -hex 8 | tr '[:lower:]' '[:upper:]' > "$WORKDIR/ca/server/serial"

echo "Signing Server certificate with Sub CA..."
openssl ca -config sub-ca.conf -passin pass:1111 -extensions server_cert \
    -days 375 -notext -verbose -in server/csr/server.csr -out server/certs/server.crt -batch

# Verify server key and cert match
echo "Verifying server key and certificate match..."
server_modulus=$(openssl rsa -noout -modulus -in server/private/server.key | openssl md5)
cert_modulus=$(openssl x509 -noout -modulus -in server/certs/server.crt | openssl md5)
if [[ "$server_modulus" != "$cert_modulus" ]]; then
  echo "ERROR: Server private key and certificate do NOT match!"
  exit 1
else
  echo "Server private key and certificate match OK."
fi

# Remove passphrase from server private key for Apache compatibility
echo "Removing passphrase from server private key..."
openssl rsa -in server/private/server.key -out server/private/server.key.unencrypted
mv server/private/server.key.unencrypted server/private/server.key
chmod 600 server/private/server.key

echo "Creating chained certificate..."
cat server/certs/server.crt sub-ca/certs/sub-ca.crt root-ca/certs/ca.crt > server/certs/chained.crt

echo "Installing Root CA certificate to system trust store..."
cp root-ca/certs/ca.crt /usr/local/share/ca-certificates/acmeroot.crt
update-ca-certificates

echo "Stopping and disabling system apache2 to avoid port conflicts..."
systemctl stop apache2 || true
systemctl disable apache2 || true

echo "Starting XAMPP..."
/opt/lampp/lampp start

# Check if XAMPP Apache is running by checking port 443 or process
if ! netstat -tuln | grep -q ':443'; then
  echo "ERROR: XAMPP Apache is not listening on port 443!"
  exit 1
fi
echo "XAMPP Apache appears to be running and listening on HTTPS port 443."

echo "Installing server certificates into XAMPP SSL folders..."
mkdir -p /opt/lampp/etc/ssl.crt /opt/lampp/etc/ssl.key
cp "$WORKDIR/ca/server/certs/chained.crt" /opt/lampp/etc/ssl.crt/server.crt
cp "$WORKDIR/ca/server/private/server.key" /opt/lampp/etc/ssl.key/server.key
chmod 600 /opt/lampp/etc/ssl.key/server.key

echo "Updating XAMPP SSL config to use generated certificates..."
if [ -f /opt/lampp/etc/extra/httpd-ssl.conf ]; then
  sed -i "s|^\s*SSLCertificateFile.*|SSLCertificateFile /opt/lampp/etc/ssl.crt/server.crt|" /opt/lampp/etc/extra/httpd-ssl.conf
  sed -i "s|^\s*SSLCertificateKeyFile.*|SSLCertificateKeyFile /opt/lampp/etc/ssl.key/server.key|" /opt/lampp/etc/extra/httpd-ssl.conf
else
  echo "WARNING: /opt/lampp/etc/extra/httpd-ssl.conf not found. Please update SSL config manually."
fi

echo "Restarting XAMPP Apache to apply SSL configuration..."
/opt/lampp/lampp restartapache

echo "Configuring BIND DNS for $DOMAIN..."

# ✅ Set config file path first
BIND_LOCAL_CONF="/etc/bind/named.conf.local"
ZONE_FILE="/etc/bind/db.$DOMAIN"

echo "Cleaning old zone entry from named.conf.local (if any)..."
sed -i "/zone \"$DOMAIN\"/,/};/d" "$BIND_LOCAL_CONF"



if ! grep -q "zone \"$DOMAIN\"" "$BIND_LOCAL_CONF"; then
# Remove old conflicting entries (TESTING ONLY — use carefully)
sed -i "/zone \"$DOMAIN\"/,+1d" "$BIND_LOCAL_CONF"
  echo "Adding DNS zone for $DOMAIN to named.conf.local..."
echo "zone \"$DOMAIN\" { type master; file \"$ZONE_FILE\"; };" >> "$BIND_LOCAL_CONF"

else
  echo "DNS zone for $DOMAIN already exists in named.conf.local — skipping."
fi


cat > "$ZONE_FILE" <<EOF
\$TTL    604800
@       IN      SOA     ns.$DOMAIN. root.$DOMAIN. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL

; Name servers
@       IN      NS      ns.$DOMAIN.

; Address of name server
ns      IN      A       127.0.0.1

; Web server IP
@       IN      A       127.0.0.1
EOF

named-checkconf || { echo "BIND configuration error!"; exit 1; }
named-checkzone "$DOMAIN" "$ZONE_FILE" || { echo "BIND zone file error!"; exit 1; }
systemctl restart bind9
# Modify /etc/hosts to resolve DOMAIN to 127.0.0.2
echo "Updating /etc/hosts for $DOMAIN..."
if grep -q "$DOMAIN" /etc/hosts; then
    echo "/etc/hosts already contains $DOMAIN. Updating..."
    sudo sed -i "s/.*$DOMAIN/127.0.0.2 $DOMAIN/" /etc/hosts
else
    echo "Appending $DOMAIN to /etc/hosts..."
    echo "127.0.0.2 $DOMAIN" | sudo tee -a /etc/hosts > /dev/null
fi

# Verify hosts file modification
echo "Pinging $DOMAIN to verify /etc/hosts entry..."
if ping -c 1 "$DOMAIN" &> /dev/null; then
    echo "Ping successful. $DOMAIN is resolving correctly."
else
    echo "⚠️  Warning: Ping to $DOMAIN failed. Please verify /etc/hosts manually."
fi

echo "Setting up basic Apache PHP info page..."
echo "<?php phpinfo(); ?>" > /opt/lampp/htdocs/info.php
chown daemon:daemon /opt/lampp/htdocs/info.php

echo "TLS CA setup complete!"

URL="https://$DOMAIN/info.php"
if command -v xdg-open &> /dev/null; then
  echo "Opening $URL in default browser..."
  xdg-open "$URL" || echo "Failed to open browser automatically, please open $URL manually."
else
  echo "Please open $URL manually in your browser."
fi
echo "=== TLS Setup Finished Successfully ==="
echo "Creating .pem aliases for convenience..."
cp "$WORKDIR/ca/root-ca/certs/ca.crt" "$WORKDIR/ca/root-ca/certs/ca.pem"
cp "$WORKDIR/ca/sub-ca/certs/sub-ca.crt" "$WORKDIR/ca/sub-ca/certs/sub-ca.pem"
cp "$WORKDIR/ca/server/certs/server.crt" "$WORKDIR/ca/server/certs/server.pem"
cp "$WORKDIR/ca/server/certs/chained.crt" "$WORKDIR/ca/server/certs/chained.pem"
cp "$WORKDIR/ca/server/private/server.key" "$WORKDIR/ca/server/private/server.key.pem"

USER_HOME="/home/ubuntu"
DOWNLOAD_DIR="$USER_HOME/Downloads"

# Create Downloads dir if missing
mkdir -p "$DOWNLOAD_DIR"

# Copy relevant certificates needed for Firefox import
cp "$WORKDIR/ca/root-ca/certs/ca.crt"        "$DOWNLOAD_DIR/RootCA.crt"
cp "$WORKDIR/ca/sub-ca/certs/sub-ca.crt"     "$DOWNLOAD_DIR/SubCA.crt"
cp "$WORKDIR/ca/server/certs/server.crt"     "$DOWNLOAD_DIR/ServerCert.crt"
chown ubuntu:ubuntu "$DOWNLOAD_DIR"/*.crt

echo ""
echo "📢 Certificates to import manually in Firefox (via File Browser):"
echo "-----------------------------------------------------------------"
echo "🔐 Authorities Tab (for trusting the CA):"
echo "   • $DOWNLOAD_DIR/RootCA.crt"
echo "   • $DOWNLOAD_DIR/SubCA.crt (optional)"
echo ""
echo "🌐 Servers Tab (optional, for server identity override):"
echo "   • $DOWNLOAD_DIR/ServerCert.crt"
echo ""
echo "⚠️  DO NOT import the private key into Firefox:"
echo "   • $WORKDIR/ca/server/private/server.key.pem"
echo ""
echo "📦 Full cert chain (for servers or nginx config, not Firefox import):"
echo "   • $WORKDIR/ca/server/certs/chained.pem"


# Detect real non-root user running script or fallback to 'ubuntu' user
if [ "$EUID" -eq 0 ]; then
    # Running as root, try to find the original user's home
    REAL_USER=$(logname 2>/dev/null || echo ubuntu)
    USER_HOME=$(eval echo "~$REAL_USER")
else
    # Running as non-root
    REAL_USER=$(whoami)
    USER_HOME="$HOME"
fi
#!/bin/bash

# Define working directory and domain (adjust as needed)
WORKDIR="/root/tls_project"

# Determine real user home directory (handles sudo)
REAL_USER=$(logname 2>/dev/null || echo $SUDO_USER || echo $USER)
USER_HOME=$(eval echo "~$REAL_USER")

echo "User home directory: $USER_HOME"

# Ensure certutil is installed
if ! command -v certutil &> /dev/null; then
    echo "Installing certutil (libnss3-tools)..."
    apt-get update
    apt-get install -y libnss3-tools
fi

# Find the default Firefox profile directory
if [ -f "$USER_HOME/.mozilla/firefox/profiles.ini" ]; then
    FIREFOX_PROFILE="$USER_HOME/.mozilla/firefox/$(grep 'Path=' "$USER_HOME/.mozilla/firefox/profiles.ini" | head -n1 | cut -d= -f2)"
else
    FIREFOX_PROFILE=""
fi

if [ -d "$FIREFOX_PROFILE" ]; then
    echo "Firefox profile directory detected: $FIREFOX_PROFILE"

    import_cert() {
        local cert_file="$1"
        local cert_name="$2"
        if certutil -L -d sql:"$FIREFOX_PROFILE" | grep -q "$cert_name"; then
            echo "Certificate '$cert_name' already exists. Replacing..."
            certutil -D -n "$cert_name" -d sql:"$FIREFOX_PROFILE" || true
        fi
        certutil -A -n "$cert_name" -t "C,," -i "$cert_file" -d sql:"$FIREFOX_PROFILE"
        echo "✔️  Imported and trusted: $cert_name"
    }

    import_cert "$WORKDIR/ca/root-ca/certs/ca.crt" "AcmeRootCA"
    import_cert "$WORKDIR/ca/sub-ca/certs/sub-ca.crt" "AcmeCA"

    echo "✅ Firefox trust store successfully updated with CA certificates."
else
    echo "⚠️ Firefox profile directory not found, skipping cert import."
fi

echo ""
echo "🌐 Your HTTPS website is ready at:"
echo "https://$DOMAIN/"
echo ""

exit 0
