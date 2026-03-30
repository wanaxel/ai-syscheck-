# analyzers/analyze.sh — AI analysis calls, one per collected section

# _trim <var> — truncate to first 800 chars to keep prompt size sane
_trim() { printf '%s' "${1:-none}" | head -c 800; }

analyze_storage() {
    ai_section "Storage & Space" \
        "$(_trim "$DF_OUT")
Inodes: $(_trim "$INODE_OUT")
FS errors: $(_trim "${FS_ERRORS:-none}")" \
        "Is storage healthy? What needs cleaning? Any errors?"
}

analyze_kernel() {
    ai_section "Kernel" \
        "$(_trim "$KERNEL_OUT")" \
        "Is the kernel healthy? Suggest any useful cmdline tweaks."
}

analyze_bootloader() {
    ai_section "Bootloader" \
        "$(_trim "$BOOT_OUT")" \
        "Is the bootloader configured safely? Any risks?"
}

analyze_compositor() {
    ai_section "Compositor / GPU" \
        "$(_trim "$COMPOSITOR_OUT")" \
        "Any compositor or GPU errors? What could cause a crash to TTY?"
}

analyze_packages() {
    ai_section "Package Cache" \
        "$(_trim "$PKG_OUT")" \
        "How much space can be reclaimed? Give exact $PKG_MGR cleanup commands."
}
