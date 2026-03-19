# collectors/compositor.sh — Session health for any compositor or TTY

collect_compositor() {
    banner "COMPOSITOR  ($COMPOSITOR)"
    COMPOSITOR_OUT=""

    case "$COMPOSITOR" in
        hyprland)        _collect_hyprland ;;
        sway)            _collect_sway ;;
        wayfire)         _collect_wayfire ;;
        wayland-unknown) _collect_wayland_generic ;;
        x11-unknown|openbox|i3|bspwm|awesome) _collect_x11_generic ;;
        none)            info "Running from TTY — no compositor active" ; return ;;
        *)               info "Compositor: $COMPOSITOR — no specific checks implemented" ;;
    esac

    # GPU / DRM info (universal)
    echo ""
    echo "GPU:"
    lspci 2>/dev/null | grep -iE "vga|display|3d" | sed 's/^/  /' || info "lspci not available"

    # Journal errors for any compositor
    echo ""
    echo "Compositor journal errors (last 24h):"
    local errors
    errors=$(journalctl --no-pager --since "1 day ago" 2>/dev/null \
             | grep -iE "wayland|wlroots|drm|amdgpu|nvidia|radeon|i915" \
             | grep -iE "error|fail|crash" | tail -20 || true)
    if [ -n "$errors" ]; then
        warn "Errors found:"; echo "$errors"
        COMPOSITOR_OUT+=" | journal: $errors"
    else
        ok "No GPU/compositor errors in journal"
    fi
}

_collect_hyprland() {
    local log_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr"
    local log
    log=$(ls -t "$log_dir"/*/hyprland.log 2>/dev/null | head -1 || true)
    if [ -n "$log" ]; then
        echo "Log: $log"
        local errs
        errs=$(grep -iE "error|warn|crash|segfault" "$log" 2>/dev/null | tail -20 || true)
        [ -n "$errs" ] && { warn "Hyprland errors:"; echo "$errs"; COMPOSITOR_OUT="$errs"; } \
                       || ok "No errors in Hyprland log"
    else
        info "No Hyprland log (normal from TTY)"
    fi
}

_collect_sway() {
    local log
    log=$(journalctl --user -u sway --no-pager --since "1 day ago" 2>/dev/null \
          | grep -iE "error|warn|crash" | tail -20 || true)
    [ -n "$log" ] && { warn "Sway errors:"; echo "$log"; COMPOSITOR_OUT="$log"; } \
                  || ok "No errors in Sway journal"
}

_collect_wayfire() {
    local log="${HOME}/.local/share/wayfire.log"
    [ -f "$log" ] && tail -30 "$log" || info "No Wayfire log found"
}

_collect_wayland_generic() {
    ok "Wayland session active (compositor: unknown)"
    info "Set WAYLAND_DEBUG=1 to capture debug output if needed"
}

_collect_x11_generic() {
    echo "X11 session — Xorg log:"
    local xlog="/var/log/Xorg.0.log"
    [ -f "$xlog" ] \
        && grep -E "^\(EE\)|\(WW\)" "$xlog" | tail -20 \
        || info "Xorg log not found"
}
