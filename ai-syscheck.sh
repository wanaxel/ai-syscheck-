#!/usr/bin/env bash
# ai-syscheck — Local AI system & storage auditor
# Works from TTY, Wayland, or X11. No DE required.
# Usage: sudo ai-syscheck [--no-smart] [--model <name>] [--no-chat]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Load libraries (order matters) ──────────────────────────
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/lib/detect.sh"
source "$SCRIPT_DIR/lib/ai.sh"

# ── Load collectors ──────────────────────────────────────────
source "$SCRIPT_DIR/collectors/storage.sh"
source "$SCRIPT_DIR/collectors/kernel.sh"
source "$SCRIPT_DIR/collectors/bootloader.sh"
source "$SCRIPT_DIR/collectors/compositor.sh"
source "$SCRIPT_DIR/collectors/packages.sh"

# ── Load analyzers ───────────────────────────────────────────
source "$SCRIPT_DIR/analyzers/analyze.sh"

# ── Parse CLI flags ──────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-smart)  SMART_ENABLED=false ;;
            --no-chat)   SKIP_CHAT=true ;;
            --model)     MODEL="$2"; shift ;;
            --help|-h)   usage ;;
        esac
        shift
    done
}

usage() {
    echo "Usage: sudo $0 [options]"
    echo "  --model <name>   Ollama model to use (default: llama3.2)"
    echo "  --no-smart       Skip SMART disk health checks"
    echo "  --no-chat        Skip interactive chat at the end"
    exit 0
}

# ── Main ─────────────────────────────────────────────────────
main() {
    parse_args "$@"
    mkdir -p "$LOG_DIR"

    clear
    ui_banner

    detect_all        # sets DISTRO, PKG_MGR, COMPOSITOR, BOOTLOADER, KERNEL_TYPE, ENV
    check_deps
    check_ollama

    # Run all collectors, tee output to log
    {
        collect_storage   # → DF_OUT, INODE_OUT, MOUNT_OUT, BLK_OUT, DU_OUT, FS_ERRORS, SWAP_OUT, SMART_OUT
        collect_kernel    # → KERNEL_OUT
        collect_bootloader # → BOOT_OUT
        collect_compositor # → COMPOSITOR_OUT
        collect_packages  # → PKG_OUT

        # AI analysis per section
        analyze_storage
        analyze_kernel
        analyze_bootloader
        analyze_compositor
        analyze_packages

        banner "AUDIT COMPLETE"
        echo "Report: $LOG_FILE"
    } 2>&1 | tee "$LOG_FILE"

    # Optional interactive chat
    ${SKIP_CHAT:-false} && exit 0
    echo ""
    read -rp "Start interactive chat? [Y/n]: " choice
    [[ "${choice,,}" =~ ^n ]] || interactive_chat
}

main "$@"
