# collectors/storage.sh — Disk usage, mounts, SMART, inodes, swap

collect_storage() {
    banner "STORAGE"

    DF_OUT=$(df -h --output=source,fstype,size,used,avail,pcent,target \
             -x tmpfs -x devtmpfs -x squashfs 2>/dev/null || df -h)
    echo "$DF_OUT"

    INODE_OUT=$(df -i -x tmpfs -x devtmpfs -x squashfs 2>/dev/null \
                | awk 'NR==1 || $5+0 > 70')
    [ -n "$INODE_OUT" ] && { echo ""; echo "Inode usage (>70%):"; echo "$INODE_OUT"; }

    MOUNT_OUT=$(findmnt -t ext4,ext3,ext2,btrfs,xfs,f2fs,ntfs,vfat,exfat \
                --real -o TARGET,SOURCE,FSTYPE,SIZE,AVAIL,USE% 2>/dev/null \
                || mount | grep -E 'ext|btrfs|xfs|ntfs|vfat')
    echo ""; echo "Mounts:"; echo "$MOUNT_OUT"

    BLK_OUT=$(lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINT,MODEL 2>/dev/null || lsblk)
    echo ""; echo "Block devices:"; echo "$BLK_OUT"

    DU_OUT=$(sudo du -Sh / \
             --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run \
             2>/dev/null | sort -rh | head -"$TOP_N_DIRS" \
             || du -sh /home /var /usr /opt /tmp 2>/dev/null | sort -rh)
    echo ""; echo "Top $TOP_N_DIRS largest dirs:"; echo "$DU_OUT"

    FS_ERRORS=$(journalctl -p err..emerg --no-pager --since "7 days ago" 2>/dev/null \
                | grep -iE "i/o error|ext4|btrfs|xfs|corruption|bad block" | tail -30 \
                || dmesg | grep -iE "error|fail|i/o|corrupt" | tail -30 || true)
    if [ -z "$FS_ERRORS" ]; then
        ok "No filesystem errors in journal"
        FS_ERRORS="none"
    else
        warn "Filesystem errors found!"; echo "$FS_ERRORS"
    fi

    SWAP_OUT=$(swapon --show 2>/dev/null || cat /proc/swaps)
    echo ""; echo "Swap:"; echo "$SWAP_OUT"

    _collect_smart
}

_collect_smart() {
    $SMART_ENABLED || return
    echo ""; echo "SMART health:"
    SMART_OUT=""
    local disks
    disks=$(lsblk -d -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}')
    for disk in $disks; do
        echo "  $disk"
        local result
        result=$(sudo smartctl -H "$disk" 2>&1 || true)
        echo "  $result"
        SMART_OUT+="$disk: $result | "
        sudo smartctl -A "$disk" 2>/dev/null \
            | grep -E "Reallocated|Pending|Uncorrectable|Wear_Leveling|Power_On" \
            | sed 's/^/  /' || true
    done
}
