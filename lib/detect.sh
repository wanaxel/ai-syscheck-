# lib/detect.sh — Auto-detect system stack (distro, compositor, bootloader, kernel)

detect_distro() {
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        DISTRO="${ID:-unknown}"
    else
        DISTRO="unknown"
    fi

    case "$DISTRO" in
        arch|manjaro|endeavouros|garuda|cachyos)  PKG_MGR="pacman" ;;
        ubuntu|debian|linuxmint|pop)              PKG_MGR="apt" ;;
        fedora|rhel|centos|almalinux|rocky)       PKG_MGR="dnf" ;;
        opensuse*|sles)                           PKG_MGR="zypper" ;;
        void)                                     PKG_MGR="xbps" ;;
        nixos)                                    PKG_MGR="nix" ;;
        *)                                        PKG_MGR="unknown" ;;
    esac
}

detect_compositor() {
    # Check env vars first (works without sudo).
    # Fall back to pgrep (works with sudo, which strips the user env).
    if   [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || pgrep -x Hyprland   &>/dev/null; then
        COMPOSITOR="hyprland"
    elif [ -n "${SWAYSOCK:-}" ]                    || pgrep -x sway        &>/dev/null; then
        COMPOSITOR="sway"
    elif [ -n "${WAYFIRE_CONFIG_FILE:-}" ]         || pgrep -x wayfire     &>/dev/null; then
        COMPOSITOR="wayfire"
    elif pgrep -x kwin_wayland &>/dev/null; then
        COMPOSITOR="kwin"
    elif pgrep -x mutter       &>/dev/null; then
        COMPOSITOR="gnome"
    elif [ -n "${WAYLAND_DISPLAY:-}" ]; then
        COMPOSITOR="wayland-unknown"
    elif [ -n "${DISPLAY:-}" ]; then
        if   pgrep -x i3      &>/dev/null; then COMPOSITOR="i3"
        elif pgrep -x bspwm   &>/dev/null; then COMPOSITOR="bspwm"
        elif pgrep -x openbox &>/dev/null; then COMPOSITOR="openbox"
        elif pgrep -x awesome &>/dev/null; then COMPOSITOR="awesome"
        elif pgrep -x xfwm4   &>/dev/null; then COMPOSITOR="xfwm4"
        else COMPOSITOR="x11-unknown"
        fi
    else
        COMPOSITOR="none"
    fi
}

detect_env() {
    # Same issue with sudo — check process list as fallback
    if pgrep -x Hyprland &>/dev/null || pgrep -x sway &>/dev/null \
        || pgrep -x wayfire &>/dev/null || pgrep -x kwin_wayland &>/dev/null; then
        ENV="wayland"
    elif [ -n "${WAYLAND_DISPLAY:-}" ]; then
        ENV="wayland"
    elif [ -n "${DISPLAY:-}" ]; then
        ENV="x11"
    else
        ENV="tty"
    fi
}

detect_bootloader() {
    if [ -d /boot/grub ] || [ -d /boot/grub2 ]; then
        BOOTLOADER="grub"
    elif [ -d /boot/loader ]; then
        BOOTLOADER="systemd-boot"
    elif command -v refind-install &>/dev/null || [ -d /boot/EFI/refind ]; then
        BOOTLOADER="refind"
    else
        BOOTLOADER="unknown"
    fi
}

detect_kernel() {
    local kver
    kver=$(uname -r)
    case "$kver" in
        *zen*)      KERNEL_TYPE="zen" ;;
        *lts*)      KERNEL_TYPE="lts" ;;
        *hardened*) KERNEL_TYPE="hardened" ;;
        *rt*)       KERNEL_TYPE="realtime" ;;
        *cachyos*)  KERNEL_TYPE="cachyos" ;;
        *xanmod*)   KERNEL_TYPE="xanmod" ;;
        *)          KERNEL_TYPE="mainline" ;;
    esac
}

detect_all() {
    detect_distro
    detect_compositor
    detect_bootloader
    detect_kernel
    detect_env

    banner "DETECTED STACK"
    info "Distro      : $DISTRO ($PKG_MGR)"
    info "Compositor  : $COMPOSITOR"
    info "Bootloader  : $BOOTLOADER"
    info "Kernel      : $(uname -r) [$KERNEL_TYPE]"
    info "Environment : $ENV"
    printf '\n'
}

check_deps() {
    local missing=()
    for cmd in ollama df du lsblk findmnt jq curl; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done

    $SMART_ENABLED && {
        command -v smartctl &>/dev/null \
            || { warn "smartmontools not found — SMART checks disabled"; SMART_ENABLED=false; }
    }

    if [ ${#missing[@]} -gt 0 ]; then
        err "Missing: ${missing[*]}"
        case "$PKG_MGR" in
            pacman) echo "Fix: sudo pacman -S ${missing[*]}" ;;
            apt)    echo "Fix: sudo apt install ${missing[*]}" ;;
            dnf)    echo "Fix: sudo dnf install ${missing[*]}" ;;
            zypper) echo "Fix: sudo zypper install ${missing[*]}" ;;
            *)      echo "Please install: ${missing[*]}" ;;
        esac
        exit 1
    fi
}
