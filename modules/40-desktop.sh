#!/usr/bin/env bash
# shellcheck shell=bash
# Module: 40-desktop — GNOME on Wayland + Gruvbox look & feel + Ghostty terminal.
#
# Convergence target: a fresh Debian 13 box logs in to GNOME 48 (Wayland) and
# sees Gruvbox-Dark-Medium GTK + libadwaita, Gruvbox-Plus-Dark icons, Bibata
# cursor, JetBrainsMono Nerd Font in the terminal, Inter Variable in the UI,
# orange accent, Gruvbox wallpaper, dash-to-dock + space-bar enabled, and
# Ghostty installed and themed to Gruvbox Dark Hard.
#
# Defaults are written to the system dconf db (/etc/dconf/db/local.d/40-gruvbox);
# users can still override via Settings. After the first run on a fresh box, log
# out and back in for the GDM session to pick the new defaults up.

step "40-desktop"

# ---------------------------------------------------------------------------
# 0. Resolve target user + paths
# ---------------------------------------------------------------------------
_user="${SUDO_USER:-${USER:-}}"
[[ -n "${_user}" && "${_user}" != "root" ]] \
    || error "40-desktop: SUDO_USER/USER must resolve to a non-root user"
_user_home="${SETUP_HOME:-}"
[[ -n "${_user_home}" && -d "${_user_home}" ]] \
    || error "40-desktop: SETUP_HOME='${_user_home}' is not a directory"

# Knobs (override via secrets.env or env). Refs are pinned for reproducibility:
# bump them deliberately when you want the upstream change.
GHOSTTY_VERSION="${GHOSTTY_VERSION:-1.3.1-0.ppa2}"
GHOSTTY_DEB_URL="${GHOSTTY_DEB_URL:-https://github.com/mkasberg/ghostty-ubuntu/releases/download/${GHOSTTY_VERSION%%.ppa*}-ppa${GHOSTTY_VERSION##*ppa}/ghostty_${GHOSTTY_VERSION}_amd64_trixie.deb}"
GRUVBOX_GTK_REPO="${GRUVBOX_GTK_REPO:-Fausto-Korpsvart/Gruvbox-GTK-Theme}"
# Pinned to master @ 2025-10-23 (no upstream tags published).
GRUVBOX_GTK_REF="${GRUVBOX_GTK_REF:-578cd220b5ff6e86b078a6111d26bb20ec8c733f}"
GRUVBOX_ICONS_REPO="${GRUVBOX_ICONS_REPO:-SylEleuth/gruvbox-plus-icon-pack}"
# Pinned to the latest tagged release (2026-04-17).
GRUVBOX_ICONS_REF="${GRUVBOX_ICONS_REF:-v6.4.0}"
JETBRAINS_FONT_URL="${JETBRAINS_FONT_URL:-https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip}"

# ---------------------------------------------------------------------------
# 1. GNOME core packages + themeable companions
# ---------------------------------------------------------------------------
_desktop_packages=(
    gnome-shell gdm3 gnome-shell-extensions gnome-shell-extension-manager
    gnome-tweaks gnome-themes-extra
    nautilus gnome-text-editor gnome-system-monitor file-roller
    loupe evince gnome-calculator gnome-screenshot flameshot
    bibata-cursor-theme papirus-icon-theme
    fonts-inter-variable fonts-noto fonts-noto-color-emoji fonts-cantarell
    dconf-cli xdg-user-dirs
)
_missing_desktop=()
for _pkg in "${_desktop_packages[@]}"; do
    guard::package_installed "${_pkg}" || _missing_desktop+=("${_pkg}")
done
if [[ "${#_missing_desktop[@]}" -gt 0 ]]; then
    dry_run_echo "would install desktop packages: ${_missing_desktop[*]}" || \
        safe_install "GNOME + theming + fonts" "${_missing_desktop[@]}"
fi

# ---------------------------------------------------------------------------
# 2. JetBrainsMono Nerd Font (idempotent)
# ---------------------------------------------------------------------------
if ! grep -q "JetBrainsMono Nerd Font" < <(fc-list 2>/dev/null); then
    if dry_run_echo "would install JetBrainsMono Nerd Font from upstream"; then :; else
        _font_dir=/usr/local/share/fonts/JetBrainsMonoNerdFont
        _font_tmp="$(mktemp -d)"
        info "Downloading JetBrainsMono Nerd Font…"
        if curl -fsSL -o "${_font_tmp}/jb.zip" "${JETBRAINS_FONT_URL}" \
           && unzip -q -o "${_font_tmp}/jb.zip" -d "${_font_tmp}/jb"; then
            install -d -m 0755 "${_font_dir}"
            install -m 0644 "${_font_tmp}/jb"/*.ttf "${_font_dir}/"
            fc-cache -fq "${_font_dir}"
            success "JetBrainsMono Nerd Font installed to ${_font_dir}"
        else
            warn "JetBrainsMono Nerd Font download/extract failed — continuing"
        fi
        rm -rf "${_font_tmp}"
    fi
fi

# ---------------------------------------------------------------------------
# 3+4. Gruvbox GTK theme + icon pack — fetched from pinned GitHub refs.
# Tarball download (vs git clone) lets us pin to either a tag or a SHA.
# ---------------------------------------------------------------------------
_install_theme_tarball() {
    # _install_theme_tarball <owner/repo> <ref> <src_subdir> <src_match> <dest_dir> <marker>
    #   src_subdir : directory inside the extracted tarball to read from
    #   src_match  : glob (relative to src_subdir) of what to copy into dest_dir
    local repo="$1" ref="$2" src_subdir="$3" src_match="$4" dest_dir="$5" marker="$6"
    if [[ -f "${marker}" ]]; then
        return 0
    fi
    # Accept a pre-existing copy under /usr/share/* (apt or earlier hand-install)
    # as already-present — don't duplicate under /usr/local.
    local legacy="${marker/\/usr\/local\/share/\/usr\/share}"
    if [[ -f "${legacy}" ]]; then
        info "  found existing theme at ${legacy} — skipping fetch"
        return 0
    fi
    dry_run_echo "would fetch ${repo}@${ref} → ${dest_dir}" && return 0
    local tmp
    tmp="$(mktemp -d)"
    local url="https://github.com/${repo}/archive/${ref}.tar.gz"
    info "Downloading ${repo}@${ref}…"
    if curl -fsSL "${url}" | tar xz -C "${tmp}"; then
        local root
        root="$(find "${tmp}" -mindepth 1 -maxdepth 1 -type d | head -n1)"
        install -d -m 0755 "${dest_dir}"
        # shellcheck disable=SC2086
        cp -r ${root}/${src_subdir}/${src_match} "${dest_dir}/"
        success "Installed ${repo}@${ref} → ${dest_dir}/"
    else
        warn "Theme fetch failed: ${url}"
    fi
    rm -rf "${tmp}"
}

_install_theme_tarball "${GRUVBOX_GTK_REPO}" "${GRUVBOX_GTK_REF}" \
    "themes" "Gruvbox-Dark-Medium*" \
    "/usr/local/share/themes" \
    "/usr/local/share/themes/Gruvbox-Dark-Medium/index.theme"

_install_theme_tarball "${GRUVBOX_ICONS_REPO}" "${GRUVBOX_ICONS_REF}" \
    "icons" "Gruvbox-Plus-Dark" \
    "/usr/local/share/icons" \
    "/usr/local/share/icons/Gruvbox-Plus-Dark/index.theme"

# Refresh icon cache if either Gruvbox-Plus dir is present
for _icondir in /usr/local/share/icons/Gruvbox-Plus-Dark /usr/share/icons/Gruvbox-Plus-Dark; do
    if [[ -d "${_icondir}" ]] && [[ ! -f "${_icondir}/icon-theme.cache" ]]; then
        dry_run_echo "would gtk-update-icon-cache ${_icondir}" || \
            gtk-update-icon-cache -f -q "${_icondir}" 2>/dev/null || true
    fi
done

# ---------------------------------------------------------------------------
# 5. GNOME Shell extensions from EGO (per-user install)
# ---------------------------------------------------------------------------
_install_ego_extension() {
    # _install_ego_extension <uuid>
    local uuid="$1"
    local ext_dir="${_user_home}/.local/share/gnome-shell/extensions/${uuid}"
    # Already present (user-installed or system-installed via apt)?
    local sysdir
    for sysdir in "${ext_dir}" \
                  "/usr/share/gnome-shell/extensions/${uuid}" \
                  "/usr/local/share/gnome-shell/extensions/${uuid}"; do
        [[ -f "${sysdir}/metadata.json" ]] && return 0
    done
    dry_run_echo "would install GNOME extension ${uuid} from extensions.gnome.org" && return 0
    local shell_major
    shell_major="$(gnome-shell --version 2>/dev/null | awk '{print $3}' | cut -d. -f1)"
    [[ -n "${shell_major}" ]] || { warn "cannot detect gnome-shell version — skipping ${uuid}"; return 0; }
    local info_json download_url
    info_json="$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${shell_major}" 2>/dev/null)"
    if [[ -z "${info_json}" ]]; then
        warn "EGO lookup failed for ${uuid} (shell ${shell_major})"
        return 0
    fi
    download_url="$(printf '%s' "${info_json}" | jq -r '.download_url // ""' 2>/dev/null || true)"
    if [[ -z "${download_url}" ]]; then
        warn "${uuid} has no build for GNOME ${shell_major}"
        return 0
    fi
    local tmp
    tmp="$(mktemp -d)"
    if curl -fsSL -o "${tmp}/ext.zip" "https://extensions.gnome.org${download_url}"; then
        install -d -m 0755 -o "${_user}" -g "${_user}" "${ext_dir}"
        unzip -q -o "${tmp}/ext.zip" -d "${ext_dir}"
        chown -R "${_user}:${_user}" "${ext_dir}"
        # Compile gsettings schema if shipped
        if [[ -d "${ext_dir}/schemas" ]]; then
            run_as_user glib-compile-schemas "${ext_dir}/schemas" 2>/dev/null || \
                glib-compile-schemas "${ext_dir}/schemas" 2>/dev/null || true
        fi
        success "Extension installed: ${uuid}"
    else
        warn "Extension download failed: ${uuid}"
    fi
    rm -rf "${tmp}"
}

_install_ego_extension "dash-to-dock@micxgx.gmail.com"
_install_ego_extension "space-bar@luchrioh"
_install_ego_extension "tactile@lundal.io"
_install_ego_extension "just-perfection-desktop@just-perfection"
_install_ego_extension "appindicatorsupport@rgcjonas.gmail.com"

# ---------------------------------------------------------------------------
# 6. Wallpaper template
# ---------------------------------------------------------------------------
deploy_template /usr/local/share/backgrounds/gruvbox-dark.svg "Gruvbox wallpaper"

# ---------------------------------------------------------------------------
# 7. GTK4 / libadwaita shim — symlink theme assets into ~/.config/gtk-4.0/
# ---------------------------------------------------------------------------
_gtk4_src=""
for _candidate in /usr/local/share/themes/Gruvbox-Dark-Medium/gtk-4.0 /usr/share/themes/Gruvbox-Dark-Medium/gtk-4.0; do
    if [[ -d "${_candidate}" ]]; then _gtk4_src="${_candidate}"; break; fi
done
if [[ -n "${_gtk4_src}" ]]; then
    _gtk4_dst="${_user_home}/.config/gtk-4.0"
    if dry_run_echo "would link gtk-4.0 assets from ${_gtk4_src} → ${_gtk4_dst}"; then :; else
        install -d -m 0755 -o "${_user}" -g "${_user}" "${_gtk4_dst}"
        for _f in gtk.css gtk-dark.css assets; do
            if [[ -e "${_gtk4_src}/${_f}" ]] \
               && ! guard::symlink_is "${_gtk4_dst}/${_f}" "${_gtk4_src}/${_f}"; then
                rm -rf "${_gtk4_dst:?}/${_f:?}"
                ln -s "${_gtk4_src}/${_f}" "${_gtk4_dst}/${_f}"
                chown -h "${_user}:${_user}" "${_gtk4_dst}/${_f}"
            fi
        done
    fi
else
    warn "Gruvbox-Dark-Medium gtk-4.0 dir not found — libadwaita apps will use Adwaita Dark"
fi

# ---------------------------------------------------------------------------
# 8. System dconf defaults — user session + GDM greeter
# ---------------------------------------------------------------------------
_dconf_changed=0
for _pair in \
        "/etc/dconf/profile/user|dconf profile (user + system-db:local)" \
        "/etc/dconf/db/local.d/40-gruvbox|GNOME look-and-feel defaults" \
        "/etc/dconf/profile/gdm|dconf profile (gdm greeter)" \
        "/etc/dconf/db/gdm.d/40-gruvbox|GDM greeter look-and-feel"; do
    _dest="${_pair%%|*}"; _desc="${_pair##*|}"
    if ! guard::file_matches_template "${_dest}" "${REPO_ROOT}/templates${_dest}"; then
        deploy_template "${_dest}" "${_desc}"
        _dconf_changed=1
    fi
done
if [[ "${_dconf_changed}" -eq 1 ]]; then
    dry_run_echo "would run dconf update" || dconf update
fi

# ---------------------------------------------------------------------------
# 8b. xdg-terminal-exec → Ghostty (system + user defaults)
# Modern GNOME uses xdg-terminal-exec to resolve "Open in Terminal here" rather
# than the deprecated org.gnome.desktop.default-applications.terminal key,
# which is still set in the dconf db above as a belt-and-braces fallback.
# ---------------------------------------------------------------------------
deploy_template /etc/xdg/xdg-terminals.list "system xdg-terminal-exec default"
deploy_user_template .config/xdg-terminals.list "user xdg-terminal-exec default"

# ---------------------------------------------------------------------------
# 8c. btop + fastfetch user config (Gruvbox)
# ---------------------------------------------------------------------------
deploy_user_template .config/btop/btop.conf "btop Gruvbox config"
deploy_user_template .config/fastfetch/config.jsonc "fastfetch Gruvbox config"

# ---------------------------------------------------------------------------
# 9. Ghostty (.deb from mkasberg/ghostty-ubuntu, trixie build)
# ---------------------------------------------------------------------------
if ! guard::package_installed ghostty; then
    if dry_run_echo "would download and install Ghostty ${GHOSTTY_VERSION} (.deb)"; then :; else
        _ghostty_tmp="$(mktemp -d)"
        _ghostty_deb="${_ghostty_tmp}/ghostty.deb"
        info "Downloading Ghostty ${GHOSTTY_VERSION} from ${GHOSTTY_DEB_URL}…"
        if curl -fsSL -o "${_ghostty_deb}" "${GHOSTTY_DEB_URL}"; then
            DEBIAN_FRONTEND=noninteractive apt-get install -y \
                -o Dpkg::Options::="--force-confdef" \
                -o Dpkg::Options::="--force-confold" \
                "${_ghostty_deb}" \
                || warn "Ghostty install failed — check ${GHOSTTY_DEB_URL}"
        else
            warn "Ghostty .deb download failed: ${GHOSTTY_DEB_URL}"
        fi
        rm -rf "${_ghostty_tmp}"
    fi
fi

# ---------------------------------------------------------------------------
# 10. Ghostty user config
# ---------------------------------------------------------------------------
deploy_user_template .config/ghostty/config "Ghostty Gruvbox config"

# ---------------------------------------------------------------------------
# 11. x-terminal-emulator alternative → Ghostty (when present)
# ---------------------------------------------------------------------------
if guard::command_exists ghostty && [[ -x /usr/bin/ghostty ]]; then
    if [[ "$(update-alternatives --query x-terminal-emulator 2>/dev/null | awk '/^Value:/{print $2}')" != "/usr/bin/ghostty" ]]; then
        dry_run_echo "would set x-terminal-emulator → /usr/bin/ghostty" || {
            update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/ghostty 60 >/dev/null 2>&1 || true
            update-alternatives --set x-terminal-emulator /usr/bin/ghostty >/dev/null 2>&1 || true
        }
    fi
fi

smoke_40_desktop() {
    [[ "${DRY_RUN:-0}" == "1" ]] && return 0

    local pkg
    for pkg in gnome-shell gdm3 gnome-shell-extensions gnome-tweaks \
               bibata-cursor-theme fonts-inter-variable fonts-noto-color-emoji \
               dconf-cli; do
        guard::package_installed "${pkg}" \
            || { echo "smoke: package not installed: ${pkg}" >&2; return 1; }
    done

    grep -q "JetBrainsMono Nerd Font" < <(fc-list 2>/dev/null) \
        || { echo "smoke: JetBrainsMono Nerd Font not registered" >&2; return 1; }

    [[ -f /usr/local/share/themes/Gruvbox-Dark-Medium/index.theme \
       || -f /usr/share/themes/Gruvbox-Dark-Medium/index.theme ]] \
        || { echo "smoke: Gruvbox-Dark-Medium GTK theme missing" >&2; return 1; }

    [[ -f /usr/local/share/icons/Gruvbox-Plus-Dark/index.theme \
       || -f /usr/share/icons/Gruvbox-Plus-Dark/index.theme ]] \
        || { echo "smoke: Gruvbox-Plus-Dark icon theme missing" >&2; return 1; }

    local _dconf_file
    for _dconf_file in \
            /etc/dconf/profile/user \
            /etc/dconf/db/local.d/40-gruvbox \
            /etc/dconf/profile/gdm \
            /etc/dconf/db/gdm.d/40-gruvbox \
            /etc/xdg/xdg-terminals.list; do
        guard::file_matches_template "${_dconf_file}" \
                "${REPO_ROOT}/templates${_dconf_file}" \
            || { echo "smoke: ${_dconf_file} does not match template" >&2; return 1; }
    done

    [[ -f /etc/dconf/db/local && -f /etc/dconf/db/gdm ]] \
        || { echo "smoke: compiled dconf dbs missing — did dconf update run?" >&2; return 1; }

    guard::file_matches_template \
            /usr/local/share/backgrounds/gruvbox-dark.svg \
            "${REPO_ROOT}/templates/usr/local/share/backgrounds/gruvbox-dark.svg" \
        || { echo "smoke: gruvbox-dark.svg wallpaper does not match template" >&2; return 1; }

    local u_home
    u_home="${SETUP_HOME:?SETUP_HOME unset}"
    local ext_uuid d found
    for ext_uuid in dash-to-dock@micxgx.gmail.com space-bar@luchrioh; do
        found=0
        for d in "${u_home}/.local/share/gnome-shell/extensions/${ext_uuid}" \
                 "/usr/share/gnome-shell/extensions/${ext_uuid}" \
                 "/usr/local/share/gnome-shell/extensions/${ext_uuid}"; do
            [[ -f "${d}/metadata.json" ]] && { found=1; break; }
        done
        [[ "${found}" -eq 1 ]] \
            || { echo "smoke: extension missing: ${ext_uuid}" >&2; return 1; }
    done

    guard::command_exists ghostty \
        || { echo "smoke: ghostty not on PATH" >&2; return 1; }

    guard::file_matches_template \
            "${u_home}/.config/ghostty/config" \
            "${REPO_ROOT}/templates/home/user/.config/ghostty/config" \
        || { echo "smoke: ghostty user config does not match template" >&2; return 1; }

    guard::file_matches_template \
            "${u_home}/.config/xdg-terminals.list" \
            "${REPO_ROOT}/templates/home/user/.config/xdg-terminals.list" \
        || { echo "smoke: user xdg-terminals.list does not match template" >&2; return 1; }

    for ext_uuid in tactile@lundal.io \
                    just-perfection-desktop@just-perfection \
                    appindicatorsupport@rgcjonas.gmail.com; do
        found=0
        for d in "${u_home}/.local/share/gnome-shell/extensions/${ext_uuid}" \
                 "/usr/share/gnome-shell/extensions/${ext_uuid}" \
                 "/usr/local/share/gnome-shell/extensions/${ext_uuid}"; do
            [[ -f "${d}/metadata.json" ]] && { found=1; break; }
        done
        [[ "${found}" -eq 1 ]] \
            || { echo "smoke: extension missing: ${ext_uuid}" >&2; return 1; }
    done

    guard::package_installed flameshot \
        || { echo "smoke: flameshot not installed" >&2; return 1; }

    guard::file_matches_template \
            "${u_home}/.config/btop/btop.conf" \
            "${REPO_ROOT}/templates/home/user/.config/btop/btop.conf" \
        || { echo "smoke: btop config does not match template" >&2; return 1; }

    guard::file_matches_template \
            "${u_home}/.config/fastfetch/config.jsonc" \
            "${REPO_ROOT}/templates/home/user/.config/fastfetch/config.jsonc" \
        || { echo "smoke: fastfetch config does not match template" >&2; return 1; }
}
