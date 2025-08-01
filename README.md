
# 🔐 Self-Signed SSL Certificate Automation Script

This project provides a **fully automated Bash script** to create a complete **TLS Certificate Authority (CA) hierarchy** with:
- A **Root CA** (`AcmeRootCA`)
- A **Subordinate CA** (`AcmeCA`)
- A **server certificate** for a domain (e.g., `www.verysecureserver.com`)

It also configures:
- **XAMPP Web Server**
- **BIND DNS**
- **Firewall rules (UFW)**
- **Trust setup in Firefox**
- **A simple secure file upload page over HTTPS**

---

## 📌 Project Context

This script was created as part of a security mini-project for a university course. The project involves building a secure web infrastructure with a custom certificate authority, private server certificates, DNS configuration, and HTTPS hosting.

> ✅ This project aligns with the requirements outlined in EWU’s course deliverables.

---

## 🎯 Features

- 🔧 Automates Root CA, Sub CA, and server certificate creation (via OpenSSL)
- 🌐 Sets up `www.verysecureserver.com` with signed TLS certs
- 🔐 Secure web server with HTTPS (using XAMPP)
- 🧾 Firefox certificate trust import (no warnings/padlock errors)
- 🛡️ Configures BIND DNS and UFW firewall rules
- 📁 Includes a working file upload form over HTTPS
- 🧰 All tools installed automatically (OpenSSL, BIND, XAMPP, PHP, certutil)

---

## 📂 Folder Structure (after script runs)
<pre>
~/tls_project/
├── ca/
│   ├── root-ca/         # AcmeRootCA private keys, certs
│   ├── sub-ca/          # AcmeCA private keys, certs
│   └── server/          # www.verysecureserver.com certs
└── /opt/lampp/htdocs/   # XAMPP public web root (with upload form)
</pre>

---

## 🛠️ Prerequisites

- Ubuntu 18.04+ (Tested on Ubuntu 18.04 and 20.04)
- Sudo/root privileges
- Internet connection (to install packages & XAMPP)
- Optional: Firefox (for CA trust import)

---

## 🚀 How to Run
```bash
sudo -i
wget https://raw.githubusercontent.com/saifkhancse/Self-Signed-SSL-Certificate-Script/main/Self-Signed-SSL-Certificate-Script.sh -O tls-setup.sh
chmod +x tls-setup.sh
sudo ./tls-setup.sh
```

- Input the required information. Leave blank if not needed. It will put default values instead.
- If script fails after installing xampp, just rerun the script. No need to download the script again! 
- If already run script succssfully, just start the xampp server
<pre>
sudo /opt/lampp/manager-linux-x64.run
</pre>
---

## 🔍 Verification
- Open Firefox and visit: https://www.verysecureserver.com
  ✅ You should see a green padlock (trusted connection).

- Use the upload form: https://www.verysecureserver.com/upload.php

- Verify DNS:
    ping www.verysecureserver.com

- Optionally inspect traffic with Wireshark on another machine.

---

## 📁 Files of Interest

Self-Signed-SSL-Certificate-Script.sh   -> Main Bash script (automated setup)  
upload.php (created dynamically)         -> Secure file upload form  
/etc/bind/                               -> BIND DNS zone and config files  
/opt/lampp/htdocs/                       -> Public files served by XAMPP  

---


## 📁 Additional Automation Scripts

This project includes several **additional automation scripts** for security testing and certificate management.

---
### 🌐 DNS Server + Client Setup  

📥 **Download & Run:**
```bash
sudo -i
wget https://raw.githubusercontent.com/saifkhancse/Self-Signed-SSL-Certificate-Script/main/dns_setup.sh -O dns_setup.sh
chmod +x dns_setup.sh
./dns_setup.sh server   # For DNS server setup
./dns_setup.sh client   # For client DNS configuration
```

---

### 🚀 How to Use

**On server machine, run:**
```bash
sudo ./this_script.sh server
```

**On client machine, run:**
```bash
sudo ./this_script.sh client
```

---

### 🧩 This covers:

**Server:**
- Sets up `/etc/hosts`, BIND config files, forward/reverse zones
- Restarts BIND
- Sets local `/etc/resolv.conf` to `127.0.0.1`

**Client:**
- Disables `systemd-resolved` stub resolver
- Removes `/etc/resolv.conf` symlink if any
- Creates `/etc/resolv.conf` pointing directly to BIND server IP
- Tests DNS resolution

---

🔧 **What it does:**
- Prompts for domain, hostname, IP, and gateway
- Sets up **BIND9 DNS server** with forward and reverse zone files
- Configures `/etc/hosts` and `/etc/resolv.conf`
- Updates `named.conf.options` and `named.conf.local`
- Automatically restarts BIND and verifies DNS resolution
- Client mode disables `systemd-resolved` and configures DNS to point to the server

🧪 **Verifies with:**
- `nslookup` for hostname and domain
- `ping` to test DNS resolution
- Ensures browser or tools can resolve names via your DNS server

---



### 🛡️ Intrusion Detection System (IDS) Setup
**Script:** `setup_ids_snort.sh`

📥 **Download & Run:**
```bash
sudo -i
wget https://raw.githubusercontent.com/saifkhancse/Self-Signed-SSL-Certificate-Script/main/setup_ids_snort.sh -O setup_ids_snort.sh
chmod +x setup_ids_snort.sh
sudo ./setup_ids_snort.sh
```

🔧 **What it does:**
- Detects your system’s interface and IP
- Installs Snort
- Configures `$HOME_NET` in `snort.conf`
- Adds a custom DoS detection rule
- Starts Snort in background mode

---

### 📡 Start DoS Listener (Snort Live Monitoring)
**Script:** `start_dos_listener_host.sh`

📥 **Download & Run:**
```bash
sudo -i
wget https://raw.githubusercontent.com/saifkhancse/Self-Signed-SSL-Certificate-Script/main/start_dos_listener_host.sh -O start_dos_listener_host.sh
chmod +x start_dos_listener_host.sh
sudo ./start_dos_listener_host.sh
```

🛠️ Displays real-time alerts from Snort for possible DoS attacks.

---

### 💣 DoS Attack Simulation (Attacker Side)
**Script:** `attacker_dos_attack.sh`

📥 **Download & Run:**
```bash
sudo -i
wget https://raw.githubusercontent.com/saifkhancse/Self-Signed-SSL-Certificate-Script/main/attacker_dos_attack.sh -O attacker_dos_attack.sh
chmod +x attacker_dos_attack.sh
sudo ./attacker_dos_attack.sh
```

⚠️ Simulates SYN flood attack on port 443 using hping3.

---

### 🔒 Revoke Server Certificate
**Script:** `revoke_server_cert.sh`

📥 **Download & Run:**
```bash
sudo -i
wget https://raw.githubusercontent.com/saifkhancse/Self-Signed-SSL-Certificate-Script/main/revoke_server_cert.sh -O revoke_server_cert.sh
chmod +x revoke_server_cert.sh
sudo ./revoke_server_cert.sh
```

🔧 **What it does:**
- Revokes the existing server certificate using Sub CA
- Regenerates CRL (certificate revocation list)
- Publishes the CRL to XAMPP for OCSP-style checking


---

## 📸 Report & Video Deliverables (Course)

For course submission:
- Submit a PDF report with:
    - Setup steps, screenshots, theory
    - Firefox padlock verification
    - Wireshark capture (if applicable)

- Include a video presentation (8–10 min) showing:
    - Your VM setup
    - How the TLS chain was built
    - Secure server working with certificate padlock

---

## ⚠️ Disclaimers

- For educational use only — not production-hardened.
- The private key passphrases are fixed for automation (not secure in production).
- Firefox version 59.0.2 or 72.0.2 is recommended for compatibility.
