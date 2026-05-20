#!/usr/bin/env bash
# shellcheck shell=bash
# Module: 70-lab — Docker CE + Compose plugin from docker.com's apt repo.
#
# v1 scope (2026-05-20): Docker engine only. The Traefik + avahi-aliases +
# whoami reference project from PRD §5.8 are deferred to a follow-up module.
# 20-storage already preps /etc/docker/daemon.json (data-root → /srv/data/
# docker) and a docker.service systemd drop-in that waits for /srv/data to
# mount, so installing docker-ce here lands on a pre-configured daemon.

step "70-lab"

# ---------------------------------------------------------------------------
# 0. Resolve target user
# ---------------------------------------------------------------------------
_user="${SUDO_USER:-${USER:-}}"
[[ -n "${_user}" && "${_user}" != "root" ]] \
    || error "70-lab: SUDO_USER/USER must resolve to a non-root user"

# ---------------------------------------------------------------------------
# 1. Docker apt repo — GPG key + deb822 source
# ---------------------------------------------------------------------------
_docker_keyring=/etc/apt/keyrings/docker.asc
_docker_repo_changed=0

if [[ ! -f "${_docker_keyring}" ]]; then
    dry_run_echo "would fetch Docker GPG key → ${_docker_keyring}" || {
        install -d -m 0755 /etc/apt/keyrings
        if curl -fsSL https://download.docker.com/linux/debian/gpg \
                -o "${_docker_keyring}"; then
            chmod 0644 "${_docker_keyring}"
            _docker_repo_changed=1
        else
            warn "Docker GPG key fetch failed — skipping repo install"
            _docker_keyring=""
        fi
    }
fi

if [[ -n "${_docker_keyring}" ]] \
   && ! guard::file_matches_template /etc/apt/sources.list.d/docker.sources \
        "${REPO_ROOT}/templates/etc/apt/sources.list.d/docker.sources"; then
    deploy_template /etc/apt/sources.list.d/docker.sources "Docker apt source (deb822)"
    _docker_repo_changed=1
fi

if [[ "${_docker_repo_changed}" -eq 1 ]]; then
    dry_run_echo "would apt-get update for Docker repo" || apt-get update -qq
fi

# ---------------------------------------------------------------------------
# 2. Docker engine + compose plugin + buildx + containerd
# ---------------------------------------------------------------------------
_docker_packages=(
    docker-ce docker-ce-cli containerd.io
    docker-buildx-plugin docker-compose-plugin
)
_missing_docker=()
for _pkg in "${_docker_packages[@]}"; do
    guard::package_installed "${_pkg}" || _missing_docker+=("${_pkg}")
done
if [[ "${#_missing_docker[@]}" -gt 0 ]]; then
    dry_run_echo "would install Docker packages: ${_missing_docker[*]}" || \
        safe_install "Docker CE + Compose + Buildx" "${_missing_docker[@]}"
fi

# ---------------------------------------------------------------------------
# 3. docker group membership for the target user
# ---------------------------------------------------------------------------
if ! guard::user_in_group "${_user}" docker; then
    dry_run_echo "would add ${_user} to docker group" || \
        usermod -aG docker "${_user}"
fi

# ---------------------------------------------------------------------------
# 4. Enable + start docker.service (the waits-for-srv-data drop-in from
# 20-storage gates the start on /srv/data being mounted)
# ---------------------------------------------------------------------------
if ! guard::service_enabled docker; then
    dry_run_echo "would enable docker.service" || systemctl enable docker
fi
if ! guard::service_active docker; then
    dry_run_echo "would start docker.service" || systemctl start docker
fi

smoke_70_lab() {
    [[ "${DRY_RUN:-0}" == "1" ]] && return 0

    guard::apt_repo_present download.docker.com \
        || { echo "smoke: Docker apt repo not present" >&2; return 1; }
    guard::file_matches_template \
            /etc/apt/sources.list.d/docker.sources \
            "${REPO_ROOT}/templates/etc/apt/sources.list.d/docker.sources" \
        || { echo "smoke: docker.sources does not match template" >&2; return 1; }
    [[ -f /etc/apt/keyrings/docker.asc ]] \
        || { echo "smoke: Docker keyring missing" >&2; return 1; }

    local pkg
    for pkg in docker-ce docker-ce-cli containerd.io \
               docker-buildx-plugin docker-compose-plugin; do
        guard::package_installed "${pkg}" \
            || { echo "smoke: package not installed: ${pkg}" >&2; return 1; }
    done

    guard::user_in_group "${_user}" docker \
        || { echo "smoke: ${_user} is not in the docker group" >&2; return 1; }

    guard::service_enabled docker \
        || { echo "smoke: docker.service not enabled" >&2; return 1; }
    guard::service_active docker \
        || { echo "smoke: docker.service not active" >&2; return 1; }

    # The actual daemon answers — catches the case where the service is
    # "active" but the socket is broken (e.g. data-root path missing).
    docker info >/dev/null 2>&1 \
        || { echo "smoke: 'docker info' failed — daemon unhealthy" >&2; return 1; }

    docker compose version >/dev/null 2>&1 \
        || { echo "smoke: 'docker compose' subcommand missing — compose plugin broken" >&2; return 1; }
}
