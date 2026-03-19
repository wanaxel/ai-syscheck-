# collectors/kernel.sh — Kernel info, cmdline, installed kernels

collect_kernel() {
    banner "KERNEL"
    local kver
    kver=$(uname -r)
    echo "Running : $kver  [$KERNEL_TYPE]"

    # List installed kernels via detected package manager
    echo "Installed kernels:"
    case "$PKG_MGR" in
        pacman) pacman -Q 2>/dev/null \
                    | grep -E "^linux(-zen|-lts|-hardened|-rt|-mainline|-cachyos|-xanmod)? " \
                    || echo "  (none found via pacman)" ;;
        apt)    dpkg -l 'linux-image-*' 2>/dev/null | grep '^ii' | awk '{print "  "$2}' \
                    || echo "  (none found via dpkg)" ;;
        dnf)    rpm -q kernel 2>/dev/null | sed 's/^/  /' || echo "  (none found)" ;;
        *)      ls /boot/vmlinuz* 2>/dev/null | sed 's/^/  /' || echo "  (check /boot manually)" ;;
    esac

    echo ""
    echo "Cmdline : $(cat /proc/cmdline)"

    KERNEL_OUT="kernel=$kver type=$KERNEL_TYPE cmdline=$(cat /proc/cmdline)"
}
