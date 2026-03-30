# collectors/compositor.sh — Session health for any compositor or TTY

collect_compositor() {
    banner "COMPOSITOR  ($COMPOSITOR)"
    COMPOSITOR_OUT=""

    case "$COMPOSITOR" in
        hyprland)        _collect_hyprland ;;
        sway)            _collect_sway ;;
        wayfire)         _collect_wayfire ;;
        wayland-unknown) ok "Wayland session active"; COMPOSITOR_OUT="Generic Wayland" ;;
        x11-unknown|openbox|i3|bspwm|awesome|xfwm4) _collect_x11_generic ;;
        gnome|kwin)      info "Compositor: $COMPOSITOR" ;;
        none)            info "TTY — no compositor active"; return ;;
        *)               info "Compositor: $COMPOSITOR" ;;
    esac

    # GPU info
    printf '\nGPU:\n'
    lspci 2>/dev/null | grep -iE "vga|display|3d" | sed 's/^/  /' \
        || info "lspci not available"

    # Journal errors — hard timeout + line cap to prevent hang
    printf '\nCompositor/GPU errors (last 24h):\n'
    local errors
    errors=$(timeout 10 journalctl -p err..emerg --no-pager \
             --since "1 day ago" --until "now" -n 100 2>/dev/null \
             | grep -iE "wayland|wlroots|drm|amdgpu|nvidia|radeon|i915|hyprland" \
             | tail -10 || true)
    if [ -n "$errors" ]; then
        warn "Errors found:"; printf '%s\n' "$errors"
        COMPOSITOR_OUT+=" | $errors"
    else
        ok "No GPU/compositor errors in journal"
        [ -z "$COMPOSITOR_OUT" ] && COMPOSITOR_OUT="No compositor or GPU errors"
    fi
}

_collect_hyprland() {
    local real_uid
    real_uid=$(id -u "${SUDO_USER:-$USER}" 2>/dev/null || echo "1000")
    local log_dir="/run/user/${real_uid}/hypr"

    local log
    log=$(ls -t "$log_dir"/*/hyprland.log 2>/dev/null | head -1 || true)

    if [ -n "$log" ]; then
        printf 'Log: %s\n' "$log"
        local errs
        errs=$(grep -iE "error|crash|segfault" "$log" 2>/dev/null | tail -15 || true)
        if [ -n "$errs" ]; then
            warn "Hyprland errors:"; printf '%s\n' "$errs"
            COMPOSITOR_OUT="$errs"
        else
            ok "No errors in Hyprland log"
            COMPOSITOR_OUT="No Hyprland errors"
        fi
    else
        info "No Hyprland log found (sudo strips XDG_RUNTIME_DIR)"
        COMPOSITOR_OUT="No Hyprland log accessible"
    fi
}

_collect_sway() {
    local log
    log=$(timeout 5 journalctl --user -u sway --no-pager \
          --since "1 day ago" -n 50 2>/dev/null \
          | grep -iE "error|warn|crash" | tail -10 || true)
    [ -n "$log" ] && { warn "Sway errors:"; printf '%s\n' "$log"; COMPOSITOR_OUT="$log"; } \
                  || { ok "No Sway errors"; COMPOSITOR_OUT="No Sway errors"; }
}

_collect_wayfire() {
    local log="${HOME}/.local/share/wayfire.log"
    [ -f "$log" ] && tail -20 "$log" || info "No Wayfire log found"
    COMPOSITOR_OUT="Wayfire log checked"
}

_collect_x11_generic() {
    local xlog="/var/log/Xorg.0.log"
    if [ -f "$xlog" ]; then
        printf 'Xorg errors:\n'
        grep -E "^\(EE\)" "$xlog" | tail -10 || ok "No Xorg errors"
        COMPOSITOR_OUT="X11 session, checked Xorg log"
    else
        info "Xorg log not found"
        COMPOSITOR_OUT="X11 session, no Xorg log"
    fi
}
