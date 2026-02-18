# dns-config
Script simples feito com o Claude para configuração de DNS no Linux Mint pela CLI. O nmcli já é bastante simples de usar, porém criei isso com o objetivo de experimentar vibe coding com Claude.

Para fazer funcionar, certifique-se de ter o fzf e o nmcli instalados no seu computador. No Linux Mint o nmcli já vem instalado por padrão. Para instalar o fzf use:

```bash
sudo apt update && sudo apt install fzf
```

Não recomendo usar esse script em outras distros se não souber como ele funciona, erros podem acontecer por inúmeros fatores. Esse projeto é apenas uma experimentação.

Para baixar e executar o script:

```bash
curl -fsSL https://raw.githubusercontent.com/GhostPython297/dns-config/main/configuracao-dns.sh | sh
```
