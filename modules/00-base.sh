#!/usr/bin/env bash
# shellcheck shell=bash
# Module: 00-base

step "00-base"

# OS gate: require Debian trixie
_os_release_file="${_OS_RELEASE:-/etc/os-release}"
# shellcheck source=/dev/null
source "${_os_release_file}"
if [[ "${VERSION_CODENAME:-}" != "trixie" ]]; then
    error "This script requires Debian trixie; detected: ${PRETTY_NAME:-unknown}"
fi

# ---------------------------------------------------------------------------
# 1. Backports config deployment
# ---------------------------------------------------------------------------
deploy_template /etc/apt/sources.list.d/backports.list "backports apt source"
deploy_template /etc/apt/preferences.d/backports "backports pin priority"

# ---------------------------------------------------------------------------
# 2. apt update & upgrade
# ---------------------------------------------------------------------------
# SAFE_REPLAY: apt update and upgrade are idempotent — always run in real mode
if [[ "${DRY_RUN:-0}" != "1" ]]; then
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold"
fi

# ---------------------------------------------------------------------------
# 3. apt-mark hold nodejs npm
# ---------------------------------------------------------------------------
for _held_pkg in nodejs npm ruby; do
    if ! guard::package_held "${_held_pkg}"; then
        dry_run_echo "would apt-mark hold ${_held_pkg}" || \
            apt-mark hold "${_held_pkg}" 2>/dev/null || \
            warn "cannot hold ${_held_pkg} — not known to dpkg (will be held when installed)"
    fi
done

# ---------------------------------------------------------------------------
# 4. Core CLI packages
# ---------------------------------------------------------------------------
# Defined at module scope so both the install block and smoke_00_base share it.
_core_packages=(
    git build-essential make jq curl wget htop ripgrep fd-find bat tree unzip
    ca-certificates gnupg lsb-release
    fzf eza zoxide plocate btop fastfetch gh
)
_missing_packages=()
for _pkg in "${_core_packages[@]}"; do
    if ! guard::package_installed "${_pkg}"; then
        _missing_packages+=("${_pkg}")
    fi
done
if [[ "${#_missing_packages[@]}" -gt 0 ]]; then
    dry_run_echo "would install missing core CLI packages: ${_missing_packages[*]}" || \
        safe_install "core CLI packages" "${_missing_packages[@]}"
fi

# ---------------------------------------------------------------------------
# 5. Locale configuration
# ---------------------------------------------------------------------------
if ! locale -a 2>/dev/null | grep -q 'en_US.utf8\|en_US.UTF-8'; then
    dry_run_echo "would run locale-gen en_US.UTF-8 and configure locale (locale)" || \
        { locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8; }
fi

# ---------------------------------------------------------------------------
# 6. Timezone configuration
# ---------------------------------------------------------------------------
_current_tz="$(timedatectl show --property=Timezone --value 2>/dev/null || true)"
if [[ "${_current_tz}" != "${TIMEZONE}" ]]; then
    dry_run_echo "would set timezone to ${TIMEZONE} via timedatectl" || \
        timedatectl set-timezone "${TIMEZONE}"
fi

smoke_00_base() {
    [[ "${DRY_RUN:-0}" == "1" ]] && return 0

    guard::apt_repo_present trixie-backports \
        || { echo "smoke: backports repo not present" >&2; return 1; }

    guard::file_exists /etc/apt/preferences.d/backports \
        || { echo "smoke: backports pin priority file missing" >&2; return 1; }

    local pkg
    for pkg in "${_core_packages[@]}"; do
        guard::package_installed "${pkg}" \
            || { echo "smoke: package not installed: ${pkg}" >&2; return 1; }
    done

    for _held in nodejs npm ruby; do
        if dpkg-query -W "${_held}" &>/dev/null; then
            apt-mark showhold | grep -qxF "${_held}" \
                || { echo "smoke: ${_held} is installed but not held" >&2; return 1; }
        fi
    done

    locale -a | grep -q 'en_US.utf8' \
        || { echo "smoke: locale en_US.utf8 not generated" >&2; return 1; }

    local _tz
    _tz="$(timedatectl show --property=Timezone --value 2>/dev/null || true)"
    [[ "${_tz}" == "${TIMEZONE}" ]] \
        || { echo "smoke: Timezone is '${_tz}', expected '${TIMEZONE}'" >&2; return 1; }
}
