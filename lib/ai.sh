# lib/ai.sh — Ollama wrapper with auto coding-model selection
#
# Model tier table (best coding models as of 2025, ranked by quality):
#
#  VRAM/RAM  | Model               | Why
#  ----------|---------------------|-------------------------------
#  24 GB+    | qwen2.5-coder:32b   | Best single-GPU coding model
#  16 GB+    | qwen2.5-coder:14b   | Strong, fits most mid-range GPUs
#  8 GB+     | qwen2.5-coder:7b    | Great quality/speed balance
#  <8 GB     | qwen2.5-coder:3b    | Lightweight fallback
#
# Override anytime: AI_MODEL=deepseek-r1:14b sudo ai-syscheck

# ── Hardware detection ────────────────────────────────────────

_get_vram_mb() {
    # Try nvidia first, then AMD, then Intel, then give up
    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null \
            | head -1 | tr -d ' '
        return
    fi

    if command -v rocm-smi &>/dev/null; then
        rocm-smi --showmeminfo vram 2>/dev/null \
            | awk '/Total Memory/{gsub(/[^0-9]/,"",$NF); print int($NF/1024)}' \
            | head -1
        return
    fi

    # DRM sysfs fallback (works for Intel/AMD without rocm-smi)
    local vram
    vram=$(cat /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null \
           | awk '{sum+=$1} END{print int(sum/1048576)}')
    [ -n "$vram" ] && [ "$vram" -gt 0 ] && echo "$vram" && return

    echo "0"
}

_get_ram_gb() {
    awk '/MemTotal/{print int($2/1024/1024)}' /proc/meminfo 2>/dev/null || echo "0"
}

# ── Model auto-selection ──────────────────────────────────────

select_model() {
    # If user already set AI_MODEL, respect it
    [ -n "${AI_MODEL:-}" ] && { MODEL="$AI_MODEL"; return; }

    local vram_mb ram_gb
    vram_mb=$(_get_vram_mb)
    ram_gb=$(_get_ram_gb)

    # Use VRAM if detected, else estimate from RAM (CPU inference fallback)
    local effective_mb="$vram_mb"
    [ "$vram_mb" -eq 0 ] && effective_mb=$(( ram_gb * 512 ))

    if   [ "$effective_mb" -ge 22000 ]; then MODEL="qwen2.5-coder:32b"
    elif [ "$effective_mb" -ge 14000 ]; then MODEL="qwen2.5-coder:14b"
    elif [ "$effective_mb" -ge  7000 ]; then MODEL="qwen2.5-coder:7b"
    else                                     MODEL="qwen2.5-coder:3b"
    fi

    info "Hardware  : ${vram_mb}MB VRAM  /  ${ram_gb}GB RAM"
    info "Model     : $MODEL  (auto-selected)"
}

# ── Ollama setup ──────────────────────────────────────────────

check_ollama() {
    if ! curl -sf "$OLLAMA_URL/api/tags" &>/dev/null; then
        err "Ollama not running. Start with: ollama serve"
        exit 1
    fi

    select_model

    if ! ollama list 2>/dev/null | grep -q "^${MODEL}"; then
        warn "Model '$MODEL' not found locally — pulling now..."
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
    curl -sf "$OLLAMA_URL/api/generate" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg m "$MODEL" --arg p "$1" \
            '{model:$m, prompt:$p, stream:false}')" \
        | jq -r '.response // "No response from model"'
}

# ── Per-section analysis ──────────────────────────────────────

ai_section() {
    local title="$1" data="$2" question="$3"
    banner "AI ▸ $title"
    echo -e "${YELLOW}[$MODEL] Thinking...${RESET}"
    ask_ai "You are a Linux sysadmin expert.
System: distro=$DISTRO  pkg_mgr=$PKG_MGR  compositor=$COMPOSITOR  bootloader=$BOOTLOADER  kernel=$KERNEL_TYPE

Data:
$data

Task: $question

Rules: be concise, use bullet points, give exact shell commands with the correct package manager for this distro."
    echo ""
}

# ── Interactive post-audit chat ───────────────────────────────

interactive_chat() {
    banner "CHAT  (type 'exit' to quit)"
    info "Model: $MODEL"
    echo ""

    local ctx="You are a Linux sysadmin expert.
System: distro=$DISTRO  pkg=$PKG_MGR  compositor=$COMPOSITOR  bootloader=$BOOTLOADER  kernel=$KERNEL_TYPE  env=$ENV

Audit summary:
- Disk:      $DF_OUT
- Big dirs:  $DU_OUT
- Devices:   $BLK_OUT
- FS errors: ${FS_ERRORS:-none}

Answer concisely. Give exact commands. Use $PKG_MGR for packages."

    while true; do
        echo -en "${BOLD}you> ${RESET}"
        read -r input
        [[ "$input" =~ ^(exit|quit)$ ]] && break
        [ -z "$input" ] && continue
        echo -e "${CYAN}ai>${RESET}"
        ask_ai "$ctx

User: $input"
        echo ""
    done
}
