# Bind Filter

Readme: [EN](README.md)

![License](https://img.shields.io/github/license/sr00t3d/bindfilter) ![Shell Script](https://img.shields.io/badge/shell-script-green)

<img width="700" alt="BindFilter" src="bindfilter-cover.webp" />

Uma ferramenta poderosa para filtrar domínios maliciosos conhecidos no Bind9. Este script automatiza a proteção contra DNS spoofing e DNS hijacking, mantendo suas listas de bloqueio atualizadas e configuradas corretamente.

---

## Funcionalidades

- **Atualizações Automatizadas**: Baixa as versões mais recentes de `blockeddomains.db` e `blocked_domain_acl.conf`.
- **Filtragem DNS**: Aplica políticas de segurança de forma integrada à sua instância do Bind9.
- **Verificação de Ambiente**: Verificação nativa da instalação do Bind9 e integridade da configuração.
- **Controle de Versão**: Verifica automaticamente se o script possui atualizações para garantir que você tenha os patches de segurança mais recentes.

## Requisitos

- **SO**: Linux (Debian, Ubuntu, CentOS, RHEL suportados).
- **Service**: Bind9 (ISC BIND) instalado.
- **Tools**: `curl` e privilégios de `sudo`.

## Instalação Rápida

1. **Baixe o arquivo no servidor:**

```bash
git clone https://github.com/sr00t3d/bindfilter/
```

2. **Dê permissão de execução:**

```bash
cd bindfilter/
chmod +x bind_filter.sh
```

3. **Execute o script:**

```bash
./bind_filter.sh VALOR
```
### Opções

| Opções | Descrição |
| :--- | :--- |
| `-r, --run` | Aplica filtros DNS e reinicia/recarrega o Bind9. |
| `-u, --update all` | Atualiza os arquivos de zona e ACL. |
| `-u, --update zone` | Atualizações apenas o arquivo `blockeddomains.db`. |
| `-u, --update acl` | Atualizações apenas o arquivo `blocked_domain_acl.conf`. |
| `-c, --check` | Valida o ambiente Bind9 atual. |
| `-h, --help` | Exibe mensagem de ajuda. |

Exemplos:

Instalar a configuração:

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

**Atualizar todos os arquivo de configuração:**


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

**Verifica as configurações:**

```bash
./bind_filter.sh -c

--- CHECK MODE ---
Checking files:
 [OK] /etc/bind/named.conf
 [OK] /etc/bind/zones/blockeddomains.db
 [OK] /etc/bind/blocked_domain_acl.conf

ACTIVE
```

*Nota: Sempre revise scripts antes de executá-los com privilégios de superusuário (sudo).*

## Resultados de zona sem autoridade

Domínio `bradesco.com.br` **EXISTE** na `/etc/bind/blocked_domain_acl.conf`

```bash
grep bradesco.com.br /etc/bind/blocked_domain_acl.conf 
zone "bradesco.com.br" {type master; file "/etc/bind/zones/blockeddomains.db";};
```

Resposta de autoridade `0`:

```bash
dig @localhost bradesco.com.br | grep AUTHORITY
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
```

Domínio `bradesco2.com.br` **NÃO EXISTE** na `/etc/bind/blocked_domain_acl.conf`

Resposta de autoridade `1`:

```bash
dig @localhost bradesco2.com.br | grep AUTHORITY
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
```

## systemctl

- O script utiliza do `systemctl` para reiniciar os serviços, você pode utilizar o `service` para reiniciar sem problemas.
- Se o seu bind9 está em um diretorio de instalação padrão, exemplo, `/var/lib/bind/` crie um syslink para o named ou altere a variavel BIND_DIR_DEBIAN

```bash
ln -s /var/lib/bind/ /var/named
```

---

## Troubleshooting (Solução de Problemas)

- **Permissões**: Certifique-se de que o script tem permissão de execução `+x`.
- **Conectividade**: Verifique se o seu servidor consegue alcançar `raw.githubusercontent.com`.
- **Logs**: Verifique `journalctl -u named` se o Bind9 falhar ao reiniciar.

## Aviso Legal

> [!WARNING]
> Este software é fornecido "tal como está". Certifique-se sempre de ter permissão explícita antes de executar. O autor não se responsabiliza por qualquer uso indevido, consequências legais ou impacto nos dados causados ​​por esta ferramenta.

## Detailed Tutorial

Para um guia completo, passo a passo, confira meu artigo completo:

👉 [**Filtrando domínios maliciosos conhecidos no Bind9**](https://perciocastelo.com.br/blog/filtering-known-malicious-domains-in-Bind9.html)

## Licença

Este projeto está licenciado sob a **GNU General Public License v3.0**. Consulte o arquivo [LICENSE](LICENSE) para mais detalhes.