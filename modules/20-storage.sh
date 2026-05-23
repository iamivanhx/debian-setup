#!/usr/bin/env bash
# shellcheck shell=bash
# Module: 20-storage

step "20-storage"

# Validate passphrase is set when first-time format is needed
if [[ "${DRY_RUN:-0}" != "1" ]] && guard::command_exists cryptsetup \
        && [[ -b "${NVME2_DEVICE}" ]] && ! cryptsetup isLuks "${NVME2_DEVICE}" 2>/dev/null; then
    [[ -n "${NVME2_LUKS_PASSPHRASE:-}" ]] || \
        error "NVME2_LUKS_PASSPHRASE is empty or unset — required for first-time LUKS format (see docs/install.md)"
fi

# ---------------------------------------------------------------------------
# 1. Install cryptsetup
# ---------------------------------------------------------------------------
if ! guard::package_installed cryptsetup; then
    dry_run_echo "would install cryptsetup" || \
        safe_install "cryptsetup" cryptsetup
fi

# ---------------------------------------------------------------------------
# 2. LUKS format NVMe2
# ---------------------------------------------------------------------------
if ! cryptsetup isLuks "${NVME2_DEVICE}" 2>/dev/null; then
    # SAFE_REPLAY: guarded by cryptsetup isLuks check above
    if ! dry_run_echo "would cryptsetup luksFormat ${NVME2_DEVICE}"; then
        # SAFE_REPLAY: guarded by cryptsetup isLuks check above
        printf '%s' "${NVME2_LUKS_PASSPHRASE:-}" | cryptsetup luksFormat --type luks2 "${NVME2_DEVICE}" - || \
            warn "LUKS format failed — device may not be present yet"
    fi
fi

# ---------------------------------------------------------------------------
# 3. Generate keyfile
# ---------------------------------------------------------------------------
if ! guard::file_exists /etc/luks-keys/srv-data.key; then
    dry_run_echo "would generate keyfile /etc/luks-keys/srv-data.key" || {
        mkdir -p /etc/luks-keys || warn "mkdir /etc/luks-keys failed — insufficient privileges"
        chmod 0700 /etc/luks-keys 2>/dev/null || true
        dd if=/dev/urandom of=/etc/luks-keys/srv-data.key bs=512 count=8 2>/dev/null \
            || warn "dd failed — cannot generate keyfile"
        chmod 0400 /etc/luks-keys/srv-data.key 2>/dev/null || true
        chown root:root /etc/luks-keys/srv-data.key 2>/dev/null || true
    }
fi

# ---------------------------------------------------------------------------
# 4. Add keyfile to LUKS
# ---------------------------------------------------------------------------
if guard::file_exists /etc/luks-keys/srv-data.key && ! cryptsetup open --test-passphrase \
        --key-file /etc/luks-keys/srv-data.key "${NVME2_DEVICE}" --type luks2 2>/dev/null; then
    dry_run_echo "would add keyfile to LUKS header of ${NVME2_DEVICE}" || \
        { printf '%s' "${NVME2_LUKS_PASSPHRASE:-}" | \
            cryptsetup luksAddKey --key-file - "${NVME2_DEVICE}" /etc/luks-keys/srv-data.key \
            || warn "cryptsetup luksAddKey failed"; }
fi

# ---------------------------------------------------------------------------
# 5. crypttab entry
# ---------------------------------------------------------------------------
if ! guard::file_has_line /etc/crypttab '^srv-data[[:space:]]'; then
    dry_run_echo "would add srv-data entry to /etc/crypttab" || {
        _luks_uuid="$(cryptsetup luksUUID "${NVME2_DEVICE}" 2>/dev/null || true)"
        if [[ -n "${_luks_uuid}" ]]; then
            echo "srv-data UUID=${_luks_uuid} /etc/luks-keys/srv-data.key luks,discard" >> /etc/crypttab \
                || warn "failed to write /etc/crypttab"
        else
            warn "cryptsetup luksUUID failed — skipping crypttab entry"
        fi
    }
fi

# ---------------------------------------------------------------------------
# 6. Open LUKS
# ---------------------------------------------------------------------------
if [[ ! -e /dev/mapper/srv-data ]]; then
    # SAFE_REPLAY: guarded by [[ ! -e /dev/mapper/srv-data ]] check above
    dry_run_echo "would cryptsetup open ${NVME2_DEVICE} as srv-data" || \
        { cryptsetup open "${NVME2_DEVICE}" srv-data --key-file /etc/luks-keys/srv-data.key \
            || warn "cryptsetup open failed — device may not be ready"; }
fi

# ---------------------------------------------------------------------------
# 7. mkfs.ext4
# ---------------------------------------------------------------------------
if ! blkid /dev/mapper/srv-data 2>/dev/null | grep -q 'TYPE="ext4"'; then
    # SAFE_REPLAY: guarded by blkid TYPE="ext4" check above
    if ! dry_run_echo "would mkfs.ext4 -L srv-data /dev/mapper/srv-data"; then
        # SAFE_REPLAY: guarded by blkid TYPE="ext4" check above
        mkfs.ext4 -L srv-data /dev/mapper/srv-data || \
            warn "ext4 format failed — mapper device may not be open"
    fi
fi

# ---------------------------------------------------------------------------
# 8. fstab entry
# ---------------------------------------------------------------------------
if ! guard::file_has_line /etc/fstab '^LABEL=srv-data[[:space:]]'; then
    dry_run_echo "would add LABEL=srv-data entry to /etc/fstab" || \
        { echo "LABEL=srv-data /srv/data ext4 defaults,noatime 0 2" >> /etc/fstab \
            || warn "failed to write /etc/fstab"; }
fi

# ---------------------------------------------------------------------------
# 9. Mount
# ---------------------------------------------------------------------------
if ! findmnt /srv/data &>/dev/null; then
    if ! guard::dir_exists /srv/data; then
        dry_run_echo "would create /srv/data mountpoint" || mkdir -p /srv/data 2>/dev/null || true
    fi
    # SAFE_REPLAY: guarded by findmnt check above
    if ! dry_run_echo "would mount /srv/data"; then
        # SAFE_REPLAY: guarded by findmnt check above
        mount /srv/data || warn "mount /srv/data failed — fstab entry may not be present yet"
    fi
fi

# ---------------------------------------------------------------------------
# 10. Directory skeleton (only if /srv/data is actually mounted)
# ---------------------------------------------------------------------------
if findmnt /srv/data &>/dev/null || [[ "${DRY_RUN:-0}" == "1" ]]; then
    for _dir in /srv/data/projects /srv/data/lab/compose /srv/data/docker; do
        if ! guard::dir_exists "${_dir}"; then
            dry_run_echo "would create ${_dir}" || mkdir -p "${_dir}" 2>/dev/null || true
        fi
    done
    # /srv/data/projects is the user's scratch space; root mkdir above leaves it
    # root-owned, so converge ownership to the invoking user every run. (docker
    # is Docker's data-root and lab is repo-managed — both intentionally stay
    # root-owned.)
    _storage_user="${SUDO_USER:-${USER:-}}"
    if [[ -n "${_storage_user}" && "${_storage_user}" != "root" ]]; then
        if dry_run_echo "would chown /srv/data/projects → ${_storage_user}:${_storage_user}"; then
            :
        elif guard::dir_exists /srv/data/projects; then
            chown -R "${_storage_user}:${_storage_user}" /srv/data/projects 2>/dev/null || \
                warn "chown /srv/data/projects failed — insufficient privileges"
        fi
    fi
else
    warn "/srv/data filesystem is not active — skipping directory skeleton creation"
fi

# ---------------------------------------------------------------------------
# 11. Docker daemon.json
# ---------------------------------------------------------------------------
deploy_template /etc/docker/daemon.json "Docker daemon.json (data-root)" \
    || warn "deploy_template /etc/docker/daemon.json failed — insufficient privileges"

# ---------------------------------------------------------------------------
# 12. Docker systemd drop-in
# ---------------------------------------------------------------------------
_dropin_changed=0
if ! guard::file_matches_template \
        /etc/systemd/system/docker.service.d/waits-for-srv-data.conf \
        "${REPO_ROOT}/templates/etc/systemd/system/docker.service.d/waits-for-srv-data.conf"; then
    deploy_template /etc/systemd/system/docker.service.d/waits-for-srv-data.conf \
        "Docker ordering drop-in" \
        || warn "deploy_template waits-for-srv-data.conf failed — insufficient privileges"
    _dropin_changed=1
fi
if [[ "${_dropin_changed}" -eq 1 ]]; then
    dry_run_echo "would systemctl daemon-reload" || \
        { systemctl daemon-reload || warn "systemctl daemon-reload failed"; }
fi

# ---------------------------------------------------------------------------
# 13. Restart dockerd if it's running with a stale DockerRootDir.
# Happens when the docker package postinst started dockerd on the default
# /var/lib/docker BEFORE this module landed daemon.json on a prior interrupted
# run.  daemon-reload above re-reads systemd units but does NOT make dockerd
# re-read /etc/docker/daemon.json — only an actual restart does.  Guarded so it
# only fires on real drift, never on a clean replay.
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN:-0}" != "1" ]] && guard::service_active docker; then
    _docker_root_running="$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || true)"
    if [[ -n "${_docker_root_running}" \
            && "${_docker_root_running}" != "/srv/data/docker" ]]; then
        info "dockerd is running with DockerRootDir='${_docker_root_running}' but daemon.json wants /srv/data/docker — restarting docker.service to apply..."
        # SAFE_REPLAY: guarded by DockerRootDir mismatch check above
        systemctl restart docker || warn "systemctl restart docker failed"
    fi
fi

smoke_20_storage() {
    [[ "${DRY_RUN:-0}" == "1" ]] && return 0

    cryptsetup isLuks "${NVME2_DEVICE}" 2>/dev/null \
        || { echo "smoke: ${NVME2_DEVICE} is not a LUKS device" >&2; return 1; }

    findmnt /srv/data &>/dev/null \
        || { echo "smoke: /srv/data filesystem is not active" >&2; return 1; }

    guard::file_exists /etc/luks-keys/srv-data.key \
        || { echo "smoke: keyfile /etc/luks-keys/srv-data.key does not exist" >&2; return 1; }
    [[ "$(stat -c '%a' /etc/luks-keys/srv-data.key 2>/dev/null)" == "400" ]] \
        || { echo "smoke: keyfile /etc/luks-keys/srv-data.key is not mode 0400" >&2; return 1; }

    guard::file_has_line /etc/crypttab '^srv-data[[:space:]]' \
        || { echo "smoke: /etc/crypttab missing srv-data entry" >&2; return 1; }

    guard::file_has_line /etc/fstab '^LABEL=srv-data[[:space:]]' \
        || { echo "smoke: /etc/fstab missing LABEL=srv-data entry" >&2; return 1; }

    guard::file_matches_template \
            /etc/docker/daemon.json \
            "${REPO_ROOT}/templates/etc/docker/daemon.json" \
        || { echo "smoke: /etc/docker/daemon.json does not match template" >&2; return 1; }

    guard::file_matches_template \
            /etc/systemd/system/docker.service.d/waits-for-srv-data.conf \
            "${REPO_ROOT}/templates/etc/systemd/system/docker.service.d/waits-for-srv-data.conf" \
        || { echo "smoke: waits-for-srv-data.conf does not match template" >&2; return 1; }

    local _dir
    for _dir in /srv/data/projects /srv/data/lab/compose /srv/data/docker; do
        guard::dir_exists "${_dir}" \
            || { echo "smoke: directory ${_dir} does not exist" >&2; return 1; }
    done

    local _smoke_user="${SUDO_USER:-${USER:-}}"
    if [[ -n "${_smoke_user}" && "${_smoke_user}" != "root" ]]; then
        [[ "$(stat -c '%U' /srv/data/projects 2>/dev/null)" == "${_smoke_user}" ]] \
            || { echo "smoke: /srv/data/projects is not owned by ${_smoke_user}" >&2; return 1; }
    fi
}
