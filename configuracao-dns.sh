#!/bin/sh

# =============================================================================
#  Utilitário de Configuração de DNS
#  Compatível com Linux Mint / Ubuntu e qualquer distro com NetworkManager
# =============================================================================

# --- Cores para o terminal ---
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
CIANO='\033[0;36m'
BRANCO='\033[1;37m'
CINZA='\033[0;90m'
NEGRITO='\033[1m'
RESET='\033[0m'

# --- Funções de formatação ---
ok()     { printf "${VERDE}  ✓${RESET}  %s\n" "$1"; }
info()   { printf "${CIANO}  ●${RESET}  %s\n" "$1"; }
erro()   { printf "${VERMELHO}  ✗${RESET}  %s\n" "$1"; }
passo()  { printf "\n${BRANCO}  $1${RESET}\n${CINZA}  $(printf '─%.0s' $(seq 1 40))${RESET}\n"; }
label()  { printf "${CINZA}  ›${RESET} ${AMARELO}%s${RESET} " "$1"; }

# --- Desenha a caixa do resumo ---
# largura baseada no maior valor esperado: dois endereços IPv6 (37 caracteres)
desenhar_resumo() {
    local col=37
    local interno=$((col + 14))
    local borda=$(printf '─%.0s' $(seq 1 $interno))
    local titulo="Resumo da configuração"
    local espaco_esq="              "
    local espaco_dir="               "

    printf "\n${CIANO}  ╭${borda}╮${RESET}\n"
    printf "${CIANO}  │${RESET}${espaco_esq}${BRANCO}${titulo}${RESET}${espaco_dir}${CIANO}│${RESET}\n"
    printf "${CIANO}  ├${borda}┤${RESET}\n"
    printf "${CIANO}  │${RESET}  ${CINZA}Conexão   ${RESET}${BRANCO}%-${col}s${RESET}  ${CIANO}│${RESET}\n" "$CONEXAO"
    printf "${CIANO}  │${RESET}  ${CINZA}Protocolo ${RESET}${BRANCO}%-${col}s${RESET}  ${CIANO}│${RESET}\n" "$MODO"
    [ -n "$DNS_V4" ] && \
        printf "${CIANO}  │${RESET}  ${CINZA}DNS IPv4  ${RESET}${BRANCO}%-${col}s${RESET}  ${CIANO}│${RESET}\n" "$DNS_V4"
    [ -n "$DNS_V6" ] && \
        printf "${CIANO}  │${RESET}  ${CINZA}DNS IPv6  ${RESET}${BRANCO}%-${col}s${RESET}  ${CIANO}│${RESET}\n" "$DNS_V6"
    printf "${CIANO}  ╰${borda}╯${RESET}\n"
}

# --- Função auxiliar: executa um comando e encerra se falhar ---
executar() {
    local descricao="$1"
    shift
    info "$descricao"
    if "$@"; then
        ok "Concluído"
    else
        erro "Falha em: $descricao"
        echo
        erro "Encerrando o script. Verifique o nome da conexão e tente novamente."
        exit 1
    fi
}

# --- Exibe valores de DNS atuais antes de aplicar ---
mostrar_dns_atual() {
    passo "DNS atual da conexão \"$CONEXAO\""
    nmcli connection show "$CONEXAO" \
        | grep --extended-regexp "ipv4.dns|ipv6.dns" \
        | grep --invert-match "search\|wins" \
        | sed 's/^/  /'
    echo
}

# --- Configuração IPv4 ---
configurar_ipv4() {
    passo "Configurando DNS IPv4"
    executar "Definindo servidores e desativando DNS automático" \
        sudo nmcli connection modify "$CONEXAO" \
            ipv4.dns "$DNS_V4" \
            ipv4.ignore-auto-dns yes
}

# --- Configuração IPv6 ---
configurar_ipv6() {
    passo "Configurando DNS IPv6"
    executar "Definindo servidores e desativando DNS automático" \
        sudo nmcli connection modify "$CONEXAO" \
            ipv6.dns "$DNS_V6" \
            ipv6.ignore-auto-dns yes
}

# --- Reativa a conexão para aplicar as mudanças ---
reconectar() {
    passo "Aplicando alterações"
    executar "Reativando a conexão \"$CONEXAO\"" \
        sudo nmcli connection up "$CONEXAO"
}

# --- Verifica se o DNS está funcionando ---
verificar() {
    passo "Verificando resolução de nomes"

    if [ "$MODO" = "ipv4" ] || [ "$MODO" = "ambos" ]; then
        info "Testando IPv4..."
        if nslookup google.com > /dev/null 2>&1; then
            ok "Resolução IPv4 funcionando"
        else
            erro "Resolução IPv4 falhou. Verifique sua conexão."
        fi
    fi

    if [ "$MODO" = "ipv6" ] || [ "$MODO" = "ambos" ]; then
        info "Testando IPv6..."
        if nslookup -type=AAAA google.com > /dev/null 2>&1; then
            ok "Resolução IPv6 funcionando"
        else
            erro "Resolução IPv6 falhou (pode ser normal se a rede não suportar IPv6)."
        fi
    fi
}

# =============================================================================
#  INTERFACE
# =============================================================================

clear

printf "${CIANO}"
printf "  ╭─────────────────────────────────────╮\n"
printf "  │                                     │\n"
printf "  │      Configuração de DNS            │\n"
printf "  │      NetworkManager / nmcli         │\n"
printf "  │                                     │\n"
printf "  ╰─────────────────────────────────────╯\n"
printf "${RESET}\n"

# 1. Nome da conexão
passo "Conexão de rede"
CONEXAO=$(nmcli --terse --fields NAME connection show --active | fzf \
    --prompt "  › Conexão: " \
    --height 10 \
    --border rounded \
    --color "prompt:3,border:6,pointer:2")

if [ -z "$CONEXAO" ]; then
    erro "Nome da conexão não pode ser vazio."
    exit 1
fi

# 2. Modo de configuração
clear
passo "Protocolo"
MODO=$(printf "ipv4\nipv6\nambos" | fzf \
    --prompt "  › Protocolo: " \
    --height 9 \
    --border rounded \
    --color "prompt:3,border:6,pointer:2")

if [ -z "$MODO" ]; then
    erro "Nenhum protocolo selecionado."
    exit 1
fi

# 3. Endereços DNS conforme o modo escolhido
if [ "$MODO" = "ipv4" ] || [ "$MODO" = "ambos" ]; then
    clear
    passo "Servidores DNS IPv4"
    printf "${CINZA}  Separe por espaço. Ex: 94.140.14.14 94.140.15.15${RESET}\n\n"
    label "Endereços:"
    read DNS_V4
    if [ -z "$DNS_V4" ]; then
        erro "Endereço IPv4 não pode ser vazio."
        exit 1
    fi
fi

if [ "$MODO" = "ipv6" ] || [ "$MODO" = "ambos" ]; then
    clear
    passo "Servidores DNS IPv6"
    printf "${CINZA}  Separe por espaço. Ex: 2a10:50c0::ad1:ff 2a10:50c0::ad2:ff${RESET}\n\n"
    label "Endereços:"
    read DNS_V6
    if [ -z "$DNS_V6" ]; then
        erro "Endereço IPv6 não pode ser vazio."
        exit 1
    fi
fi

# 4. Confirmação
clear
desenhar_resumo
echo
label "Confirmar e aplicar? [s/N]:"
read CONFIRMA

case "$CONFIRMA" in
    s|S|sim|Sim) ;;
    *) echo; info "Operação cancelada."; echo; exit 0 ;;
esac

# =============================================================================
#  EXECUÇÃO
# =============================================================================

mostrar_dns_atual

[ "$MODO" = "ipv4" ] || [ "$MODO" = "ambos" ] && configurar_ipv4
[ "$MODO" = "ipv6" ] || [ "$MODO" = "ambos" ] && configurar_ipv6

reconectar
verificar

echo
printf "${VERDE}"
printf "  ╭─────────────────────────────────────╮\n"
printf "  │                                     │\n"
printf "  │   ✓  Configuração concluída!        │\n"
printf "  │                                     │\n"
printf "  ╰─────────────────────────────────────╯\n"
printf "${RESET}\n"
