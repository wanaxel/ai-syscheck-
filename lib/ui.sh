# lib/ui.sh — Terminal output helpers

# Auto-disable color in dumb terminals / pipes
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ]; then
    RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
    RED=''; YELLOW=''; GREEN=''; CYAN=''; BOLD=''; RESET=''
fi

banner() { echo -e "\n${BOLD}${CYAN}══ $1 ══${RESET}"; }
ok()     { echo -e "${GREEN}[OK]${RESET}  $1"; }
warn()   { echo -e "${YELLOW}[WARN]${RESET} $1"; }
err()    { echo -e "${RED}[ERR]${RESET}  $1"; }
info()   { echo -e "      $1"; }

ui_banner() {
    echo -e "${BOLD}"
    echo "╔════════════════════════════════════════════╗"
    echo "║        ai-syscheck  •  local AI audit      ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo "  Model    : $MODEL"
    echo "  Log      : $LOG_FILE"
    echo ""
}
