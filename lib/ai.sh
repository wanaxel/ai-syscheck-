# lib/ai.sh — Ollama wrapper, model selector, structured output renderer

# ── Hardware detection ────────────────────────────────────────

_get_vram_mb() {
    if command -v nvidia-smi &>/dev/null; then
        local v
        v=$(nvidia-smi --query-gpu=memory.total \
            --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' \n')
        [ "${v:-0}" -gt 0 ] 2>/dev/null && echo "$v" && return
    fi

    if command -v rocm-smi &>/dev/null; then
        local v
        v=$(rocm-smi --showmeminfo vram 2>/dev/null \
            | awk '/Total Memory/{gsub(/[^0-9]/,"",$NF); print int($NF/1024)}' | head -1)
        [ "${v:-0}" -gt 0 ] 2>/dev/null && echo "$v" && return
    fi

    local total=0
    for f in /sys/class/drm/card*/device/mem_info_vram_total; do
        [ -f "$f" ] || continue
        local v; v=$(timeout 2 cat "$f" 2>/dev/null || echo 0)
        total=$(( total + v ))
    done
    [ "$total" -gt 0 ] 2>/dev/null && echo $(( total / 1048576 )) && return

    echo "0"
}

_get_ram_gb() {
    awk '/MemTotal/{print int($2/1024/1024)}' /proc/meminfo 2>/dev/null || echo "0"
}

# ── Model auto-selection ──────────────────────────────────────

select_model() {
    [ -n "${AI_MODEL:-}" ] && { MODEL="$AI_MODEL"; return; }

    local vram_mb ram_gb
    vram_mb=$(_get_vram_mb)
    ram_gb=$(_get_ram_gb)

    local effective=$(( vram_mb > 0 ? vram_mb : ram_gb * 614 ))

    if   [ "$effective" -ge 22000 ]; then MODEL="qwen2.5-coder:32b"
    elif [ "$effective" -ge 14000 ]; then MODEL="qwen2.5-coder:14b"
    elif [ "$effective" -ge  7000 ]; then MODEL="qwen2.5-coder:7b"
    else                                  MODEL="qwen2.5-coder:3b"
    fi

    info "Hardware  : ${vram_mb}MB VRAM  /  ${ram_gb}GB RAM"
    info "Model     : $MODEL  (auto-selected)"
}

# ── Ollama setup ──────────────────────────────────────────────

check_ollama() {
    if ! curl -sf --max-time 3 "$OLLAMA_URL/api/tags" &>/dev/null; then
        err "Ollama not running. Start with: ollama serve"
        exit 1
    fi

    select_model

    if ! ollama list 2>/dev/null | grep -q "^${MODEL}"; then
        warn "Model '$MODEL' not pulling now..."
        ollama pull "$MODEL" || {
            warn "Pull failed — falling back to qwen2.5-coder:3b"
            MODEL="qwen2.5-coder:3b"
            ollama pull "$MODEL"
        }
    fi

    ok "Ollama ready  →  $MODEL"
}

# ── Core API call ─────────────────────────────────────────────

ask_ai() {
    local payload
    payload=$(jq -n \
        --arg m "$MODEL" \
        --arg p "$1" \
        --argjson opts '{"num_predict":200,"temperature":0.1}' \
        '{model:$m, prompt:$p, stream:false, options:$opts}')
    curl -sf --max-time 60 "$OLLAMA_URL/api/generate" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        | jq -r '.response // "No response from model"'
}

# Strip markdown: bold, italic, backticks, code fences
_strip_md() {
    sed 's/\*\*//g; s/\*//g; s/`//g; s/```[a-z]*//g; s/```//g' <<< "$1"
}

# ── Structured section analysis ───────────────────────────────

ai_section() {
    local title="$1" data="$2" question="$3"

    banner "Analysing: $title"

    # Very explicit format instruction — reduces model going off-script
    local prompt
    prompt="You are a Linux sysadmin. Analyze the data and answer the question.

System: distro=$DISTRO pkg=$PKG_MGR compositor=$COMPOSITOR bootloader=$BOOTLOADER kernel=$KERNEL_TYPE

Data:
$data

Question: $question

YOU MUST reply using ONLY this exact format. No markdown. No extra text. No code blocks.

STATUS: (write exactly one word: ok, warn, or err)
SUMMARY: (one sentence describing the current state, plain text only)
STEPS:
- exact shell command here  # brief explanation of what it does
- exact shell command here  # brief explanation of what it does
- exact shell command here  # brief explanation of what it does

Rules for STEPS:
- Each step must be a real shell command the user can copy and run
- After the command write two spaces then a hash then a short explanation
- If nothing needs to be done write: - No action needed
- Maximum 4 steps
- Use $PKG_MGR syntax for package commands
- No markdown, no backticks, no bold"

    local raw
    raw=$(ask_ai "$prompt")

    # Parse each field
    local status summary steps

    status=$( printf '%s' "$raw" | grep -m1 '^STATUS:'  | sed 's/^STATUS:[[:space:]]*//' | tr -d '[:space:]')
    summary=$(printf '%s' "$raw" | grep -m1 '^SUMMARY:' | sed 's/^SUMMARY:[[:space:]]*//')
    steps=$(  printf '%s' "$raw" | awk '/^STEPS:/{found=1;next} found && /^- /{print substr($0,3)}')

    summary=$(_strip_md "$summary")

    case "$status" in
        ok|warn|err) ;;
        *) status="info" ;;
    esac

    if [ -z "$summary" ]; then
        summary=$(printf '%s' "$raw" | head -3 | tr '\n' ' ')
        summary=$(_strip_md "$summary")
        steps=""
    fi

    print_result_card "$title" "$status" "$summary" "$steps"
}

# ── Interactive chat ──────────────────────────────────────────

interactive_chat() {
    banner "CHAT  (type 'exit' to quit)"
    info "Model: $MODEL"
    printf '\n'

    local ctx="You are a Linux sysadmin expert.
System: distro=$DISTRO pkg=$PKG_MGR compositor=$COMPOSITOR bootloader=$BOOTLOADER kernel=$KERNEL_TYPE env=$ENV

Audit summary:
- Disk:      $DF_OUT
- Big dirs:  $DU_OUT
- Devices:   $BLK_OUT
- FS errors: ${FS_ERRORS:-none}

Keep answers short. No markdown. Use $PKG_MGR for packages."

    while true; do
        printf '\n%syou>%s ' "$BOLD" "$RESET"
        read -r input
        [[ "$input" =~ ^(exit|quit)$ ]] && break
        [ -z "$input" ] && continue
        printf '\n%s' "$CYAN"
        ask_ai "$ctx

User: $input" | sed 's/\*\*//g; s/\*//g; s/`//g'
        printf '%s\n' "$RESET"
    done
}
