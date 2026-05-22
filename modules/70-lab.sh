#!/usr/bin/env bash
# shellcheck shell=bash
# Module: 70-lab — Docker CE + Traefik + Avahi + whoami reference project.
#
# Scope (per issue #15):
#   a) Docker CE engine + Compose + buildx from docker.com's apt repo.
#   b) Avahi daemon + vendored avahi-aliases CNAME publisher (lib/avahi-aliases/),
#      systemd .service + .path units that re-publish on /etc/avahi/aliases edits.
#   c) Traefik v3 + whoami compose stacks under /srv/data/lab/compose/, attached
#      to the external traefik-proxy network. whoami.local is added to the
#      aliases file so it resolves on the LAN and Traefik routes Host(`whoami.local`).
#
# 20-storage already lands /etc/docker/daemon.json (data-root → /srv/data/docker)
# and a docker.service drop-in that waits for /srv/data to mount, so Docker comes
# up pointing at the encrypted volume from first start.

step "70-lab"

# ---------------------------------------------------------------------------
# 0. Resolve target user
# ---------------------------------------------------------------------------
_user="${SUDO_USER:-${USER:-}}"
[[ -n "${_user}" && "${_user}" != "root" ]] \
    || error "70-lab: SUDO_USER/USER must resolve to a non-root user"

# ===========================================================================
# 70-lab-a  Docker CE + Compose plugin
# ===========================================================================

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

# ---------------------------------------------------------------------------
# 5. Verify daemon.json data-root from 20-storage is actually in effect.
# Catches the case where 20-storage didn't land the drop-in but docker is
# already running on /var/lib/docker — would silently fill the system disk.
# Also catches the case where docker.service failed to start at all — the
# rest of this module (avahi alias for whoami.local, traefik-proxy network,
# compose stacks) would otherwise half-converge against a dead daemon.
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN:-0}" != "1" ]]; then
    guard::service_active docker \
        || error "70-lab: docker.service is not active after enable+start — refusing to proceed. Check 'journalctl -u docker.service' and 20-storage's daemon.json drop-in."
    _docker_root="$(docker info --format '{{.DockerRootDir}}' 2>/dev/null)"
    if [[ "${_docker_root}" != "/srv/data/docker" ]]; then
        error "70-lab: docker info reports DockerRootDir='${_docker_root:-<empty>}' (want /srv/data/docker) — 20-storage daemon.json drop-in did not land. Investigate before proceeding."
    fi
fi

# ===========================================================================
# 70-lab-b  Avahi + vendored avahi-aliases CNAME publisher
# ===========================================================================

# ---------------------------------------------------------------------------
# 6. avahi-daemon, avahi-utils, python3-dbus + python3-gi for the publisher
# ---------------------------------------------------------------------------
_avahi_packages=(
    avahi-daemon avahi-utils libnss-mdns
    python3-dbus python3-gi gir1.2-glib-2.0
)
_missing_avahi=()
for _pkg in "${_avahi_packages[@]}"; do
    guard::package_installed "${_pkg}" || _missing_avahi+=("${_pkg}")
done
if [[ "${#_missing_avahi[@]}" -gt 0 ]]; then
    dry_run_echo "would install avahi + python deps: ${_missing_avahi[*]}" || \
        safe_install "avahi + python deps" "${_missing_avahi[@]}"
fi

# ---------------------------------------------------------------------------
# 7. Install vendored avahi-aliases binary → /usr/local/sbin/avahi-aliases
# ---------------------------------------------------------------------------
_vendored_avahi_aliases="${REPO_ROOT}/lib/avahi-aliases/avahi-aliases"
_avahi_binary_changed=0
if ! guard::file_matches_template /usr/local/sbin/avahi-aliases \
        "${_vendored_avahi_aliases}"; then
    _avahi_binary_changed=1
    dry_run_echo "would install ${_vendored_avahi_aliases} → /usr/local/sbin/avahi-aliases" || \
        install -m 0755 "${_vendored_avahi_aliases}" /usr/local/sbin/avahi-aliases
fi

# ---------------------------------------------------------------------------
# 8. /etc/avahi/aliases (empty file gets created — module 70-lab-c later
# appends whoami.local)
# ---------------------------------------------------------------------------
if ! guard::file_exists /etc/avahi/aliases; then
    dry_run_echo "would create /etc/avahi/aliases" || {
        install -d -m 0755 /etc/avahi
        : > /etc/avahi/aliases
    }
fi

# ---------------------------------------------------------------------------
# 9. systemd units for the alias publisher (service + path + restart helper)
# ---------------------------------------------------------------------------
_avahi_units_changed=0
for _unit in avahi-aliases.service avahi-aliases.path avahi-aliases-restart.service; do
    if ! guard::file_matches_template "/etc/systemd/system/${_unit}" \
            "${REPO_ROOT}/templates/etc/systemd/system/${_unit}"; then
        deploy_template "/etc/systemd/system/${_unit}" "avahi-aliases unit (${_unit})"
        _avahi_units_changed=1
    fi
done

if [[ "${_avahi_units_changed}" -eq 1 ]]; then
    dry_run_echo "would systemctl daemon-reload" || systemctl daemon-reload
fi

# ---------------------------------------------------------------------------
# 10. Enable + start avahi-daemon, avahi-aliases, avahi-aliases.path
# ---------------------------------------------------------------------------
for _svc in avahi-daemon.service avahi-aliases.service avahi-aliases.path; do
    if ! guard::service_enabled "${_svc}"; then
        # SAFE_REPLAY: guarded by guard::service_enabled above
        dry_run_echo "would systemctl enable ${_svc}" || systemctl enable "${_svc}"
    fi
    if ! guard::service_active "${_svc}"; then
        dry_run_echo "would systemctl start ${_svc}" || systemctl start "${_svc}"
    fi
done

# Restart the publisher when either the vendored binary OR the .service unit
# template changed. daemon-reload above picks up the new unit file on disk,
# but the running process keeps its old ExecStart + sandbox config until
# explicitly restarted — same idempotency shape for both inputs.
if { [[ "${_avahi_binary_changed}" -eq 1 ]] || [[ "${_avahi_units_changed}" -eq 1 ]]; } \
        && guard::service_active avahi-aliases.service; then
    dry_run_echo "would systemctl try-restart avahi-aliases.service (binary or unit updated)" \
        || systemctl try-restart avahi-aliases.service
fi

# ===========================================================================
# 70-lab-c  Traefik + whoami reference project
# ===========================================================================

# ---------------------------------------------------------------------------
# 11. Docker external network for Traefik ↔ project containers
# ---------------------------------------------------------------------------
if ! guard::docker_network_exists traefik-proxy; then
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        dry_run_echo "would docker network create traefik-proxy"
    elif guard::service_active docker; then
        # SAFE_REPLAY: guarded by guard::docker_network_exists above
        docker network create traefik-proxy >/dev/null \
            || warn "docker network create traefik-proxy failed"
    fi
fi

# ---------------------------------------------------------------------------
# 12. Deploy Traefik + whoami compose files into /srv/data/lab/compose/
# ---------------------------------------------------------------------------
for _project in traefik whoami; do
    _compose_dir="/srv/data/lab/compose/${_project}"
    if ! guard::dir_exists "${_compose_dir}"; then
        dry_run_echo "would mkdir ${_compose_dir}" || install -d -m 0755 "${_compose_dir}"
    fi
    deploy_template "${_compose_dir}/docker-compose.yml" "${_project} compose file"
done

# ---------------------------------------------------------------------------
# 13. Bring up the Traefik + whoami stacks. `docker compose up -d` is itself
# idempotent: it diffs the running container against the compose spec and
# recreates only on drift — so we always invoke it. In dry-run, announce only
# when convergence would do something (container missing OR compose file on
# disk differs from the template that step 12 would deploy).
# ---------------------------------------------------------------------------
for _project in traefik whoami; do
    _compose_file="/srv/data/lab/compose/${_project}/docker-compose.yml"
    _compose_template="${REPO_ROOT}/templates${_compose_file}"
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        if ! guard::container_running "${_project}" \
                || ! guard::file_matches_template "${_compose_file}" "${_compose_template}"; then
            dry_run_echo "would docker compose -f ${_compose_file} up -d (${_project})"
        fi
        continue
    fi
    guard::service_active docker || continue
    # SAFE_REPLAY: docker compose up -d is idempotent (recreates on spec drift, no-op when in sync).
    docker compose -f "${_compose_file}" up -d \
        || warn "docker compose up -d failed for ${_project}"
done

# ---------------------------------------------------------------------------
# 14. Register whoami.local with avahi-aliases — the .path unit picks up the
# change within ~5s and the alias publisher republishes.
# ---------------------------------------------------------------------------
if ! guard::file_has_line /etc/avahi/aliases '^whoami\.local$'; then
    dry_run_echo "would append whoami.local to /etc/avahi/aliases" || \
        printf 'whoami.local\n' >> /etc/avahi/aliases
fi

# ===========================================================================
# Smoke test — full deep-scope acceptance probe
# ===========================================================================
smoke_70_lab() {
    [[ "${DRY_RUN:-0}" == "1" ]] && return 0

    # --- 70-lab-a: Docker ---------------------------------------------------
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

    docker info >/dev/null 2>&1 \
        || { echo "smoke: 'docker info' failed — daemon unhealthy" >&2; return 1; }
    local docker_root
    docker_root="$(docker info --format '{{.DockerRootDir}}' 2>/dev/null)"
    [[ "${docker_root}" == "/srv/data/docker" ]] \
        || { echo "smoke: docker info reports DockerRootDir='${docker_root:-<empty>}' (want /srv/data/docker)" >&2; return 1; }
    docker compose version >/dev/null 2>&1 \
        || { echo "smoke: 'docker compose' subcommand missing — compose plugin broken" >&2; return 1; }

    # --- 70-lab-b: Avahi + aliases publisher --------------------------------
    for pkg in avahi-daemon avahi-utils libnss-mdns python3-dbus python3-gi; do
        guard::package_installed "${pkg}" \
            || { echo "smoke: package not installed: ${pkg}" >&2; return 1; }
    done

    [[ -x /usr/local/sbin/avahi-aliases ]] \
        || { echo "smoke: /usr/local/sbin/avahi-aliases missing or not executable" >&2; return 1; }
    guard::file_matches_template /usr/local/sbin/avahi-aliases \
            "${REPO_ROOT}/lib/avahi-aliases/avahi-aliases" \
        || { echo "smoke: installed avahi-aliases differs from vendored copy" >&2; return 1; }

    local unit
    for unit in avahi-aliases.service avahi-aliases.path avahi-aliases-restart.service; do
        guard::file_matches_template "/etc/systemd/system/${unit}" \
                "${REPO_ROOT}/templates/etc/systemd/system/${unit}" \
            || { echo "smoke: ${unit} does not match template" >&2; return 1; }
    done

    for unit in avahi-daemon.service avahi-aliases.service avahi-aliases.path; do
        guard::service_enabled "${unit}" \
            || { echo "smoke: ${unit} not enabled" >&2; return 1; }
        guard::service_active "${unit}" \
            || { echo "smoke: ${unit} not active" >&2; return 1; }
    done

    [[ -f /etc/avahi/aliases ]] \
        || { echo "smoke: /etc/avahi/aliases missing" >&2; return 1; }
    guard::file_has_line /etc/avahi/aliases '^whoami\.local$' \
        || { echo "smoke: whoami.local missing from /etc/avahi/aliases" >&2; return 1; }

    # --- 70-lab-c: Traefik + whoami -----------------------------------------
    guard::docker_network_exists traefik-proxy \
        || { echo "smoke: docker network traefik-proxy missing" >&2; return 1; }

    local project
    for project in traefik whoami; do
        guard::file_matches_template \
                "/srv/data/lab/compose/${project}/docker-compose.yml" \
                "${REPO_ROOT}/templates/srv/data/lab/compose/${project}/docker-compose.yml" \
            || { echo "smoke: ${project} compose file does not match template" >&2; return 1; }
        guard::container_running "${project}" \
            || { echo "smoke: ${project} container not running" >&2; return 1; }
    done

    # Functional probe: mDNS resolution (libnss-mdns wires nsswitch on install)
    # + HTTP routing through Traefik. The curl path has a small retry window
    # because on first converge Traefik needs ~1–3s to bind 127.0.0.1:80 and
    # ingest Docker labels before the Host(`whoami.local`) router fires.
    local attempt
    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        getent hosts whoami.local >/dev/null 2>&1 && break
        sleep 1
    done
    getent hosts whoami.local >/dev/null 2>&1 \
        || { echo "smoke: getent hosts whoami.local did not resolve after ${attempt}s (libnss-mdns installed?)" >&2; return 1; }

    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        curl -sf -o /dev/null -H 'Host: whoami.local' http://127.0.0.1/ && break
        sleep 1
    done
    curl -sf -o /dev/null -H 'Host: whoami.local' http://127.0.0.1/ \
        || { echo "smoke: curl -H 'Host: whoami.local' http://127.0.0.1 did not return 2xx within ${attempt}s" >&2; return 1; }
}
