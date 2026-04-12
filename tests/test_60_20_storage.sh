#!/usr/bin/env bash
# shellcheck shell=bash

test_60_nvme2_device_defaults_to_nvme1n1() {
    local sandbox output rc
    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"
    cat > "${sandbox}/modules/20-storage.sh" <<'PROBE'
#!/usr/bin/env bash
# shellcheck shell=bash
step "20-storage"
echo "PROBE_NVME2=${NVME2_DEVICE:-unset}"
smoke_20_storage() { :; }
PROBE
    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" 20-storage 2>&1)" && rc=0 || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected exit 0, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi
    if [[ "${output}" != *"PROBE_NVME2=/dev/nvme1n1"* ]]; then
        printf "expected 'PROBE_NVME2=/dev/nvme1n1' in output\n"
        printf '%s\n' "${output}"
        return 1
    fi
    return 0
}

test_60b_nvme2_device_overridable_via_env() {
    local sandbox output rc
    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"
    cat > "${sandbox}/modules/20-storage.sh" <<'PROBE'
#!/usr/bin/env bash
# shellcheck shell=bash
step "20-storage"
echo "PROBE_NVME2=${NVME2_DEVICE:-unset}"
smoke_20_storage() { :; }
PROBE
    output="$(NVME2_DEVICE=/dev/loop99 HOME="${sandbox}/home" "${sandbox}/run.sh" 20-storage 2>&1)" && rc=0 || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected exit 0, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi
    if [[ "${output}" != *"PROBE_NVME2=/dev/loop99"* ]]; then
        printf "expected 'PROBE_NVME2=/dev/loop99' in output\n"
        printf '%s\n' "${output}"
        return 1
    fi
    return 0
}

test_61_docker_daemon_json_template_exists_with_correct_content() {
    local template_file="${REPO_ROOT}/templates/etc/docker/daemon.json"
    if [[ ! -f "${template_file}" ]]; then
        printf 'file not found: %s\n' "${template_file}"
        return 1
    fi
    if ! grep -Fq '"data-root"' "${template_file}"; then
        printf "expected '\"data-root\"' in %s\n" "${template_file}"
        return 1
    fi
    if ! grep -Fq '/srv/data/docker' "${template_file}"; then
        printf "expected '/srv/data/docker' in %s\n" "${template_file}"
        return 1
    fi
    return 0
}

test_61b_docker_dropin_template_exists_with_correct_content() {
    local template_file="${REPO_ROOT}/templates/etc/systemd/system/docker.service.d/waits-for-srv-data.conf"
    if [[ ! -f "${template_file}" ]]; then
        printf 'file not found: %s\n' "${template_file}"
        return 1
    fi
    if ! grep -Fq 'RequiresMountsFor=/srv/data' "${template_file}"; then
        printf "expected 'RequiresMountsFor=/srv/data' in %s\n" "${template_file}"
        return 1
    fi
    if ! grep -Fq 'After=srv-data.mount' "${template_file}"; then
        printf "expected 'After=srv-data.mount' in %s\n" "${template_file}"
        return 1
    fi
    return 0
}

test_62_dry_run_20_storage_exits_zero() {
    local sandbox output rc
    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"
    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" --dry-run 20-storage 2>&1)" && rc=0 || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected exit 0 in dry-run mode, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi
    if [[ "${output}" != *"20-storage"* ]]; then
        printf "expected '20-storage' step banner in output\n"
        printf '%s\n' "${output}"
        return 1
    fi
    if [[ "${output}" != *"dry-run"* ]]; then
        printf "expected 'dry-run' in output\n"
        printf '%s\n' "${output}"
        return 1
    fi
    if [[ "${output}" != *"luksFormat"* ]]; then
        printf "expected 'luksFormat' in output\n"
        printf '%s\n' "${output}"
        return 1
    fi
    if [[ "${output}" != *"mkfs"* ]]; then
        printf "expected 'mkfs' in output\n"
        printf '%s\n' "${output}"
        return 1
    fi
    if [[ "${output}" != *"daemon.json"* ]]; then
        printf "expected 'daemon.json' in output\n"
        printf '%s\n' "${output}"
        return 1
    fi
    return 0
}

test_63_smoke_20_storage_is_nontrivial() {
    local body compact_body

    body="$(
        awk '
            /^smoke_20_storage\(\)[[:space:]]*\{/ { in_fn=1 }
            in_fn { print }
            in_fn && /^[[:space:]]*}[[:space:]]*$/ { exit }
        ' "${REPO_ROOT}/modules/20-storage.sh"
    )"

    if [[ -z "${body}" ]]; then
        printf 'smoke_20_storage not found in modules/20-storage.sh\n'
        return 1
    fi

    compact_body="$(printf '%s' "${body}" | tr -d '[:space:]')"
    if [[ "${compact_body}" == 'smoke_20_storage(){:;}' ]]; then
        printf 'smoke_20_storage must not be a no-op\n'
        return 1
    fi

    if [[ "${body}" != *"isLuks"* && "${body}" != *"cryptsetup"* ]]; then
        printf "missing LUKS check\n"
        return 1
    fi

    if [[ "${body}" != *"/srv/data"* && "${body}" != *"findmnt"* && "${body}" != *"mountpoint"* ]]; then
        printf "missing mountpoint check\n"
        return 1
    fi

    if [[ "${body}" != *"luks-keys"* && "${body}" != *"srv-data.key"* ]]; then
        printf "missing keyfile check\n"
        return 1
    fi

    if [[ "${body}" != *"crypttab"* ]]; then
        printf "missing crypttab check\n"
        return 1
    fi

    if [[ "${body}" != *"fstab"* ]]; then
        printf "missing fstab check\n"
        return 1
    fi

    if [[ "${body}" != *"daemon.json"* ]]; then
        printf "missing daemon.json check\n"
        return 1
    fi

    if [[ "${body}" != *"waits-for-srv-data"* && "${body}" != *"drop-in"* ]]; then
        printf "missing drop-in check\n"
        return 1
    fi

    return 0
}

test_64_docs_install_documents_nvme2_passphrase() {
    local doc="${REPO_ROOT}/docs/install.md"
    if [[ ! -f "${doc}" ]]; then
        printf 'docs/install.md not found\n'
        return 1
    fi
    if ! grep -qi 'nvme2' "${doc}"; then
        printf "expected NVMe2 reference in docs/install.md\n"
        return 1
    fi
    if ! grep -qi '20-storage' "${doc}"; then
        printf "expected 20-storage reference in docs/install.md\n"
        return 1
    fi
    if ! grep -qi 'NVME2_LUKS_PASSPHRASE' "${doc}"; then
        printf "expected NVME2_LUKS_PASSPHRASE reference in docs/install.md\n"
        return 1
    fi
    return 0
}
