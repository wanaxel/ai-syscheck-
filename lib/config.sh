# lib/config.sh — Global defaults (override via env or CLI flags)

MODEL="${AI_MODEL:-llama3.2}"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
LOG_DIR="${LOG_DIR:-$HOME/.local/share/ai-syscheck}"
LOG_FILE="$LOG_DIR/report-$(date +%Y%m%d-%H%M%S).txt"
TOP_N_DIRS="${TOP_N_DIRS:-20}"
SMART_ENABLED="${SMART_ENABLED:-true}"
SKIP_CHAT="${SKIP_CHAT:-false}"

# Populated by detect.sh
DISTRO=""
PKG_MGR=""
COMPOSITOR=""
BOOTLOADER=""
KERNEL_TYPE=""
ENV=""         # tty | wayland | x11
