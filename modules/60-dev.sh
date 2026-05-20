#!/usr/bin/env bash
# shellcheck shell=bash
# Module: 60-dev — mise-managed runtimes + Ruby/Rails build deps + dev TUIs.
#
# Runtime strategy: mise owns Node, Python, Ruby, Go versions per project.
# Apt's nodejs/npm/ruby/ruby-full are `apt-mark hold`ed in 00-base so they
# can't shadow mise's installs.
#
# After install, the user runs:
#   mise use --global node@lts python@3 ruby@3 go@1
#   mise install
# in any project to get the right runtime in PATH.  mise activate in zsh is
# handled by the 50-shell module's .zshrc template.

step "60-dev"

# ---------------------------------------------------------------------------
# 1. Mise apt repo + GPG key
# ---------------------------------------------------------------------------
_mise_keyring=/etc/apt/keyrings/mise-archive-keyring.gpg
_mise_repo_changed=0

if [[ ! -f "${_mise_keyring}" ]]; then
    dry_run_echo "would fetch mise GPG key → ${_mise_keyring}" || {
        install -d -m 0755 /etc/apt/keyrings
        if ! curl -fsSL https://mise.jdx.dev/gpg-key.pub \
                | gpg --dearmor -o "${_mise_keyring}"; then
            warn "mise GPG key fetch failed — skipping mise repo install"
            _mise_keyring=""
        else
            chmod 0644 "${_mise_keyring}"
            _mise_repo_changed=1
        fi
    }
fi

if [[ -n "${_mise_keyring}" ]] \
   && ! guard::file_matches_template /etc/apt/sources.list.d/mise.list \
        "${REPO_ROOT}/templates/etc/apt/sources.list.d/mise.list"; then
    deploy_template /etc/apt/sources.list.d/mise.list "mise apt source"
    _mise_repo_changed=1
fi

if [[ "${_mise_repo_changed}" -eq 1 ]]; then
    dry_run_echo "would apt-get update for mise repo" || apt-get update -qq
fi

# ---------------------------------------------------------------------------
# 2. Mise package + Ruby/Rails build deps + dev TUI from apt
# ---------------------------------------------------------------------------
# Build deps cover ruby-build (mise's Ruby installer) and common gem natives
# (pg, mysql2, sqlite3, nokogiri, ffi, jemalloc-backed Ruby).
_dev_packages=(
    mise
    autoconf bison clang
    libssl-dev libreadline-dev zlib1g-dev libyaml-dev
    libncurses-dev libffi-dev libgdbm-dev libjemalloc2
    libpq-dev libsqlite3-dev default-libmysqlclient-dev
    postgresql-client redis-tools sqlite3
    lazygit
)
_missing_dev=()
for _pkg in "${_dev_packages[@]}"; do
    if ! guard::package_installed "${_pkg}"; then
        _missing_dev+=("${_pkg}")
    fi
done
if [[ "${#_missing_dev[@]}" -gt 0 ]]; then
    dry_run_echo "would install dev packages: ${_missing_dev[*]}" || \
        safe_install "mise + Ruby build deps + lazygit" "${_missing_dev[@]}"
fi

# ---------------------------------------------------------------------------
# 3. lazydocker — single static binary from upstream releases
# ---------------------------------------------------------------------------
LAZYDOCKER_VERSION="${LAZYDOCKER_VERSION:-0.25.2}"
if ! guard::command_exists lazydocker; then
    dry_run_echo "would install lazydocker ${LAZYDOCKER_VERSION} to /usr/local/bin" || {
        _ld_tmp="$(mktemp -d)"
        _ld_url="https://github.com/jesseduffield/lazydocker/releases/download/v${LAZYDOCKER_VERSION}/lazydocker_${LAZYDOCKER_VERSION}_Linux_x86_64.tar.gz"
        info "Downloading lazydocker ${LAZYDOCKER_VERSION}…"
        if curl -fsSL "${_ld_url}" | tar xz -C "${_ld_tmp}" lazydocker; then
            install -m 0755 "${_ld_tmp}/lazydocker" /usr/local/bin/lazydocker
            success "lazydocker installed at /usr/local/bin/lazydocker"
        else
            warn "lazydocker download/extract failed: ${_ld_url}"
        fi
        rm -rf "${_ld_tmp}"
    }
fi

smoke_60_dev() {
    [[ "${DRY_RUN:-0}" == "1" ]] && return 0

    guard::apt_repo_present mise.jdx.dev \
        || { echo "smoke: mise apt repo not present" >&2; return 1; }

    guard::file_matches_template /etc/apt/sources.list.d/mise.list \
            "${REPO_ROOT}/templates/etc/apt/sources.list.d/mise.list" \
        || { echo "smoke: mise apt source does not match template" >&2; return 1; }

    [[ -f /etc/apt/keyrings/mise-archive-keyring.gpg ]] \
        || { echo "smoke: mise keyring missing" >&2; return 1; }

    local pkg
    for pkg in mise lazygit libssl-dev libreadline-dev libyaml-dev \
               libpq-dev libsqlite3-dev default-libmysqlclient-dev \
               postgresql-client redis-tools sqlite3; do
        guard::package_installed "${pkg}" \
            || { echo "smoke: package not installed: ${pkg}" >&2; return 1; }
    done

    guard::command_exists mise \
        || { echo "smoke: mise not on PATH" >&2; return 1; }
    guard::command_exists lazygit \
        || { echo "smoke: lazygit not on PATH" >&2; return 1; }
    guard::command_exists lazydocker \
        || { echo "smoke: lazydocker not on PATH" >&2; return 1; }

    # Apt-mark hold of ruby/ruby-full (set in 00-base) — assert here too since
    # 60-dev is the module that depends on mise winning over apt's ruby.
    local h
    for h in ruby ruby-full; do
        if dpkg-query -W "${h}" &>/dev/null; then
            apt-mark showhold | grep -qxF "${h}" \
                || { echo "smoke: ${h} is installed but not held" >&2; return 1; }
        fi
    done
}
