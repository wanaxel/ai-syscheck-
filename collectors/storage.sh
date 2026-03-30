# collectors/storage.sh — Disk usage, mounts, SMART, inodes, swap

# Scans top-level dirs individually instead of crawling all of /
# Avoids hangs on large drives, network mounts, or permission walls
_du_safe() {
    local dirs=()
    for d in /home /var /usr /opt /tmp /root /srv /snap /flatpak; do
        [ -d "$d" ] && dirs+=("$d")
    done
    # timeout 20 hard cap — never hangs longer than this
    timeout 20 du -sh "${dirs[@]}" 2>/dev/null | sort -rh | head -"$TOP_N_DIRS" || true
}

collect_storage() {
    banner "STORAGE"

    # ── Disk usage ──────────────────────────────────────────
    DF_OUT=$(df -h --output=source,fstype,size,used,avail,pcent,target \
             -x tmpfs -x devtmpfs -x squashfs 2>/dev/null || df -h)
    echo "$DF_OUT"

    # ── Inodes ──────────────────────────────────────────────
    INODE_OUT=$(df -i -x tmpfs -x devtmpfs -x squashfs 2>/dev/null \
                | awk 'NR==1 || $5+0 > 70')
    [ -n "$INODE_OUT" ] && { echo ""; echo "Inode usage (>70%):"; echo "$INODE_OUT"; }

    # ── Mounts ──────────────────────────────────────────────
    MOUNT_OUT=$(findmnt -t ext4,ext3,ext2,btrfs,xfs,f2fs,ntfs,vfat,exfat \
                --real -o TARGET,SOURCE,FSTYPE,SIZE,AVAIL,USE% 2>/dev/null \
                || mount | grep -E 'ext|btrfs|xfs|ntfs|vfat')
    echo ""; echo "Mounts:"; echo "$MOUNT_OUT"

    # ── Block devices ────────────────────────────────────────
    BLK_OUT=$(lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINT,MODEL 2>/dev/null || lsblk)
    echo ""; echo "Block devices:"; echo "$BLK_OUT"

    # ── Top dirs — skip deep scan if disk critically full ────
    local root_pct
    root_pct=$(df / 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}')

    echo ""; echo "Largest dirs (top-level scan):"
    if [ "${root_pct:-0}" -ge 95 ]; then
        warn "Disk over 95% full — skipping du scan to avoid hang"
        DU_OUT="Disk critically full (${root_pct}%) — skipped du scan"
        echo "$DU_OUT"
    else
        DU_OUT=$(_du_safe)
        echo "$DU_OUT"

        echo ""; echo "/var breakdown:"
        timeout 15 du -sh /var/* 2>/dev/null | sort -rh | head -10 || true

        echo ""; echo "/home breakdown:"
        timeout 15 du -sh /home/* 2>/dev/null | sort -rh | head -10 || true
    fi

    # ── Filesystem errors ────────────────────────────────────
    FS_ERRORS=$(journalctl -p err..emerg --no-pager --since "7 days ago" 2>/dev/null \
                | grep -iE "i/o error|ext4|btrfs|xfs|corruption|bad block" | tail -30 \
                || dmesg | grep -iE "error|fail|i/o|corrupt" | tail -30 || true)
    if [ -z "$FS_ERRORS" ]; then
        ok "No filesystem errors in journal"
        FS_ERRORS="none"
    else
        warn "Filesystem errors found!"; echo "$FS_ERRORS"
    fi

    # ── Swap ─────────────────────────────────────────────────
    SWAP_OUT=$(swapon --show 2>/dev/null || cat /proc/swaps)
    echo ""; echo "Swap:"; echo "$SWAP_OUT"

    _collect_smart
}

_collect_smart() {
    $SMART_ENABLED || return

    # Skip virtual/RAM devices (zram, loop, sr)
    local disks
    disks=$(lsblk -d -o NAME,TYPE,TRAN 2>/dev/null \
            | awk '$2=="disk" && $1!~/^zram|^loop/ {print "/dev/"$1}')

    [ -z "$disks" ] && { info "No physical disks found for SMART"; return; }

    echo ""; echo "SMART health:"
    SMART_OUT=""
    for disk in $disks; do
        echo "  $disk"
        local result
        result=$(timeout 10 smartctl -H "$disk" 2>&1 || true)
        echo "  $result"
        SMART_OUT+="$disk: $result | "
        timeout 10 smartctl -A "$disk" 2>/dev/null \
            | grep -E "Reallocated|Pending|Uncorrectable|Wear_Leveling|Power_On" \
            | sed 's/^/  /' || true
    done
}
