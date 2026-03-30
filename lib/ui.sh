# lib/ui.sh — Terminal output helpers + result card formatter

if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ] && [ "${NO_COLOR:-}" = "" ]; then
    RED=$(printf '\033[0;31m');    YELLOW=$(printf '\033[1;33m')
    GREEN=$(printf '\033[0;32m');  CYAN=$(printf '\033[0;36m')
    BLUE=$(printf '\033[0;34m');   BOLD=$(printf '\033[1m')
    DIM=$(printf '\033[2m');       RESET=$(printf '\033[0m')
else
    RED=''; YELLOW=''; GREEN=''; CYAN=''; BLUE=''; BOLD=''; DIM=''; RESET=''
fi

# ── Helpers ───────────────────────────────────────────────────
banner()  { printf '\n%s══ %s ══%s\n' "$BOLD$CYAN" "$1" "$RESET"; }
ok()      { printf '%s ✔%s  %s\n'    "$GREEN" "$RESET" "$1"; }
warn()    { printf '%s ⚠%s  %s\n'    "$YELLOW" "$RESET" "$1"; }
err()     { printf '%s ✖%s  %s\n'    "$RED" "$RESET" "$1"; }
info()    { printf '%s   %s%s\n'      "$DIM" "$1" "$RESET"; }

# Strip ANSI codes to get the visible length of a string
_visible_len() { printf '%s' "$1" | sed 's/\033\[[0-9;]*m//g' | wc -c; }

# ── Box drawing ───────────────────────────────────────────────
_hline() { local w="$1" s=""; printf -v s '%*s' "$w" ''; printf '%s' "${s// /─}"; }

box_top() {
    local width="${1:-64}" title="$2"
    local inner=$(( width - 2 ))
    local tlen; tlen=$(_visible_len "$title")
    local pad=$(( (inner - tlen) / 2 ))
    local rpad=$(( inner - tlen - pad ))
    local h; h=$(_hline "$inner")
    printf '%s┌%s┐%s\n' "$BOLD$BLUE" "$h" "$RESET"
    printf '%s│%s%*s%s%*s%s%s│%s\n' \
        "$BOLD$BLUE" "$RESET" \
        "$pad" "" \
        "$title" \
        "$rpad" "" \
        "$RESET" "$BOLD$BLUE" "$RESET"
    printf '%s├%s┤%s\n' "$BOLD$BLUE" "$h" "$RESET"
}

box_divider() {
    local width="${1:-64}"
    local h; h=$(_hline $(( width - 2 )))
    printf '%s├%s┤%s\n' "$BOLD$BLUE" "$h" "$RESET"
}

box_bottom() {
    local width="${1:-64}"
    local h; h=$(_hline $(( width - 2 )))
    printf '%s└%s┘%s\n' "$BOLD$BLUE" "$h" "$RESET"
}

# box_line <width> <text>
# Measures visible length (strips ANSI) so padding is always correct
box_line() {
    local width="${1:-64}" text="$2"
    local inner=$(( width - 4 ))  # 2 borders + 2 spaces padding
    local vlen; vlen=$(_visible_len "$text")
    local pad=$(( inner - vlen ))
    [ "$pad" -lt 0 ] && pad=0
    printf '%s│%s %s%*s %s│%s\n' \
        "$BOLD$BLUE" "$RESET" \
        "$text" "$pad" "" \
        "$BOLD$BLUE" "$RESET"
}

box_empty() { box_line "${1:-64}" ""; }

# _wrap_into_box <width> <indent> <text>
# Word-wraps text into box_line calls with a given indent
_wrap_into_box() {
    local width="$1" indent="$2" text="$3"
    local max=$(( width - 4 - ${#indent} - 1 ))
    local line="" word
    for word in $text; do
        if [ $(( ${#line} + ${#word} + 1 )) -gt "$max" ]; then
            box_line "$width" "${indent}${line}"
            line="$word"
        else
            [ -n "$line" ] && line="$line $word" || line="$word"
        fi
    done
    [ -n "$line" ] && box_line "$width" "${indent}${line}"
}

# ── Result card ───────────────────────────────────────────────
print_result_card() {
    local title="$1" status="$2" summary="$3" steps="$4"
    local width=64

    local icon color
    case "$status" in
        ok)   icon="✔  HEALTHY";  color="$GREEN" ;;
        warn) icon="⚠  WARNING";  color="$YELLOW" ;;
        err)  icon="✖  CRITICAL"; color="$RED" ;;
        *)    icon="•  INFO";     color="$CYAN" ;;
    esac

    printf '\n'
    box_top $width "  $title  "
    box_empty $width
    box_line  $width "  Status    ${color}${BOLD}${icon}${RESET}"
    box_empty $width

    box_divider $width
    box_line    $width "  ${BOLD}Summary${RESET}"
    box_empty   $width
    _wrap_into_box $width "    " "$summary"
    box_empty $width

    if [ -n "$steps" ]; then
        box_divider $width
        box_line    $width "  ${BOLD}Steps to take${RESET}"
        box_empty   $width
        local i=1
        while IFS= read -r step; do
            [ -z "$step" ] && continue
            # Render step number then wrap continuation lines with indent
            local prefix="${CYAN}${i}.${RESET} "
            local plen=$(( ${#i} + 2 ))   # visible: "N. "
            local max=$(( width - 4 - 4 - plen ))  # 4=borders+pad, 4=leading spaces
            if [ "${#step}" -le "$max" ]; then
                box_line $width "    ${CYAN}${i}.${RESET} ${step}"
            else
                local first=true word="" line=""
                for word in $step; do
                    if [ $(( ${#line} + ${#word} + 1 )) -gt "$max" ]; then
                        if $first; then
                            box_line $width "    ${CYAN}${i}.${RESET} ${line}"
                            first=false
                        else
                            box_line $width "       ${line}"
                        fi
                        line="$word"
                    else
                        [ -n "$line" ] && line="$line $word" || line="$word"
                    fi
                done
                [ -n "$line" ] && {
                    $first && box_line $width "    ${CYAN}${i}.${RESET} ${line}" \
                           || box_line $width "       ${line}"
                }
            fi
            (( i++ ))
        done <<< "$steps"
        box_empty $width
    fi

    box_bottom $width
}

# ── Startup banner ────────────────────────────────────────────
ui_banner() {
    local width=64
    printf '\n'
    box_top    $width "  ai-syscheck  •  local AI audit  "
    box_empty  $width
    box_line   $width "  Model   : ${CYAN}${MODEL}${RESET}"
    box_line   $width "  Log     : ${DIM}${LOG_FILE}${RESET}"
    box_empty  $width
    box_bottom $width
    printf '\n'
}
