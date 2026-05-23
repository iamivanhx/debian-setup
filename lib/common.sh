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
        # apt scans /etc/apt/{apt.conf.d,sources.list.d,preferences.d}/ for
        # config snippets and prints a warning for every sibling whose
        # extension it doesn't recognise — including our `.bak.<timestamp>`
        # files. For those directories, divert the backup to a mirrored path
        # under /var/backups/debian-setup so it stays out of apt's view.
        local backup_dir
        case "${parent_dir}" in
            /etc/apt/apt.conf.d|/etc/apt/sources.list.d|/etc/apt/preferences.d)
                backup_dir="/var/backups/debian-setup${parent_dir}"
                mkdir -p "${backup_dir}"
                ;;
            *)
                backup_dir="${parent_dir}"
                ;;
        esac
        local backup
        backup="${backup_dir}/$(basename "$target").bak.$(date +%Y%m%d_%H%M%S_%N)"
        cp "$target" "$backup"
        info "Backed up ${target} → ${backup}"
    fi
    cat > "$target"
}

# Install packages with a dry-run preflight check.
#
# On install failure, refresh the apt index and retry once.  Catches the common
# case where the cached Packages index points at a .deb version the mirror has
# already rotated away (e.g. libc6-i386 2.41-12+deb13u2 → 404 after a point
# release), without needing a full second run.sh.
#   Example: safe_install "curl and wget" curl wget
safe_install() {
    local desc="$1"
    shift
    info "Installing: ${desc}..."
    if ! apt-get install -y --dry-run "$@" &>/dev/null; then
        warn "Preflight check flagged issues for: ${desc}. Attempting install anyway..."
    fi
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold"; then
        warn "Install of '${desc}' failed — refreshing apt index and retrying once..."
        apt-get update -qq || true
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            || { warn "Some packages in '${desc}' could not be installed — continuing."; return; }
    fi
    success "${desc} installed."
}

# Run a command as the primary non-root user (SUDO_USER if set, else USER).
# `sudo -H` rewrites HOME to the target user's home; default Debian sudoers
# does not set `always_set_home`, so without `-H` HOME would stay at the
# caller's value (e.g. /root) and tools that key off HOME (mise, npm, glib,
# zsh dotfile sourcing) would write to the wrong directory.
#   Example: run_as_user git clone https://github.com/example/repo
run_as_user() {
    local target_user="${SUDO_USER:-${USER:-}}"
    if [[ -z "${target_user}" || "${target_user}" == "root" ]]; then
        error "run_as_user: cannot resolve a non-root target user (SUDO_USER='${SUDO_USER:-}', USER='${USER:-}')"
    fi
    sudo -H -n -u "${target_user}" -- "$@"
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

# Deploy a template file to its destination if the destination does not already
# match the template.  The template path is derived as:
#   ${REPO_ROOT}/templates${dest}
# so the caller only needs to supply the destination path.
# An optional second argument overrides the dry-run message description.
#   Example: deploy_template /etc/apt/preferences.d/backports "backports pin priority"
deploy_template() {
    local dest="${1:-}"
    [[ -n "${dest}" ]] || error "deploy_template: dest argument must not be empty"
    local desc="${2:-${dest}}"
    local template="${REPO_ROOT}/templates${dest}"
    [[ -f "${template}" ]] || error "deploy_template: template not found: ${template}"
    if ! guard::file_matches_template "${dest}" "${template}"; then
        dry_run_echo "would deploy ${dest} (${desc})" || \
            deploy_config "${dest}" < "${template}"
    fi
}

# Deploy a template, expanding a whitelist of ${VAR} references via envsubst.
# Use this when a templated file needs runtime values (LAN_SUBNET, etc).
# The whitelist keeps envsubst from touching shell-syntax $vars that aren't
# meant to be expanded (sshd_config doesn't need this; nftables does).
#   Example: deploy_template_subst /etc/nftables.conf "nftables ruleset" '${LAN_SUBNET}'
deploy_template_subst() {
    local dest="${1:-}" desc="${2:-${1}}" varlist="${3:-}"
    [[ -n "${dest}"    ]] || error "deploy_template_subst: dest required"
    [[ -n "${varlist}" ]] || error "deploy_template_subst: varlist required (e.g. '\${LAN_SUBNET}')"
    local template="${REPO_ROOT}/templates${dest}"
    [[ -f "${template}" ]] || error "deploy_template_subst: template not found: ${template}"
    local rendered
    rendered="$(envsubst "${varlist}" < "${template}")"
    if [[ -f "${dest}" ]] && diff -q <(printf '%s' "${rendered}") "${dest}" >/dev/null 2>&1; then
        return 0
    fi
    dry_run_echo "would deploy ${dest} (${desc}, envsubst:${varlist})" && return 0
    printf '%s' "${rendered}" | deploy_config "${dest}"
}

# Deploy a per-user template into ${SETUP_HOME}, owned by the target user.
# The source path uses the literal placeholder "user":
#   ${REPO_ROOT}/templates/home/user/<rel_path>
# The destination is:
#   ${SETUP_HOME}/<rel_path>
# Parent dirs are created mode 0755 owned by the user; the destination file is
# mode 0644 chown'd to the user. Backed up with a dated suffix if it exists
# and differs.
#   Example: deploy_user_template .config/ghostty/config "ghostty terminal config"
deploy_user_template() {
    local rel="${1:-}"
    [[ -n "${rel}" ]] || error "deploy_user_template: relative path must not be empty"
    local desc="${2:-${rel}}"
    [[ -n "${SETUP_HOME:-}" ]] || error "deploy_user_template: SETUP_HOME is unset"
    local template="${REPO_ROOT}/templates/home/user/${rel}"
    local dest="${SETUP_HOME}/${rel}"
    [[ -f "${template}" ]] || error "deploy_user_template: template not found: ${template}"
    if guard::file_matches_template "${dest}" "${template}"; then
        return 0
    fi
    dry_run_echo "would deploy ${dest} (${desc})" && return 0
    local owner_user owner_group
    owner_user="$(stat -c '%U' "${SETUP_HOME}")"
    owner_group="$(stat -c '%G' "${SETUP_HOME}")"
    install -d -o "${owner_user}" -g "${owner_group}" -m 0755 "$(dirname "${dest}")"
    if [[ -f "${dest}" ]]; then
        local backup
        backup="${dest}.bak.$(date +%Y%m%d_%H%M%S_%N)"
        cp -a "${dest}" "${backup}"
        info "Backed up ${dest} → ${backup}"
    fi
    install -m 0644 -o "${owner_user}" -g "${owner_group}" "${template}" "${dest}"
}
