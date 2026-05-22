#!/usr/bin/env bash
# shellcheck shell=bash
# Module: 50-shell — framework-free zsh + starship + templated dotfiles.
#
# PRD §5.6: zsh as the login shell, no oh-my-zsh / zinit / zplug. Plugins from
# apt only (zsh-autosuggestions, zsh-syntax-highlighting). starship installed
# via the official install script.
#
# An existing ~/.zshrc / ~/.config/starship.toml is backed up with a dated
# suffix when the templated version differs (deploy_user_template behaviour).
# A previous Oh-My-Zsh install in ~/.oh-my-zsh is left in place — the new
# .zshrc simply stops sourcing it. Cleanup is a manual `rm -rf ~/.oh-my-zsh`.

step "50-shell"

# Pinned to the latest tagged release (2026-04-30). Bump deliberately.
STARSHIP_VERSION="${STARSHIP_VERSION:-v1.25.1}"

# ---------------------------------------------------------------------------
# 0. Resolve target user + paths
# ---------------------------------------------------------------------------
_user="${SUDO_USER:-${USER:-}}"
[[ -n "${_user}" && "${_user}" != "root" ]] \
    || error "50-shell: SUDO_USER/USER must resolve to a non-root user"
_user_home="${SETUP_HOME:-}"
[[ -n "${_user_home}" && -d "${_user_home}" ]] \
    || error "50-shell: SETUP_HOME='${_user_home}' is not a directory"

# ---------------------------------------------------------------------------
# 1. Apt packages — zsh and the two whitelisted plugins
# ---------------------------------------------------------------------------
_shell_packages=(zsh zsh-autosuggestions zsh-syntax-highlighting)
_missing_shell=()
for _pkg in "${_shell_packages[@]}"; do
    guard::package_installed "${_pkg}" || _missing_shell+=("${_pkg}")
done
if [[ "${#_missing_shell[@]}" -gt 0 ]]; then
    dry_run_echo "would install shell packages: ${_missing_shell[*]}" || \
        safe_install "zsh + apt plugins" "${_missing_shell[@]}"
fi

# ---------------------------------------------------------------------------
# 2. Starship (official install script — PRD §5.6 mandates this path)
# ---------------------------------------------------------------------------
if ! guard::command_exists starship; then
    dry_run_echo "would install starship ${STARSHIP_VERSION} from starship.rs/install.sh" || {
        if curl -fsSL https://starship.rs/install.sh \
                | sh -s -- -y -b /usr/local/bin -v "${STARSHIP_VERSION}"; then
            success "starship ${STARSHIP_VERSION} installed at $(command -v starship)"
        else
            warn "starship install script failed — check network / starship.rs"
        fi
    }
fi

# ---------------------------------------------------------------------------
# 3. Default login shell → /usr/bin/zsh
# ---------------------------------------------------------------------------
if ! guard::user_shell_is "${_user}" /usr/bin/zsh; then
    dry_run_echo "would chsh -s /usr/bin/zsh ${_user}" || \
        chsh -s /usr/bin/zsh "${_user}" \
        || warn "chsh failed for ${_user} — set the shell manually"
fi

# ---------------------------------------------------------------------------
# 4. Templated dotfiles
# ---------------------------------------------------------------------------
deploy_user_template .zshrc                "framework-free zshrc"
deploy_user_template .config/starship.toml "Gruvbox starship prompt"

# ---------------------------------------------------------------------------
# 5. Pre-create $XDG_CACHE_HOME/zsh (where the templated .zshrc puts history)
# ---------------------------------------------------------------------------
_zsh_cache="${_user_home}/.cache/zsh"
if [[ ! -d "${_zsh_cache}" ]]; then
    dry_run_echo "would mkdir ${_zsh_cache} (owned by ${_user})" || \
        install -d -m 0700 -o "${_user}" -g "${_user}" "${_zsh_cache}"
fi

smoke_50_shell() {
    [[ "${DRY_RUN:-0}" == "1" ]] && return 0

    local pkg
    for pkg in zsh zsh-autosuggestions zsh-syntax-highlighting; do
        guard::package_installed "${pkg}" \
            || { echo "smoke: package not installed: ${pkg}" >&2; return 1; }
    done

    guard::command_exists starship \
        || { echo "smoke: starship not on PATH" >&2; return 1; }

    guard::user_shell_is "${_user}" /usr/bin/zsh \
        || { echo "smoke: ${_user}'s login shell is not /usr/bin/zsh" >&2; return 1; }

    guard::file_matches_template \
            "${_user_home}/.zshrc" \
            "${REPO_ROOT}/templates/home/user/.zshrc" \
        || { echo "smoke: ~/.zshrc does not match template" >&2; return 1; }

    guard::file_matches_template \
            "${_user_home}/.config/starship.toml" \
            "${REPO_ROOT}/templates/home/user/.config/starship.toml" \
        || { echo "smoke: ~/.config/starship.toml does not match template" >&2; return 1; }

    [[ -d "${_user_home}/.cache/zsh" ]] \
        || { echo "smoke: ~/.cache/zsh missing" >&2; return 1; }

    # mise shims must precede /usr/bin in PATH. A stray apt install of nodejs,
    # ruby, etc. would otherwise shadow the mise-managed runtime even though
    # 00-base apt-mark holds the obvious offenders.
    local _zsh_path _mise_pos _usrbin_pos _mise_line
    _mise_line="${_user_home}/.local/share/mise/shims"
    # shellcheck disable=SC2016  # $PATH must be expanded by zsh, not by us.
    _zsh_path="$(run_as_user zsh -ic 'echo $PATH')"
    [[ -n "${_zsh_path}" ]] \
        || { echo "smoke: zsh -ic produced no PATH" >&2; return 1; }
    _mise_pos="$(echo "${_zsh_path}" | tr : '\n' | grep -nxF "${_mise_line}" | head -1 | cut -d: -f1)"
    _usrbin_pos="$(echo "${_zsh_path}" | tr : '\n' | grep -nxF '/usr/bin' | head -1 | cut -d: -f1)"
    [[ -n "${_mise_pos}" ]] \
        || { echo "smoke: mise shims (${_mise_line}) not in zsh PATH" >&2; return 1; }
    [[ -n "${_usrbin_pos}" ]] \
        || { echo "smoke: /usr/bin not in zsh PATH" >&2; return 1; }
    [[ "${_mise_pos}" -lt "${_usrbin_pos}" ]] \
        || { echo "smoke: mise shims must precede /usr/bin in zsh PATH" >&2; return 1; }
}
