# collectors/bootloader.sh — Detects and audits GRUB, systemd-boot, or rEFInd

collect_bootloader() {
    banner "BOOTLOADER  ($BOOTLOADER)"
    BOOT_OUT=""

    case "$BOOTLOADER" in
        grub)            _collect_grub ;;
        systemd-boot)    _collect_systemd_boot ;;
        refind)          _collect_refind ;;
        *)               warn "Unknown bootloader — skipping boot checks" ;;
    esac

    # EFI partition (critical for all bootloaders)
    echo ""
    echo "EFI / boot partition:"
    local efi
    efi=$(df -h /boot/efi /boot 2>/dev/null || df -h /boot 2>/dev/null || echo "not found")
    echo "$efi"
    BOOT_OUT+=" | EFI: $efi"
}

_collect_grub() {
    local cfg="/etc/default/grub"
    [ -f "$cfg" ] || { warn "$cfg not found"; return; }

    local conf
    conf=$(grep -E "^GRUB_DEFAULT|^GRUB_TIMEOUT|^GRUB_CMDLINE_LINUX|^GRUB_DISABLE_OS_PROBER" "$cfg")
    echo "$conf"
    BOOT_OUT="$conf"

    grep -q 'GRUB_TIMEOUT=0'             "$cfg" && warn "GRUB_TIMEOUT=0 — no time to select kernel"
    grep -q 'GRUB_DISABLE_OS_PROBER=true' "$cfg" && warn "OS prober disabled — dual boot won't detect other OSes"

    local entries
    entries=$(grep -c "menuentry " /boot/grub/grub.cfg 2>/dev/null || echo "?")
    echo "Menu entries: $entries"
}

_collect_systemd_boot() {
    echo "Loader entries:"
    ls /boot/loader/entries/ 2>/dev/null | sed 's/^/  /' || warn "No entries found"
    echo ""
    bootctl status 2>/dev/null | grep -E "Product|Version|Default|Timeout" | sed 's/^/  /' || true
    BOOT_OUT="systemd-boot entries: $(ls /boot/loader/entries/ 2>/dev/null | tr '\n' ' ')"
}

_collect_refind() {
    local cfg="/boot/EFI/refind/refind.conf"
    [ -f "$cfg" ] || cfg="/boot/refind_linux.conf"
    if [ -f "$cfg" ]; then
        echo "rEFInd config ($cfg):"
        grep -v "^#" "$cfg" | grep -v "^$" | head -20 | sed 's/^/  /'
        BOOT_OUT="refind config: $cfg"
    else
        warn "rEFInd config not found"
    fi
}
