# Bind Filter 🛡️

Readme: [English](README.md)

<img width="700" alt="BindFilter" src="https://github.com/user-attachments/assets/a42468cb-91a0-4838-933e-97c3a3a2151c" />

![License](https://img.shields.io/github/license/sr00t3d/bindfilter)
![Shell Script](https://img.shields.io/badge/shell-script-green)

Uma ferramenta poderosa para filtrar domínios maliciosos conhecidos no Bind9. Este script automatiza a proteção contra DNS spoofing e DNS hijacking, mantendo suas listas de bloqueio atualizadas e configuradas corretamente.

---

## ✨ Features

- **Atualizações Automatizadas**: Baixa as versões mais recentes de `blockeddomains.db` e `blocked_domain_acl.conf`.
- **Filtragem DNS**: Aplica políticas de segurança de forma integrada à sua instância do Bind9.
- **Verificação de Ambiente**: Verificação nativa da instalação do Bind9 e integridade da configuração.
- **Controle de Versão**: Verifica automaticamente se o script possui atualizações para garantir que você tenha os patches de segurança mais recentes.

## 🛠️ Requisitos

- **SO**: Linux (Debian, Ubuntu, CentOS, RHEL suportados).
- **Service**: Bind9 (ISC BIND) instalado.
- **Tools**: `curl` e privilégios de `sudo`.

## 🚀 Instalação Rápida

Você pode executar o script diretamente sem clonar o repositório:

```bash
curl -s https://raw.githubusercontent.com/sr00t3d/bindfilter/main/bind_filter.sh | sudo bash -s -- -r
```

*Nota: Sempre revise scripts antes de executá-los com privilégios de superusuário (sudo).*

## Uso

### Opções

| Opções | Descrição |
| :--- | :--- |
| `-r, --run` | Aplica filtros DNS e reinicia/recarrega o Bind9. |
| `-u, --update all` | Atualiza os arquivos de zona e ACL. |
| `-u, --update zone` | Atualizações apenas o arquivo `blockeddomains.db`. |
| `-u, --update acl` | Atualizações apenas o arquivo `blocked_domain_acl.conf`. |
| `-c, --check` | Valida o ambiente Bind9 atual. |
| `-h, --help` | Exibe mensagem de ajuda. |

### Instalação Manual

1. **Clonar**: `git clone https://github.com/sr00t3d/bindfilter.git`
2. **Acessar**: `cd bindfilter`
3. **Executar**: `chmod +x bind_filter.sh && sudo ./bind_filter.sh -r`

---

## 🛠️ Troubleshooting (Solução de Problemas)

- **Permissões**: Certifique-se de que o script tem permissão de execução `+x`.
- **Conectividade**: Verifique se o seu servidor consegue alcançar `raw.githubusercontent.com`.
- **Logs**: Verifique `journalctl -u named` se o Bind9 falhar ao reiniciar.

## ⚠️ Disclaimer

> [!WARNING]
> Este software é fornecido "como está". Embora tenha sido amplamente testado em ambientes Dovecot, **sempre faça um backup completo** dos seus diretórios Maildir antes de executar qualquer script de conversão. O autor não se responsabiliza por qualquer perda de dados.

## 📚 Detailed Tutorial

For a complete step-by-step guide on how to import the generated files into Thunderbird and troubleshoot common migration issues, check out my full article:

👉 [**Filter known malicious domains in Bind9**](https://perciocastelo.com.br/blog/filter-known-malicious-domains-in-Bind9.html)

## License 📄

Este projeto está licenciado sob a **GNU General Public License v3.0**. Consulte o arquivo [LICENSE](LICENSE) para mais detalhes.
