# analyzers/analyze.sh — AI analysis calls, one per collected section

analyze_storage() {
    ai_section "Storage & Space" \
        "$DF_OUT
Inodes: $INODE_OUT
Mounts: $MOUNT_OUT
FS errors: ${FS_ERRORS:-none}
SMART: ${SMART_OUT:-not collected}" \
        "Is storage healthy? What should be cleaned? Are there errors needing a fix?"
}

analyze_kernel() {
    ai_section "Kernel" \
        "$KERNEL_OUT" \
        "Is the kernel healthy and well configured for this desktop setup? Suggest cmdline tweaks if useful."
}

analyze_bootloader() {
    ai_section "Bootloader" \
        "$BOOT_OUT" \
        "Is the bootloader configured safely? Any risks or misconfigurations?"
}

analyze_compositor() {
    ai_section "Compositor / GPU" \
        "$COMPOSITOR_OUT" \
        "Are there compositor or GPU errors? What could cause a crash to TTY and how to fix it?"
}

analyze_packages() {
    ai_section "Package Cache" \
        "$PKG_OUT" \
        "How much space can be reclaimed? Give exact cleanup commands for $PKG_MGR."
}
