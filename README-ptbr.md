# Bind Filter

Readme: [EN](README.md)

![License](https://img.shields.io/github/license/sr00t3d/bindfilter) ![Shell Script](https://img.shields.io/badge/shell-script-green)

<img width="700" alt="BindFilter" src="bindfilter-cover.webp" />

Uma ferramenta de DNS sinkhole para BIND9/Named que bloqueia domínios maliciosos conhecidos redirecionando-os para `127.0.0.1`. Projetada para funcionar universalmente em **cPanel/WHM**, **HestiaPanel**, **DirectAdmin** e servidores **Debian/Ubuntu** ou **RHEL/AlmaLinux** puros, automatiza a proteção contra DNS spoofing e DNS hijacking com patching inteligente compatível com views, backups automáticos e reloads sem downtime.

---

## 🚀 Funcionalidades (v2.1.0)

* **Suporte Universal a Painéis e Distribuições:** Auto-detecta **cPanel/WHM** (`/etc/named.conf` com views), **HestiaPanel** (`/etc/bind/named.conf.local`), **DirectAdmin** (RHEL ou Debian) e ambientes BIND9 sem painel.
* **Injeção Compatível com Views:** Detecta automaticamente blocos `view "..." { ... }` (como `localhost_resolver`, `internal`, `external` no cPanel/WHM) e injeta o `include` da ACL dentro de cada view via Python3 (com fallback POSIX `awk`).
* **Backup Automático:** Sempre cria um backup com timestamp do arquivo de configuração antes de qualquer modificação.
* **Reload Sem Downtime:** Preferência por `rndc reload` (recarga em memória, sem interrupção de serviço) com fallback automático para `systemctl reload`/`restart` e `service`.
* **Validação de Configuração:** Executa `named-checkconf` antes de qualquer reload — aborta se a configuração estiver inválida para evitar indisponibilidade.
* **Gestão Individual de Domínios:** Adicione (`--add`) ou remova (`--remove`) domínios específicos da lista de bloqueio sem re-baixar a lista completa.
* **Modo Dry-Run (`-n, --dry-run`):** Simula todas as operações sem tocar em nenhum arquivo ou serviço.
* **Modo Stats (`--stats`):** Exibe total de domínios bloqueados, tamanho dos arquivos, painel detectado, modo de views e data de última modificação.
* **Desinstalação Limpa (`--uninstall`):** Remove toda a configuração injetada (dentro de views ou global) e restaura o ambiente de forma limpa.
* **Substituição Automática de HOSTNAME:** Registros SOA gerados com o hostname real do servidor, sem placeholders.
* **Normalização de Paths:** Arquivos ACL baixados do GitHub são automaticamente corrigidos para usar os paths de zona corretos do ambiente local.

## 📋 Pré-requisitos

* `bash` 4.0+
* `named` / `bind9` (ISC BIND instalado)
* `named-checkconf`
* `curl`
* Privilégios de root

## 🔧 Uso e Opções

```text
Bind9 DNS Filter & Security v2.1.0
DNS Sinkhole universal: cPanel/WHM, HestiaPanel, DirectAdmin, Debian, RHEL

Uso: bind_filter.sh [COMANDO] [OPÇÕES]

Comandos:
  -r, --run               Instalação completa: baixa listas, configura BIND9 e recarrega
  -u, --update [ALVO]     Atualiza arquivos de bloqueio. Alvos: all | zone | acl
      --add DOMÍNIO       Adiciona um domínio à ACL local de bloqueio e recarrega
      --remove DOMÍNIO    Remove um domínio da ACL local e recarrega
  -c, --check             Verifica status do ambiente (arquivos, serviço, validação)
      --stats             Exibe estatísticas da lista de bloqueio atual
      --uninstall         Remove as configurações de bloqueio e restaura named.conf

Opções:
  -n, --dry-run           Simula as operações sem efetuar alterações reais
  -v, --verbose           Exibir mensagens de debug detalhadas
      --no-color          Desativar cores na saída de terminal
      --no-restart        Pula o reload/restart do BIND9 (útil em scripts de automação)
  -h, --help              Exibir este menu de ajuda
```

## 💡 Exemplos Práticos

**Instalação completa (auto-detecta OS e versão do BIND):**
```bash
./bind_filter.sh -r
```

**Simular instalação completa sem alterar nada:**
```bash
./bind_filter.sh -r --dry-run
```

**Adicionar um domínio malicioso manualmente:**
```bash
./bind_filter.sh --add malware.exemplo.com.br
```

**Remover um domínio da lista de bloqueio:**
```bash
./bind_filter.sh --remove ads.exemplo.net
```

**Atualizar apenas a ACL (sem re-baixar o .db de zona):**
```bash
./bind_filter.sh -u acl
```

**Verificar saúde do ambiente:**
```bash
./bind_filter.sh -c
```

**Exibir estatísticas da lista:**
```bash
./bind_filter.sh --stats
```

**Desinstalação completa:**
```bash
./bind_filter.sh --uninstall
```

## 📝 Exemplo de Saída

### `-r` (Instalação Completa):
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

## 📄 Licença

Este projeto é distribuído sob a licença [Apache License 2.0](LICENSE).

---
Autor: **Percio Castelo**  
Contato: [contato@perciocastelo.com.br](mailto:contato@perciocastelo.com.br)  
Website: [https://perciocastelo.com.br](https://perciocastelo.com.br)
