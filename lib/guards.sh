#!/usr/bin/env bash
# shellcheck shell=bash
#
# lib/guards.sh — Idempotency guard vocabulary
#
# Convention: every destructive call in a module must be wrapped in a
# guard::* check OR preceded by "# SAFE_REPLAY: <reason>".
#
# Each guard:
#   - Returns 0 when the desired state is already present (no action needed).
#   - Returns 1 when the desired state is absent (action needed).
#   - Reads state only — never mutates the system.
#
# Destructive verbs requiring a guard wrapper include:
#   apt install, apt-mark hold, cp, ln -s, mkdir, mkfs, mount,
#   cryptsetup luksFormat, systemctl enable, usermod, chsh,
#   docker network create, docker compose up.

# Usage: guard::command_exists curl
# Returns 0 if the command is found on PATH, 1 otherwise.
guard::command_exists() {
    command -v "${1}" > /dev/null 2>&1
}

# Usage: guard::file_exists /etc/fstab
# Returns 0 if a regular file exists at path, 1 otherwise.
guard::file_exists() {
    [[ -f "$1" ]]
}

# Usage: guard::dir_exists /var/log
# Returns 0 if a directory exists at path, 1 otherwise.
guard::dir_exists() {
    [[ -d "$1" ]]
}

# Usage: guard::symlink_is /home/user/.config /dotfiles/config
# Returns 0 if <link> is a symlink whose resolved target matches <target>, 1 otherwise.
guard::symlink_is() {
    [[ -L "$1" ]] && [[ "$(readlink -f "$1")" == "$(readlink -f "$2")" ]]
}

# Usage: guard::file_has_line /etc/fstab '^UUID'
# Returns 0 if any line in the file matches the extended regex, 1 otherwise.
guard::file_has_line() {
    grep -qE "$2" "$1" 2>/dev/null
}

# Usage: guard::file_matches_template /etc/foo.conf /dotfiles/foo.conf
# Returns 0 if the file at path is byte-identical to the template file, 1 otherwise.
guard::file_matches_template() {
    cmp -s "$1" "$2"
}

# Usage: guard::package_installed coreutils
# Returns 0 if the dpkg package is fully installed, 1 otherwise.
guard::package_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q '^install ok installed$'
}

# Usage: guard::package_held coreutils
# Returns 0 if the package is held via apt-mark hold, 1 otherwise.
guard::package_held() {
    apt-mark showhold | grep -qxF "$1"
}

# Usage: guard::apt_repo_present debian
# Returns 0 if the keyword appears in any apt sources file, 1 otherwise.
guard::apt_repo_present() {
    grep -rql "$1" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null
}

# Usage: guard::service_enabled systemd-journald
# Returns 0 if the systemd unit is enabled, 1 otherwise.
guard::service_enabled() {
    systemctl is-enabled "$1" &>/dev/null
}

# Usage: guard::service_active systemd-journald
# Returns 0 if the systemd unit is currently active, 1 otherwise.
guard::service_active() {
    systemctl is-active "$1" &>/dev/null
}

# Usage: guard::unit_file_exists systemd-journald
# Returns 0 if the systemd unit file exists, 1 otherwise.
guard::unit_file_exists() {
    systemctl cat "$1" &>/dev/null
}

# Usage: guard::user_in_group ivan sudo
# Returns 0 if the user is a member of the group, 1 otherwise.
guard::user_in_group() {
    id -nG "$1" 2>/dev/null | tr ' ' '\n' | grep -qx "$2"
}

# Usage: guard::user_shell_is ivan /bin/bash
# Returns 0 if the user's login shell matches the given shell path, 1 otherwise.
guard::user_shell_is() {
    local entry
    entry="$(getent passwd "$1")"
    [[ -n "$entry" ]] && [[ "${entry##*:}" == "$2" ]]
}

# Usage: guard::docker_network_exists my_network
# Returns 0 if the Docker network exists, 1 otherwise.
guard::docker_network_exists() {
    docker network inspect "$1" >/dev/null 2>&1
}

# Usage: guard::container_running my_container
# Returns 0 if a Docker container with that name is currently running, 1 otherwise.
guard::container_running() {
    docker inspect --format='{{.State.Running}}' "$1" 2>/dev/null | grep -q 'true'
}

# Usage: guard::port_listening tcp 443
# Returns 0 if a socket is listening on the given protocol and port, 1 otherwise.
guard::port_listening() {
    local flag
    case "$1" in
        tcp) flag="-t" ;;
        udp) flag="-u" ;;
        *)   return 1 ;;
    esac
    ss -Hln "$flag" | grep -qE ":${2}[[:space:]]"
}
