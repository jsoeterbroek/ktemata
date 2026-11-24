#!/usr/bin/env bash
# Ktemata offline AI, installed and configured separately from the library post-install.
#
# Installs Ollama, pulls a small local model and an embedding model, installs the ktemata-ai CLI,
# installs KiwixRAG (brunuff, https://github.com/brunuff/KiwixRAG) for ZIM retrieval,
# writes /etc/ktemata/ai.conf, and enables a timer that re-indexes the configured document roots
# (default: /var/lib/kiwix and /srv/kiwix/zim). Nothing is exposed on the network: Ollama stays on
# localhost and the CLI is local. The library admin can build ZIM indexes and call
# `ktemata-ai ask --json`.
#
#   sudo ./post-install-ai.sh --yes
#   sudo ./post-install-ai.sh --model llama3.2:1b --no-ingest
#   ./post-install-ai.sh --dry-run
#
# The model download is the long part (about 2 GB for llama3.2:3b and 274 MB for the embeddings).

set -euo pipefail

SCRIPT=$(basename "$0")
readonly SCRIPT
readonly SCRIPT_VERSION="0.1.0"

AI_MODEL=${AI_MODEL:-llama3.2:3b}
AI_EMBED_MODEL=${AI_EMBED_MODEL:-nomic-embed-text}
AI_OLLAMA_URL=${AI_OLLAMA_URL:-http://127.0.0.1:11434}
AI_INGEST_DIRS=${AI_INGEST_DIRS:-"/var/lib/kiwix /srv/kiwix/zim"}
AI_DB=${AI_DB:-/var/lib/ktemata-ai/index.sqlite3}
AI_CONFIG=/etc/ktemata/ai.conf
AI_CLI=/usr/local/bin/ktemata-ai
AI_SERVICE=ktemata-ai-ingest
ADMIN_SERVICE=ktemata-admin
AI_STATE_DIR=/var/lib/ktemata-ai
AI_PULL_TIMEOUT=7200
AI_KIWIXRAG_DIR=${AI_KIWIXRAG_DIR:-/opt/ktemata-ai/kiwixrag}
AI_KIWIXRAG_URL=${AI_KIWIXRAG_URL:-https://github.com/brunuff/KiwixRAG.git}
AI_KIWIXRAG_REF=${AI_KIWIXRAG_REF:-main}
AI_KIWIX_USER=${AI_KIWIX_USER:-ktemata}
AI_TORCH_INDEX=${AI_TORCH_INDEX:-https://download.pytorch.org/whl/cpu}
AI_TORCH_SPEC=${AI_TORCH_SPEC:-torch==2.15.0+cpu}
AI_ZIM_MODEL=${AI_ZIM_MODEL:-}
AI_ZIM_HOME=${AI_ZIM_HOME:-/srv/kiwix/zim}
AI_ZIM_TOP_K=${AI_ZIM_TOP_K:-6}

DRY_RUN=false
ASSUME_YES=false
NO_MODELS=false
NO_INGEST=false
NO_SERVICE=false
NO_UPDATE=false
WITH_KIWIXRAG=true
WITH_ZIM_INDEX=false
CONFIG_EXISTED=false

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RED=$'\e[31m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'
    C_BLUE=$'\e[36m'; C_BOLD=$'\e[1m'; C_OFF=$'\e[0m'
else
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_BOLD=""; C_OFF=""
fi

log_info()  { printf '%s•%s %s\n' "$C_BLUE" "$C_OFF" "$*"; }
log_ok()    { printf '%s✓%s %s\n' "$C_GREEN" "$C_OFF" "$*"; }
log_warn()  { printf '%s!%s %s\n' "$C_YELLOW" "$C_OFF" "$*" >&2; }
log_stage() { printf '\n%s%s==>%s %s\n' "$C_BOLD" "$C_BLUE" "$C_OFF" "$*"; }
die()       { printf '%s✗%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }

usage() {
    cat <<EOF
${C_BOLD}$SCRIPT $SCRIPT_VERSION${C_OFF} — Ktemata offline AI (Ollama + local index)

${C_BOLD}USAGE${C_OFF}
  [sudo] ./$SCRIPT [OPTION]...

${C_BOLD}OPTIONS${C_OFF}
  -y, --yes             Do not ask for confirmation.
  -n, --dry-run         Print commands, change nothing (no root needed).
      --model NAME      Generation model (default: $AI_MODEL).
      --embed-model N   Embedding model (default: $AI_EMBED_MODEL).
      --ollama-url URL  Ollama API (default: $AI_OLLAMA_URL).
      --ingest-dir DIR  Document root (repeatable; default: /var/lib/kiwix /srv/kiwix/zim).
      --db PATH         SQLite index (default: $AI_DB).
      --zim-model NAME  Generation model for ZIM questions (default: AI_MODEL).
      --zim-home DIR    ZIM directory (default: $AI_ZIM_HOME).
      --zim-top N       KiwixRAG chunks per ZIM question (default: $AI_ZIM_TOP_K).
      --kiwixrag-dir D  KiwixRAG checkout and venv (default: $AI_KIWIXRAG_DIR).
      --kiwix-user N    Owner of built ZIM indexes (default: $AI_KIWIX_USER).
      --no-kiwixrag     Do not install KiwixRAG; zim-index/zim-ask will not work.
      --zim-index       Build KiwixRAG indexes for all ZIMs in --zim-home after install.
      --no-models       Do not pull models (for a preloaded or offline Ollama).
      --no-ingest       Do not run the first document index build now.
      --no-service      Do not install/enable the re-index timer.
      --no-update       Do not run apt-get update first.
  -h, --help            This message.
  -V, --version         Print the version.

${C_BOLD}WHAT IT DOES${C_OFF}
  1. installs python3-numpy, python3-venv, poppler-utils, zim-tools, git, curl and zstd
  2. installs Ollama and enables ollama.service (localhost:11434)
  3. pulls the generation and embedding models unless --no-models
  4. installs /usr/local/bin/ktemata-ai and $AI_CONFIG
  5. installs KiwixRAG (git checkout + venv with sentence-transformers/chromadb)
  6. updates the library admin UI and server, restarting ktemata-admin if installed
  7. indexes $AI_INGEST_DIRS (text, Markdown, HTML, XML, PDF, EPUB, DOCX, ODT)
  8. installs $AI_SERVICE.service + .timer; re-indexes documents every 6 hours

ZIM index:  sudo ktemata-ai zim-index --zim FILE
ZIM ask:    ktemata-ai zim-ask --zim FILE "your question"
Documents:  ktemata-ai ask "your question"

ZIM indexing uses KiwixRAG by brunuff: https://github.com/brunuff/KiwixRAG
EOF
}

run() {
    if $DRY_RUN; then
        printf '%s  [dry-run]%s %s\n' "$C_YELLOW" "$C_OFF" "$*"
        return 0
    fi
    "$@"
}

run_sh() {
    if $DRY_RUN; then
        printf '%s  [dry-run]%s sh -c %q\n' "$C_YELLOW" "$C_OFF" "$1"
        return 0
    fi
    sh -c "$1"
}

has_command() { command -v "$1" >/dev/null 2>&1; }
have_systemd() { [ -d /run/systemd/system ]; }

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        die "run as root: sudo ./$SCRIPT $*"
    fi
}

confirm() {
    $ASSUME_YES && return 0
    local answer
    read -r -p "$1 [y/N] " answer || return 1
    case $answer in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

check_config_secure() {
    local file=$1 owner mode
    [ -r "$file" ] || return 0
    owner=$(stat -c '%u' "$file" 2>/dev/null || true)
    mode=$(stat -c '%a' "$file" 2>/dev/null || true)
    [ "$owner" = 0 ] || die "$file must be owned by root"
    case $mode in
        ''|*[!0-7]*) die "cannot check the permissions of $file" ;;
    esac
    [ $((8#$mode & 022)) -eq 0 ] || die "$file must not be group/other writable"
}

check_platform() {
    [ -r /etc/os-release ] || die "/etc/os-release missing; cannot identify the distribution"
    local ID ID_LIKE PRETTY_NAME
    eval "$( ( . /etc/os-release; printf 'ID=%q ID_LIKE=%q PRETTY_NAME=%q\n' \
        "${ID:-}" "${ID_LIKE:-}" "${PRETTY_NAME:-}" ) )"
    local id_like=" ${ID_LIKE:-} "
    case "${ID:-}${id_like}" in
        *debian*|*ubuntu*) ;;
        *) die "this installer targets Debian/Ubuntu derivatives; found ID=${ID:-?}" ;;
    esac
    log_ok "${PRETTY_NAME:-$ID} ($(uname -m))"
}

install_packages() {
    log_stage "Packages"
    local packages=(curl ca-certificates git python3 python3-numpy python3-venv python3-pip poppler-utils zstd zim-tools)
    if ! $NO_UPDATE; then
        run env DEBIAN_FRONTEND=noninteractive apt-get update -qq
    fi
    run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
    log_ok "${packages[*]}"
}

install_ollama() {
    log_stage "Ollama"
    if has_command ollama; then
        log_ok "already installed: $(ollama --version 2>/dev/null | head -1)"
    else
        log_info "installing Ollama"
        run_sh 'curl -fsSL https://ollama.com/install.sh | sh'
    fi
    if have_systemd; then
        run systemctl enable --now ollama
        log_ok "ollama.service enabled"
    else
        log_warn "systemd is not running here; start 'ollama serve' manually"
    fi
}

wait_ollama() {
    $DRY_RUN && return 0
    local url="${AI_OLLAMA_URL%/}/api/tags" _
    for _ in $(seq 1 60); do
        if curl -fsS --max-time 2 "$url" >/dev/null 2>&1; then
            log_ok "Ollama answers on $AI_OLLAMA_URL"
            return 0
        fi
        sleep 2
    done
    die "Ollama is not answering on $AI_OLLAMA_URL; journalctl -u ollama"
}

pull_model() {
    local name=$1
    case $name in
        *[!A-Za-z0-9._:/-]*) die "invalid model name: $name" ;;
    esac
    if $NO_MODELS; then
        log_info "skipped model $name (--no-models)"
        return 0
    fi
    if $DRY_RUN; then
        printf '%s  [dry-run]%s pull %s\n' "$C_YELLOW" "$C_OFF" "$name"
        return 0
    fi
    log_info "pulling $name (first run downloads the model)"
    if ! curl -fsS --max-time "$AI_PULL_TIMEOUT" -X POST \
            -H 'Content-Type: application/json' \
            -d "{\"name\":\"$name\"}" \
            "${AI_OLLAMA_URL%/}/api/pull" >/dev/null; then
        die "could not pull $name"
    fi
    log_ok "$name"
}

install_admin_assets() {
    local dir=$1 file
    [ -d /usr/share/ktemata/admin ] || return 0
    for file in index.html style.css app.js favicon.svg; do
        [ -r "$dir/ktemata-admin/$file" ] || continue
        run install -m 0644 -o root -g root \
            "$dir/ktemata-admin/$file" "/usr/share/ktemata/admin/$file"
    done
    # The page's /api/ai routes live in the server, not only in the assets. Update the
    # installed server too, or the new box will ask an old binary that answers 404.
    if [ -f /usr/local/bin/ktemata-admin ]; then
        run install -m 0755 -o root -g root \
            "$dir/ktemata-admin.py" /usr/local/bin/ktemata-admin
        if have_systemd && systemctl cat "$ADMIN_SERVICE.service" >/dev/null 2>&1; then
            run systemctl restart "$ADMIN_SERVICE.service"
            log_ok "library admin updated and restarted (Ask the library)"
        else
            log_ok "library admin updated (Ask the library); restart it manually"
        fi
    else
        log_ok "library admin UI updated (Ask the library)"
    fi
}

install_cli() {
    log_stage "CLI"
    local dir
    dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    [ -r "$dir/ktemata-ai.py" ] || die "cannot find ktemata-ai.py next to this script"
    run install -m 0755 -o root -g root "$dir/ktemata-ai.py" "$AI_CLI"
    log_ok "$AI_CLI"
    install_admin_assets "$dir"
}

install_kiwixrag() {
    log_stage "KiwixRAG"
    local dir
    dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    [ -r "$dir/kiwixrag_query.py" ] || die "cannot find kiwixrag_query.py next to this script"
    [ -r "$dir/kiwixrag_index.py" ] || die "cannot find kiwixrag_index.py next to this script"
    [ -r "$dir/kiwixrag-constraints.txt" ] || die "cannot find kiwixrag-constraints.txt next to this script"
    run install -d -m 0755 /opt/ktemata-ai
    if [ ! -d "$AI_KIWIXRAG_DIR/.git" ]; then
        run git clone --depth 1 --branch "$AI_KIWIXRAG_REF" "$AI_KIWIXRAG_URL" "$AI_KIWIXRAG_DIR"
    elif ! $DRY_RUN; then
        if ! git -C "$AI_KIWIXRAG_DIR" fetch --depth 1 origin "$AI_KIWIXRAG_REF" \
                || ! git -C "$AI_KIWIXRAG_DIR" reset --hard FETCH_HEAD; then
            log_warn "could not update $AI_KIWIXRAG_DIR; keeping the existing checkout"
        fi
    fi
    if [ ! -x "$AI_KIWIXRAG_DIR/venv/bin/python" ]; then
        run python3 -m venv "$AI_KIWIXRAG_DIR/venv"
    fi
    run "$AI_KIWIXRAG_DIR/venv/bin/pip" install --upgrade pip
    # PyPI's Linux aarch64 torch wheel pulls CUDA/NVIDIA wheels. The Pi has no GPU;
    # install the CPU build first so sentence-transformers does not resolve the CUDA one.
    run "$AI_KIWIXRAG_DIR/venv/bin/pip" install \
        --index-url "$AI_TORCH_INDEX" \
        --extra-index-url https://pypi.org/simple \
        "$AI_TORCH_SPEC"
    run "$AI_KIWIXRAG_DIR/venv/bin/pip" install -r "$AI_KIWIXRAG_DIR/requirements.txt" \
        -c "$dir/kiwixrag-constraints.txt"
    run install -m 0755 -o root -g root "$dir/kiwixrag_query.py" "$AI_KIWIXRAG_DIR/kiwixrag_query.py"
    run install -m 0755 -o root -g root "$dir/kiwixrag_index.py" "$AI_KIWIXRAG_DIR/kiwixrag_index.py"
    if ! $DRY_RUN && ! $NO_MODELS; then
        log_info "warming the BGE embedding model (first run downloads ~110 MB)"
        if ! HF_HOME="$AI_KIWIXRAG_DIR/.cache/huggingface" \
                "$AI_KIWIXRAG_DIR/venv/bin/python" - <<'PY'
from sentence_transformers import SentenceTransformer
SentenceTransformer("BAAI/bge-base-en-v1.5")
PY
        then
            log_warn "embedding model not warmed; the first zim-index will download it"
        fi
        chmod -R a+rX "$AI_KIWIXRAG_DIR/.cache" 2>/dev/null || true
    fi
    log_ok "$AI_KIWIXRAG_DIR (KiwixRAG + venv + headless helpers)"
}

write_config() {
    log_stage "Configuration"
    if $CONFIG_EXISTED; then
        if ! $DRY_RUN; then
            # Add the ZIM keys introduced after the first install without touching the
            # user's existing values. Existing keys always win; missing ones take this run's
            # flags/defaults.
            if ! grep -q '^AI_ZIM_MODEL=' "$AI_CONFIG"; then
                printf 'AI_ZIM_MODEL=%q\n' "$AI_ZIM_MODEL" >>"$AI_CONFIG"
            fi
            if ! grep -q '^AI_ZIM_HOME=' "$AI_CONFIG"; then
                printf 'AI_ZIM_HOME=%q\n' "$AI_ZIM_HOME" >>"$AI_CONFIG"
            fi
            if ! grep -q '^AI_ZIM_TOP_K=' "$AI_CONFIG"; then
                printf 'AI_ZIM_TOP_K=%q\n' "$AI_ZIM_TOP_K" >>"$AI_CONFIG"
            fi
            if ! grep -q '^AI_KIWIXRAG_DIR=' "$AI_CONFIG"; then
                printf 'AI_KIWIXRAG_DIR=%q\n' "$AI_KIWIXRAG_DIR" >>"$AI_CONFIG"
            fi
            if ! grep -q '^AI_KIWIX_USER=' "$AI_CONFIG"; then
                printf 'AI_KIWIX_USER=%q\n' "$AI_KIWIX_USER" >>"$AI_CONFIG"
            fi
        fi
        log_ok "using existing $AI_CONFIG (edit it to change models or roots)"
        return 0
    fi
    if $DRY_RUN; then
        printf '%s  [dry-run]%s write %s\n' "$C_YELLOW" "$C_OFF" "$AI_CONFIG"
        return 0
    fi
    install -d -m 0755 /etc/ktemata
    {
        printf '# Ktemata offline AI. Read by /usr/local/bin/ktemata-ai and the ingest timer.\n'
        printf '# AI_INGEST_DIRS is a space-separated list; paths must not contain spaces.\n'
        printf '# ZIM retrieval uses KiwixRAG by brunuff: https://github.com/brunuff/KiwixRAG\n'
        printf 'AI_MODEL=%q\n' "$AI_MODEL"
        printf 'AI_EMBED_MODEL=%q\n' "$AI_EMBED_MODEL"
        printf 'AI_OLLAMA_URL=%q\n' "$AI_OLLAMA_URL"
        printf 'AI_INGEST_DIRS=%q\n' "$AI_INGEST_DIRS"
        printf 'AI_DB=%q\n' "$AI_DB"
        printf 'AI_CHUNK_CHARS=%q\n' "1200"
        printf 'AI_CHUNK_OVERLAP=%q\n' "200"
        printf 'AI_TOP_K=%q\n' "4"
        printf 'AI_MAX_FILE_MB=%q\n' "50"
        printf 'AI_ZIM_MODEL=%q\n' "$AI_ZIM_MODEL"
        printf 'AI_ZIM_HOME=%q\n' "$AI_ZIM_HOME"
        printf 'AI_ZIM_TOP_K=%q\n' "$AI_ZIM_TOP_K"
        printf 'AI_KIWIXRAG_DIR=%q\n' "$AI_KIWIXRAG_DIR"
        printf 'AI_KIWIX_USER=%q\n' "$AI_KIWIX_USER"
    } >"$AI_CONFIG"
    chmod 0644 "$AI_CONFIG"
    log_ok "$AI_CONFIG"
}

install_units() {
    if $NO_SERVICE; then
        log_stage "Timer"
        log_info "skipped (--no-service)"
        return 0
    fi
    log_stage "Timer"
    local service="/etc/systemd/system/$AI_SERVICE.service"
    local timer="/etc/systemd/system/$AI_SERVICE.timer"
    if $DRY_RUN; then
        printf '%s  [dry-run]%s write %s and %s\n' "$C_YELLOW" "$C_OFF" "$service" "$timer"
        printf '%s  [dry-run]%s systemctl enable --now %s.timer\n' \
            "$C_YELLOW" "$C_OFF" "$AI_SERVICE"
        return 0
    fi

    cat >"$service" <<EOF
[Unit]
Description=Ktemata offline AI index
Documentation=file:$AI_CONFIG
After=network-online.target ollama.service
Wants=network-online.target ollama.service

[Service]
Type=oneshot
User=root
Nice=10
IOSchedulingClass=idle
# A large first index can take a while; the timer will not start a second copy.
TimeoutStartSec=3600
ExecStart=$AI_CLI ingest
ProtectSystem=strict
ReadWritePaths=$AI_STATE_DIR
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true
NoNewPrivileges=true
EOF
    cat >"$timer" <<EOF
[Unit]
Description=Re-index Ktemata offline AI documents

[Timer]
OnBootSec=5min
OnUnitActiveSec=6h
Persistent=true

[Install]
WantedBy=timers.target
EOF
    chmod 0644 "$service" "$timer"
    log_ok "$service"
    log_ok "$timer"

    if have_systemd; then
        run systemctl daemon-reload
        run systemctl enable --now "$AI_SERVICE.timer"
        log_ok "$AI_SERVICE.timer enabled"
    else
        log_warn "systemd is not running here; start the timer later with:"
        log_warn "  sudo systemctl enable --now $AI_SERVICE.timer"
    fi
}

install_zim_unit() {
    $WITH_KIWIXRAG || return 0
    log_stage "ZIM index service"
    local unit="/etc/systemd/system/ktemata-ai-zim-index@.service"
    if $DRY_RUN; then
        printf '%s  [dry-run]%s write %s\n' "$C_YELLOW" "$C_OFF" "$unit"
        return 0
    fi
    cat >"$unit" <<EOF
[Unit]
Description=Ktemata KiwixRAG index for %I
Documentation=file:$AI_CONFIG
After=network-online.target

[Service]
Type=oneshot
User=root
Nice=10
IOSchedulingClass=idle
# A large archive may take hours; the admin starts one unit per ZIM and polls it.
TimeoutStartSec=0
ExecStart=$AI_CLI zim-index --zim "$AI_ZIM_HOME/%I"
ProtectSystem=strict
ReadWritePaths=$AI_ZIM_HOME -$AI_KIWIXRAG_DIR/.cache
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true
NoNewPrivileges=true
EOF
    chmod 0644 "$unit"
    if have_systemd; then
        run systemctl daemon-reload
    fi
    log_ok "$unit"
}

initial_zim_index() {
    $WITH_ZIM_INDEX || return 0
    if ! $WITH_KIWIXRAG; then
        log_warn "--zim-index needs KiwixRAG (remove --no-kiwixrag)"
        return 0
    fi
    if $NO_MODELS; then
        log_stage "ZIM indexes"
        log_warn "skipped because --no-models was used; run: sudo ktemata-ai zim-index"
        return 0
    fi
    if ! compgen -G "$AI_ZIM_HOME/*.zim" >/dev/null; then
        log_stage "ZIM indexes"
        log_info "no .zim files in $AI_ZIM_HOME; nothing to index"
        return 0
    fi
    log_stage "ZIM indexes"
    run "$AI_CLI" zim-index
}

initial_ingest() {
    if $NO_INGEST; then
        log_stage "Initial index"
        log_info "skipped (--no-ingest)"
        return 0
    fi
    if $NO_MODELS; then
        log_stage "Initial index"
        log_warn "skipped because --no-models was used; pull the models, then: ktemata-ai ingest"
        return 0
    fi
    log_stage "Initial index"
    run install -d -m 0755 "$AI_STATE_DIR"
    run "$AI_CLI" ingest
}

summary() {
    log_stage "Done"
    printf '  model      %s\n' "$AI_MODEL"
    printf '  embeddings %s\n' "$AI_EMBED_MODEL"
    printf '  roots      %s\n' "$AI_INGEST_DIRS"
    printf '  index      %s\n' "$AI_DB"
    printf '  config     %s\n' "$AI_CONFIG"
    printf '  ask        ktemata-ai ask "What is in these documents?"\n'
    printf '  search     ktemata-ai search "keyword"\n'
    printf '  ingest     sudo ktemata-ai ingest\n'
    if $WITH_KIWIXRAG; then
        printf '  zim index  sudo ktemata-ai zim-index --zim FILE (KiwixRAG by brunuff)\n'
        printf '  zim ask    ktemata-ai zim-ask --zim FILE "..." (model %s)\n' "$AI_ZIM_MODEL"
        printf '  credit     https://github.com/brunuff/KiwixRAG\n'
        printf '  admin      the library admin on :8081 has one Ask form (Documents/ZIM) and AI index controls\n'
    else
        printf '  zim        not installed (--no-kiwixrag)\n'
        printf '  admin      the library admin on :8081 has Ask the library\n'
    fi
    if $NO_SERVICE; then
        printf '  timer      not installed (--no-service)\n'
    else
        printf '  timer      systemctl list-timers %s.timer\n' "$AI_SERVICE"
    fi
}

main() {
    local -a dirs=()
    while [ $# -gt 0 ]; do
        case $1 in
            -y|--yes)       ASSUME_YES=true ;;
            -n|--dry-run)   DRY_RUN=true ;;
            --model)        AI_MODEL=${2:?--model needs a name}; shift ;;
            --embed-model)  AI_EMBED_MODEL=${2:?--embed-model needs a name}; shift ;;
            --ollama-url)   AI_OLLAMA_URL=${2:?--ollama-url needs a URL}; shift ;;
            --ingest-dir)   dirs+=("${2:?--ingest-dir needs a path}"); shift ;;
            --db)           AI_DB=${2:?--db needs a path}; shift ;;
            --zim-model)    AI_ZIM_MODEL=${2:?--zim-model needs a name}; shift ;;
            --zim-home)     AI_ZIM_HOME=${2:?--zim-home needs a path}; shift ;;
            --zim-top)      AI_ZIM_TOP_K=${2:?--zim-top needs a number}; shift ;;
            --kiwixrag-dir) AI_KIWIXRAG_DIR=${2:?--kiwixrag-dir needs a path}; shift ;;
            --kiwix-user)   AI_KIWIX_USER=${2:?--kiwix-user needs a user}; shift ;;
            --no-kiwixrag)  WITH_KIWIXRAG=false ;;
            --zim-index)    WITH_ZIM_INDEX=true ;;
            --no-models)    NO_MODELS=true ;;
            --no-ingest)    NO_INGEST=true ;;
            --no-service)   NO_SERVICE=true ;;
            --no-update)    NO_UPDATE=true ;;
            -h|--help)      usage; exit 0 ;;
            -V|--version)   printf '%s %s\n' "$SCRIPT" "$SCRIPT_VERSION"; exit 0 ;;
            *)              die "unknown option: $1" ;;
        esac
        shift
    done

    if [ ${#dirs[@]} -gt 0 ]; then
        AI_INGEST_DIRS="${dirs[*]}"
    fi
    case $AI_DB in /*) ;; *) die "--db must be an absolute path" ;; esac
    AI_STATE_DIR=$(dirname "$AI_DB")
    [ "$AI_STATE_DIR" != "/" ] || die "--db must not be at the filesystem root"

    # An existing config is the runtime source of truth: the timer and the CLI read it, so use
    # its models/roots rather than pulling something different.
    if [ -r "$AI_CONFIG" ]; then
        check_config_secure "$AI_CONFIG"
        # shellcheck disable=SC1090
        . "$AI_CONFIG"
        AI_MODEL=${AI_MODEL:-llama3.2:3b}
        AI_EMBED_MODEL=${AI_EMBED_MODEL:-nomic-embed-text}
        AI_OLLAMA_URL=${AI_OLLAMA_URL:-http://127.0.0.1:11434}
        AI_INGEST_DIRS=${AI_INGEST_DIRS:-"/var/lib/kiwix /srv/kiwix/zim"}
        AI_DB=${AI_DB:-/var/lib/ktemata-ai/index.sqlite3}
        AI_STATE_DIR=$(dirname "$AI_DB")
        [ "$AI_STATE_DIR" != "/" ] || die "AI_DB must not be at the filesystem root"
        CONFIG_EXISTED=true
    fi
    AI_ZIM_MODEL=${AI_ZIM_MODEL:-$AI_MODEL}
    AI_ZIM_HOME=${AI_ZIM_HOME:-/srv/kiwix/zim}
    AI_ZIM_TOP_K=${AI_ZIM_TOP_K:-6}
    AI_KIWIXRAG_DIR=${AI_KIWIXRAG_DIR:-/opt/ktemata-ai/kiwixrag}
    AI_KIWIX_USER=${AI_KIWIX_USER:-ktemata}
    case $AI_ZIM_HOME in /*) ;; *) die "--zim-home must be an absolute path" ;; esac
    case $AI_ZIM_HOME in *" "*) die "--zim-home must not contain spaces" ;; esac
    case $AI_KIWIXRAG_DIR in /*) ;; *) die "--kiwixrag-dir must be an absolute path" ;; esac
    case $AI_KIWIXRAG_DIR in *" "*) die "--kiwixrag-dir must not contain spaces" ;; esac
    case $AI_ZIM_TOP_K in ''|*[!0-9]*) die "--zim-top must be a positive integer" ;; esac
    [ "$AI_ZIM_TOP_K" -ge 1 ] || die "--zim-top must be at least 1"
    case $AI_KIWIX_USER in ''|*[!A-Za-z0-9._-]*) die "invalid --kiwix-user: $AI_KIWIX_USER" ;; esac
    case $AI_OLLAMA_URL in http://*|https://*) ;; *) die "--ollama-url must be an http(s) URL" ;; esac

    $DRY_RUN || require_root "$@"

    if ! $DRY_RUN && ! $ASSUME_YES; then
        confirm "Install Ollama, pull the local models, install KiwixRAG, and index $AI_INGEST_DIRS?" \
            || { log_info "aborted"; exit 0; }
    fi

    check_platform
    install_packages
    install_ollama
    wait_ollama
    pull_model "$AI_EMBED_MODEL"
    pull_model "$AI_MODEL"
    if [ "$AI_ZIM_MODEL" != "$AI_MODEL" ]; then
        pull_model "$AI_ZIM_MODEL"
    fi
    install_cli
    if $WITH_KIWIXRAG; then
        install_kiwixrag
    else
        log_stage "KiwixRAG"
        log_info "skipped (--no-kiwixrag); zim-index and zim-ask are unavailable"
    fi
    write_config
    run install -d -m 0755 "$AI_STATE_DIR"
    install_units
    install_zim_unit
    initial_ingest
    initial_zim_index
    if ! $DRY_RUN; then
        log_stage "Status"
        "$AI_CLI" status
    fi
    summary
}

main "$@"
