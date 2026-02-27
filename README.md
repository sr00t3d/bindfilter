# Bind Filter 🛡️

Readme: [BR](README.md)

<img width="700" alt="BindFilter" src="bindfilter-cover.webp" />

A powerful tool to filter known malicious domains in Bind9. This script automates protection against DNS spoofing and DNS hijacking by keeping your blocklists updated and correctly configured.

---

## ✨ Features

* **Automated Updates**: Downloads the latest versions of `blockeddomains.db` and `blocked_domain_acl.conf`.
* **DNS Filtering**: Applies security policies seamlessly into your Bind9 instance.
* **Environment Check**: Native verification of Bind9 installation and configuration integrity.
* **Version Control**: Automatically checks if the script has updates to ensure you have the latest security patches.

## 🛠️ Requirements

* **OS**: Linux (Debian, Ubuntu, CentOS, RHEL supported).
* **Service**: Bind9 (ISC BIND) installed.
* **Tools**: `curl` and `sudo` privileges.

## 🚀 Quick Installation

1. **Clone the repository on the server:**

```bash
git clone https://github.com/sr00t3d/bindfilter/
```

2. **Grant execution permission:**

```bash
cd bindfilter/
chmod +x bind_filter.sh
```

3. **Run the script:**

```bash
./bind_filter.sh VALUE
```

### Options

| Options | Description |
| --- | --- |
| `-r, --run` | Applies DNS filters and restarts/reloads Bind9. |
| `-u, --update all` | Updates both zone and ACL files. |
| `-u, --update zone` | Updates only the `blockeddomains.db` file. |
| `-u, --update acl` | Updates only the `blocked_domain_acl.conf` file. |
| `-c, --check` | Validates the current Bind9 environment. |
| `-h, --help` | Displays the help message. |

**Examples:**

Install the configuration:

```bash
./bind_filter.sh -r

[!] Checking Bind9 installation...
[+] Bind9 detected.
[+] Configuration file found: /etc/bind/named.conf
[+] Downloading blocked zones list...
[+] Downloading ACL configuration...
[!] ACL include already exists in config.
[!] Restarting DNS service (bind9)...
[+] Service restarted successfully.
```

**Update all configuration files:**

```bash
./bind_filter.sh -u all

[!] Checking Bind9 installation...
[+] Bind9 detected.
[+] Configuration file found: /etc/bind/named.conf
[!] Updating ALL files...
[+] Downloading blocked zones list...
[+] Downloading ACL configuration...
[!] Restarting DNS service (bind9)...
[+] Service restarted successfully.
```

**Check configurations:**

```bash
./bind_filter.sh -c

--- CHECK MODE ---
Checking files:
 [OK] /etc/bind/named.conf
 [OK] /etc/bind/zones/blockeddomains.db
 [OK] /etc/bind/blocked_domain_acl.conf

ACTIVE
```

*Note: Always review scripts before running them with superuser (sudo) privileges.*

## Non-authoritative zone results

Domain `bradesco.com.br` **EXISTS** in `/etc/bind/blocked_domain_acl.conf`

```bash
grep bradesco.com.br /etc/bind/blocked_domain_acl.conf 
zone "bradesco.com.br" {type master; file "/etc/bind/zones/blockeddomains.db";};
```

Authority response `0`:

```bash
dig @localhost bradesco.com.br | grep AUTHORITY
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
```

Domain `bradesco2.com.br` **DOES NOT EXIST** in `/etc/bind/blocked_domain_acl.conf`

Authority response `1`:

```bash
dig @localhost bradesco2.com.br | grep AUTHORITY
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
```

## ⚠️ systemctl

* The script uses `systemctl` to restart services, but you can use `service` to restart manually without issues.
* If your Bind9 is in a non-standard installation directory (e.g., `/var/lib/bind/`), create a symlink to named or change variable BIND_DIR_DEBIAN

```bash
ln -s /var/lib/bind/ /var/named
```

---

## 🛠️ Troubleshooting

* **Permissions**: Ensure the script has execution permission (`+x`).
* **Connectivity**: Verify if your server can reach `raw.githubusercontent.com`.
* **Logs**: Check `journalctl -u named` if Bind9 fails to restart.

## ⚠️ Legal Disclaimer

> [!WARNING]
> This software is provided "as is". Always ensure you have explicit permission before execution. The author is not responsible for any misuse, legal consequences, or data impact caused by this tool.

## 📚 Detailed Tutorial

For a complete, step-by-step guide, check out my full article:

👉 **[Filter known malicious domains in Bind9](https://perciocastelo.com.br/blog/filter-known-malicious-domains-in-Bind9.html)**

## License 📄

This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](https://www.google.com/search?q=LICENSE) file for more details.