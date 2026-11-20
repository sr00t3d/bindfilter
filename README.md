# Bind Filter

Readme: [BR](README-ptbr.md)

![License](https://img.shields.io/github/license/sr00t3d/bindfilter) ![Shell Script](https://img.shields.io/badge/shell-script-green)

<img width="700" alt="BindFilter" src="bindfilter-cover.webp" />

A powerful DNS sinkhole tool for BIND9/Named that blocks known malicious domains by routing them to `127.0.0.1`. Designed to work universally across **cPanel/WHM**, **HestiaPanel**, **DirectAdmin**, and plain **Debian/Ubuntu** or **RHEL/AlmaLinux** servers, it automates protection against DNS spoofing and DNS hijacking with view-aware config patching, automatic backups, and zero-downtime reloads.

---

## 🚀 Features (v2.1.0)

* **Universal Panel & Distro Support:** Auto-detects **cPanel/WHM** (`/etc/named.conf` with views), **HestiaPanel** (`/etc/bind/named.conf.local`), **DirectAdmin** (RHEL or Debian), and plain Debian/RHEL BIND9 setups.
* **View-Aware Injection:** Automatically detects `view "..." { ... }` blocks (such as cPanel/WHM `localhost_resolver`, `internal`, `external`) and injects the ACL `include` inside every view using Python3 (with POSIX `awk` fallback).
* **Automatic Backup:** Always creates a timestamped backup of the target config file before any modification.
* **Zero-Downtime Reload:** Prefers `rndc reload` (live reload, no downtime) with automatic fallback to `systemctl reload`/`restart` and `service`.
* **Config Validation Gate:** Runs `named-checkconf` before any reload — aborts if the config is invalid to prevent outages.
* **Domain Management:** Add (`--add`) or remove (`--remove`) individual domains from the blocklist without re-downloading the full list.
* **Dry-Run Mode (`-n, --dry-run`):** Simulates all operations without touching any files or services.
* **Stats Mode (`--stats`):** Shows total blocked domains, file sizes, panel type, view mode, and last modification date.
* **Clean Uninstall (`--uninstall`):** Removes all injected configuration (both inside views and global) and restores the config cleanly.
* **Automatic HOSTNAME substitution:** SOA records are generated with the real server hostname, not a placeholder.
* **Path normalization:** ACL files downloaded from GitHub are automatically patched to use the correct local zone file paths.

## 📋 Requirements

* `bash` 4.0+
* `named` / `bind9` (ISC BIND installed)
* `named-checkconf`
* `curl`
* Root privileges

## 🔧 Usage & Options

```text
Bind9 DNS Filter & Security v2.1.0
DNS Sinkhole universal: cPanel/WHM, HestiaPanel, DirectAdmin, Debian, RHEL

Usage: bind_filter.sh [COMMAND] [OPTIONS]

Commands:
  -r, --run               Full install: download lists, configure BIND9 and reload
  -u, --update [TARGET]   Update blocklist files. Targets: all | zone | acl
      --add DOMAIN        Add a domain to the local ACL and reload
      --remove DOMAIN     Remove a domain from the local ACL and reload
  -c, --check             Check environment status (files, service, config validation)
      --stats             Show blocklist statistics (domain count, sizes, dates)
      --uninstall         Remove all blocking configuration and restore named.conf

Options:
  -n, --dry-run           Simulate all operations without making real changes
  -v, --verbose           Print debug messages to stderr
      --no-color          Disable colored terminal output
      --no-restart        Skip service reload/restart (useful in automation scripts)
  -h, --help              Show this help message
```

## 💡 Practical Examples

**Full installation (auto-detects your OS and BIND version):**
```bash
./bind_filter.sh -r
```

**Simulate full install without changing anything:**
```bash
./bind_filter.sh -r --dry-run
```

**Add a specific malicious domain manually:**
```bash
./bind_filter.sh --add malware.example.com
```

**Remove a domain from the blocklist:**
```bash
./bind_filter.sh --remove ads.example.net
```

**Update only the ACL (without re-downloading the zone DB):**
```bash
./bind_filter.sh -u acl
```

**Check environment health:**
```bash
./bind_filter.sh -c
```

**Show blocklist statistics:**
```bash
./bind_filter.sh --stats
```

**Complete uninstall:**
```bash
./bind_filter.sh --uninstall
```

## 📝 Example Output

### `-r` (Full Install):
```text
 ______ __           __ _______ __ __ __
|   __ \__|.-----.--|  |    ___|__|  |  |_.-----.----.
|   __ <  ||     |  _  |    ___|  |  |   _|  -__|   _|
|______/__||__|__|_____|___|   |__|__|____|_____|__|

  DNS Sinkhole para BIND9/Named — v2.1.0
  cPanel · HestiaPanel · DirectAdmin · Debian · RHEL

[→] Detectando ambiente BIND9...
[+] Ambiente detectado: cPanel/WHM (RHEL/AlmaLinux — named com views)
[+] Config:    /etc/named.conf
[+] Inject:    /etc/named.conf
[+] Serviço:   named
[+] Zonas:     /var/named/zones/blocked
[+] ACL:       /etc/named.blocked_acl.conf
[+] Painel:    cpanel
[+] Views:     true
[→] Baixando lista de zonas bloqueadas...
[+] Zona de bloqueio instalada: /var/named/zones/blocked/blockeddomains.db
[→] Baixando configuração de ACL...
[+] ACL instalada: /etc/named.blocked_acl.conf
[+] Backup criado: /etc/named.conf.bkp.20261119_211428
Inserted include into 3 view(s): localhost_resolver, external, internal
[+] Include da ACL injetado em cada view de /etc/named.conf
[→] Validando configuração com named-checkconf...
[+] Configuração válida.
[→] Recarregando serviço named...
[+] Instalação completa!
```

### `--stats`:
```text
=== Estatísticas bindfilter ===

  Domínios bloqueados na ACL : 218
  Tamanho da ACL             : 20K
  Última modificação         : 2026-11-19 21:14:28
  Tamanho do sinkhole .db    : 4.0K
  Versão do script           : v2.1.0
  Painel detectado           : cpanel
  Ambiente                   : named (/etc/named.conf)
  Inject em                  : /etc/named.conf
  Usa views                  : true
```

## 📄 License

This project is licensed under the [Apache License 2.0](LICENSE).

---
Autor: **Percio Castelo**  
Contato: [contato@perciocastelo.com.br](mailto:contato@perciocastelo.com.br)  
Website: [https://perciocastelo.com.br](https://perciocastelo.com.br)
