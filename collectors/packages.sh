# collectors/packages.sh — Package cache size and orphans for any distro

collect_packages() {
    banner "PACKAGE CACHE"
    PKG_OUT=""

    case "$PKG_MGR" in
        pacman) _collect_pacman ;;
        apt)    _collect_apt ;;
        dnf)    _collect_dnf ;;
        zypper) _collect_zypper ;;
        nix)    _collect_nix ;;
        *)      info "Unknown package manager ($PKG_MGR) — skipping" ;;
    esac
}

_collect_pacman() {
    local cache_size
    cache_size=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1 || echo "unknown")
    echo "Cache size : $cache_size"

    local orphans
    orphans=$(pacman -Qtdq 2>/dev/null || true)
    echo "Orphans    : ${orphans:-none}"

    # AUR helper
    local aur_count=0
    if   command -v yay  &>/dev/null; then aur_count=$(yay  -Qm 2>/dev/null | wc -l)
    elif command -v paru &>/dev/null; then aur_count=$(paru -Qm 2>/dev/null | wc -l)
    fi
    echo "AUR pkgs   : $aur_count"

    PKG_OUT="pacman cache=$cache_size orphans=${orphans:-none} aur=$aur_count"
}

_collect_apt() {
    local cache_size
    cache_size=$(du -sh /var/cache/apt/archives/ 2>/dev/null | cut -f1 || echo "unknown")
    echo "Cache size : $cache_size"

    local autoremove
    autoremove=$(apt-get --dry-run autoremove 2>/dev/null | grep "^Remv" | wc -l || echo "0")
    echo "Autoremove : $autoremove packages"
    PKG_OUT="apt cache=$cache_size autoremovable=$autoremove"
}

_collect_dnf() {
    local cache_size
    cache_size=$(du -sh /var/cache/dnf/ 2>/dev/null | cut -f1 || echo "unknown")
    echo "Cache size : $cache_size"
    PKG_OUT="dnf cache=$cache_size"
}

_collect_zypper() {
    local cache_size
    cache_size=$(du -sh /var/cache/zypp/ 2>/dev/null | cut -f1 || echo "unknown")
    echo "Cache size : $cache_size"
    PKG_OUT="zypper cache=$cache_size"
}

_collect_nix() {
    echo "Nix store:"
    nix-store --gc --print-dead 2>/dev/null | wc -l | xargs -I{} echo "  {} dead store paths"
    du -sh /nix/store 2>/dev/null | sed 's/^/  /' || true
    PKG_OUT="nix store=$(du -sh /nix/store 2>/dev/null | cut -f1)"
}
