# Bind Filter 🛡️

<img width="700" alt="BindFilter" src="https://github.com/user-attachments/assets/a42468cb-91a0-4838-933e-97c3a3a2151c" />


![License](https://img.shields.io/github/license/sr00t3d/bindfilter)
![Shell Script](https://img.shields.io/badge/shell-script-green)

A powerful tool to filter known malicious domains in Bind9. This script automates the protection against DNS spoofing and DNS hijacking by keeping your blocklists updated and properly configured.

---

## Features

- **Automated Updates**: Download the latest `blockeddomains.db` and `blocked_domain_acl.conf`.
- **DNS Filtering**: Seamlessly apply security policies to your Bind9 instance.
- **Environment Check**: Built-in verification for Bind9 installation and config health.
- **Version Control**: Auto-checks for script updates to ensure you have the latest security patches.

## Requirements

- **OS**: Linux (Debian, Ubuntu, CentOS, RHEL supported).
- **Service**: Bind9 (ISC BIND) installed.
- **Tools**: `curl` and `sudo` privileges.

## Quick Installation

You can run the script directly without cloning the repo:

```bash
curl -s https://raw.githubusercontent.com/sr00t3d/bindfilter/main/bind_filter.sh | sudo bash -s -- -r
```

*Note: Always review scripts before running them with sudo.*

## Usage

### Options

| Option | Description |
| :--- | :--- |
| `-r, --run` | Applies DNS filters and restarts/reloads Bind9. |
| `-u, --update all` | Updates both zone and ACL files. |
| `-u, --update zone` | Updates only the `blockeddomains.db` file. |
| `-u, --update acl` | Updates only the `blocked_domain_acl.conf` file. |
| `-c, --check` | Validates current Bind9 environment. |
| `-h, --help` | Displays help message. |

### Manual Installation

1. **Clone**: `git clone https://github.com/sr00t3d/bindfilter.git`
2. **Access**: `cd bindfilter`
3. **Execute**: `chmod +x bind_filter.sh && sudo ./bind_filter.sh -r`

---

## Troubleshooting

- **Permissions**: Ensure the script has `+x` permission.
- **Connectivity**: Verify if your server can reach `raw.githubusercontent.com`.
- **Logs**: Check `journalctl -u named` if Bind9 fails to restart.

## License 📄

This project is licensed under the **GNU General Public License v2.0**. See the [LICENSE](LICENSE) file for details.
