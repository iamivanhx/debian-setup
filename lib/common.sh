#!/usr/bin/env bash
# shellcheck shell=bash

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
BLU='\033[0;34m'
CYN='\033[0;36m'
RST='\033[0m'

# Print an informational message to stdout.
info()    { echo -e "${BLU}[INFO]${RST}  $*"; }

# Print a success message to stdout.
success() { echo -e "${GRN}[OK]${RST}    $*"; }

# Print a warning message to stdout.
warn()    { echo -e "${YLW}[WARN]${RST}  $*"; }

# Print an error message to stderr and exit 1.
error()   { echo -e "${RED}[ERROR]${RST} $*" >&2; exit 1; }

# Print a cyan section banner with rule lines above and below.
step()    { echo -e "\n${CYN}══════════════════════════════════════════════${RST}"; \
            echo -e "${CYN}  $*${RST}"; \
            echo -e "${CYN}══════════════════════════════════════════════${RST}"; }

# Deploy a config file from stdin, creating parent dirs and backing up any
# existing file with a dated suffix.
#   Example: echo "hello" | deploy_config /tmp/foo/bar.txt
deploy_config() {
    local target="$1"
    local parent_dir
    parent_dir="$(dirname "$target")"
    mkdir -p "$parent_dir"
    if [[ -f "$target" ]]; then
        local backup
        backup="${target}.bak.$(date +%Y%m%d_%H%M%S_%N)"
        cp "$target" "$backup"
        info "Backed up ${target} → ${backup}"
    fi
    cat > "$target"
}

# Install packages with a dry-run preflight check.
#   Example: safe_install "curl and wget" curl wget
safe_install() {
    local desc="$1"
    shift
    info "Installing: ${desc}..."
    if ! apt-get install -y --dry-run "$@" &>/dev/null; then
        warn "Preflight check flagged issues for: ${desc}. Attempting install anyway..."
    fi
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        || warn "Some packages in '${desc}' could not be installed — continuing."
    success "${desc} installed."
}

# Run a command as the primary non-root user (SUDO_USER if set, else USER).
#   Example: run_as_user git clone https://github.com/example/repo
run_as_user() {
    local target_user="${SUDO_USER:-${USER:-}}"
    if [[ -z "${target_user}" || "${target_user}" == "root" ]]; then
        error "run_as_user: cannot resolve a non-root target user (SUDO_USER='${SUDO_USER:-}', USER='${USER:-}')"
    fi
    sudo -n -u "${target_user}" -- "$@"
}

# Echo a dry-run notice and return 0 when DRY_RUN=1; otherwise return 1.
# Callers can use: dry_run_echo "would do X" && return
#   Example: dry_run_echo "apt-get install curl" && return
dry_run_echo() {
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        info "[dry-run] $*"
        return 0
    fi
    return 1
}
