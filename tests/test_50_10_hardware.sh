#!/usr/bin/env bash
# shellcheck shell=bash

test_50_kernel_backports_template_exists_with_correct_content() {
    local template_file="${REPO_ROOT}/templates/etc/apt/preferences.d/kernel-backports"

    if [[ ! -f "${template_file}" ]]; then
        printf 'file not found: %s\n' "${template_file}"
        return 1
    fi
    if ! grep -Fq 'linux-image-*' "${template_file}"; then
        printf "expected 'linux-image-*' in %s\n" "${template_file}"
        return 1
    fi
    if ! grep -Fq 'linux-headers-*' "${template_file}"; then
        printf "expected 'linux-headers-*' in %s\n" "${template_file}"
        return 1
    fi
    if ! grep -q 'trixie-backports' "${template_file}"; then
        printf "expected 'trixie-backports' in %s\n" "${template_file}"
        return 1
    fi
    if ! grep -q 'Pin-Priority: 900' "${template_file}"; then
        printf "expected 'Pin-Priority: 900' in %s\n" "${template_file}"
        return 1
    fi

    return 0
}

test_51_firmware_amd_backports_template_exists_with_correct_content() {
    local template_file="${REPO_ROOT}/templates/etc/apt/preferences.d/firmware-amd-backports"
    if [[ ! -f "${template_file}" ]]; then
        printf 'file not found: %s\n' "${template_file}"
        return 1
    fi
    if ! grep -Fq 'firmware-amd-graphics' "${template_file}"; then
        printf "expected 'firmware-amd-graphics' in %s\n" "${template_file}"
        return 1
    fi
    if ! grep -q 'trixie-backports' "${template_file}"; then
        printf "expected 'trixie-backports' in %s\n" "${template_file}"
        return 1
    fi
    if ! grep -q 'Pin-Priority: 900' "${template_file}"; then
        printf "expected 'Pin-Priority: 900' in %s\n" "${template_file}"
        return 1
    fi
    return 0
}

test_52_nvme_udev_rule_template_exists_with_correct_content() {
    local template_file="${REPO_ROOT}/templates/etc/udev/rules.d/60-nvme-scheduler.rules"
    if [[ ! -f "${template_file}" ]]; then
        printf 'file not found: %s\n' "${template_file}"
        return 1
    fi
    if ! grep -Fq 'KERNEL=="nvme[0-9]*"' "${template_file}"; then
        printf "expected 'KERNEL==\"nvme[0-9]*\"' in %s\n" "${template_file}"
        return 1
    fi
    if ! grep -Fq 'scheduler' "${template_file}"; then
        printf "expected 'scheduler' in %s\n" "${template_file}"
        return 1
    fi
    if ! grep -Fq 'none' "${template_file}"; then
        printf "expected 'none' in %s\n" "${template_file}"
        return 1
    fi
    if ! grep -Fq 'power/control' "${template_file}"; then
        printf "expected 'power/control' in %s\n" "${template_file}"
        return 1
    fi
    return 0
}

test_53_power_profile_defaults_to_balanced() {
    local sandbox output rc
    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"
    cat > "${sandbox}/modules/10-hardware.sh" <<'PROBE'
#!/usr/bin/env bash
# shellcheck shell=bash
step "10-hardware"
echo "PROBE_PP=${POWER_PROFILE:-unset}"
smoke_10_hardware() { :; }
PROBE
    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" 10-hardware 2>&1)" && rc=0 || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected exit 0, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi
    if [[ "${output}" != *"PROBE_PP=balanced"* ]]; then
        printf "expected 'PROBE_PP=balanced' in output\n"
        printf '%s\n' "${output}"
        return 1
    fi
    return 0
}

test_53b_power_profile_overridable_via_env() {
    local sandbox output rc
    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"
    cat > "${sandbox}/modules/10-hardware.sh" <<'PROBE'
#!/usr/bin/env bash
# shellcheck shell=bash
step "10-hardware"
echo "PROBE_PP=${POWER_PROFILE:-unset}"
smoke_10_hardware() { :; }
PROBE
    output="$(POWER_PROFILE=performance HOME="${sandbox}/home" "${sandbox}/run.sh" 10-hardware 2>&1)" && rc=0 || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected exit 0, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi
    if [[ "${output}" != *"PROBE_PP=performance"* ]]; then
        printf "expected 'PROBE_PP=performance' in output\n"
        printf '%s\n' "${output}"
        return 1
    fi
    return 0
}

test_54_dry_run_10_hardware_exits_zero() {
    local sandbox output rc
    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"
    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" --dry-run 10-hardware 2>&1)" && rc=0 || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected exit 0 in dry-run mode, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi
    if [[ "${output}" != *"10-hardware"* ]]; then
        printf "expected '10-hardware' step banner in output\n"
        printf '%s\n' "${output}"
        return 1
    fi
    if [[ "${output}" != *"dry-run"* ]]; then
        printf "expected 'dry-run' in output\n"
        printf '%s\n' "${output}"
        return 1
    fi
    return 0
}

test_55_smoke_10_hardware_is_nontrivial() {
    local body compact_body

    body="$(
        awk '
            /^smoke_10_hardware\(\)[[:space:]]*\{/ { in_fn=1 }
            in_fn { print }
            in_fn && /^[[:space:]]*}[[:space:]]*$/ { exit }
        ' "${REPO_ROOT}/modules/10-hardware.sh"
    )"

    if [[ -z "${body}" ]]; then
        printf 'smoke_10_hardware not found in modules/10-hardware.sh\n'
        return 1
    fi

    compact_body="$(printf '%s' "${body}" | tr -d '[:space:]')"
    if [[ "${compact_body}" == 'smoke_10_hardware(){:;}' ]]; then
        printf 'smoke_10_hardware must not be a no-op\n'
        return 1
    fi

    if [[ "${body}" != *"kernel"* && "${body}" != *"linux-image"* ]]; then
        printf "missing kernel check\n"
        return 1
    fi

    if [[ "${body}" != *"package"* && "${body}" != *"dpkg"* ]]; then
        printf "missing package check\n"
        return 1
    fi

    if [[ "${body}" != *"udev"* && "${body}" != *"nvme"* && "${body}" != *"60-nvme"* ]]; then
        printf "missing NVMe udev rule check\n"
        return 1
    fi

    if [[ "${body}" != *"power-profiles-daemon"* && "${body}" != *"power_profiles"* ]]; then
        printf "missing power daemon check\n"
        return 1
    fi

    if [[ "${body}" != *"POWER_PROFILE"* && "${body}" != *"powerprofilesctl"* ]]; then
        printf "missing power profile check\n"
        return 1
    fi

    return 0
}
