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

> ✅ This project aligns with the requirements outlined in GENIBARTA tutorial videos and EWU’s course deliverables.

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
<pre> 
wget https://raw.githubusercontent.com/saifkhancse/Self-Signed-SSL-Certificate-Script/main/Self-Signed-SSL-Certificate-Script.sh -O tls-setup.sh
chmod +x tls-setup.sh
sudo ./tls-setup.sh
</pre>
- Input the required information. Leave blank if not needed. It will put default values instead. 
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

## 📹 Reference Videos

- GENIBARTA Part 1
- GENIBARTA Part 2
- GENIBARTA Part 3

---

## ⚠️ Disclaimers

- For educational use only — not production-hardened.
- The private key passphrases are fixed for automation (not secure in production).
- Firefox version 59.0.2 or 72.0.2 is recommended for compatibility.
