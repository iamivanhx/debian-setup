#!/usr/bin/env bash
# shellcheck shell=bash

test_40_os_gate_rejects_non_trixie() {
    local sandbox output rc

    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"

    cat > "${sandbox}/os-release" <<'EOF'
VERSION_CODENAME=bookworm
PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
EOF

    output="$(_OS_RELEASE="${sandbox}/os-release" HOME="${sandbox}/home" "${sandbox}/run.sh" 00-base 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -eq 0 ]]; then
        printf 'expected nonzero exit for non-Trixie os-release, got 0\n'
        printf '%s\n' "${output}"
        return 1
    fi

    if [[ "${output}" != *"Bookworm"* && "${output}" != *"bookworm"* ]]; then
        printf "expected detected distro name 'Bookworm' or 'bookworm' in error output\n"
        printf '%s\n' "${output}"
        return 1
    fi

    return 0
}

test_41_timezone_defaults_to_europe_madrid() {
    local sandbox output rc

    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"

    cat > "${sandbox}/modules/00-base.sh" <<'PROBE'
#!/usr/bin/env bash
# shellcheck shell=bash
step "00-base"
echo "PROBE_TZ=${TIMEZONE:-unset}"
smoke_00_base() { :; }
PROBE

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" 00-base 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected exit 0, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi

    if [[ "${output}" != *"PROBE_TZ=Europe/Madrid"* ]]; then
        printf "expected 'PROBE_TZ=Europe/Madrid' in output\n"
        printf '%s\n' "${output}"
        return 1
    fi

    return 0
}

test_45_smoke_00_base_is_nontrivial() {
    local body compact_body

    body="$(
        awk '
            /^smoke_00_base\(\)[[:space:]]*\{/ { in_fn=1 }
            in_fn { print }
            in_fn && /^[[:space:]]*}[[:space:]]*$/ { exit }
        ' "${REPO_ROOT}/modules/00-base.sh"
    )"

    if [[ -z "${body}" ]]; then
        printf 'smoke_00_base not found in modules/00-base.sh\n'
        return 1
    fi

    compact_body="$(printf '%s' "${body}" | tr -d '[:space:]')"
    if [[ "${compact_body}" == 'smoke_00_base(){:;}' ]]; then
        printf 'smoke_00_base must not be a no-op\n'
        return 1
    fi

    [[ "${body}" == *"backports"* ]] || {
        printf "missing 'backports' check\n"
        return 1
    }

    if [[ "${body}" != *"package"* && "${body}" != *"dpkg"* ]]; then
        printf "missing package check\n"
        return 1
    fi

    [[ "${body}" == *"locale"* ]] || {
        printf "missing 'locale' check\n"
        return 1
    }

    if [[ "${body}" != *"timezone"* && "${body}" != *"Timezone"* ]]; then
        printf "missing timezone check\n"
        return 1
    fi

    return 0
}

test_44_dry_run_exits_zero() {
    local sandbox output rc

    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" --dry-run 00-base 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected exit 0 in dry-run mode, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi

    if [[ "${output}" != *"00-base"* ]]; then
        printf "expected '00-base' step banner in output\n"
        printf '%s\n' "${output}"
        return 1
    fi

    return 0
}

test_43_backports_templates_exist_with_correct_content() {
    local sources_file="${REPO_ROOT}/templates/etc/apt/sources.list.d/backports.list"
    local preferences_file="${REPO_ROOT}/templates/etc/apt/preferences.d/backports"

    if [[ ! -f "${sources_file}" ]]; then
        printf 'file not found: %s\n' "${sources_file}"
        return 1
    fi
    if ! grep -q 'trixie-backports' "${sources_file}"; then
        printf "expected 'trixie-backports' in %s\n" "${sources_file}"
        return 1
    fi
    if ! grep -q 'main contrib non-free-firmware' "${sources_file}"; then
        printf "expected 'main contrib non-free-firmware' in %s\n" "${sources_file}"
        return 1
    fi

    if [[ ! -f "${preferences_file}" ]]; then
        printf 'file not found: %s\n' "${preferences_file}"
        return 1
    fi
    if ! grep -q 'trixie-backports' "${preferences_file}"; then
        printf "expected 'trixie-backports' in %s\n" "${preferences_file}"
        return 1
    fi
    if ! grep -q 'Pin-Priority: 100' "${preferences_file}"; then
        printf "expected 'Pin-Priority: 100' in %s\n" "${preferences_file}"
        return 1
    fi

    return 0
}

test_42_timezone_overridable_via_env() {
    local sandbox output rc

    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"

    cat > "${sandbox}/modules/00-base.sh" <<'PROBE'
#!/usr/bin/env bash
# shellcheck shell=bash
step "00-base"
echo "PROBE_TZ=${TIMEZONE:-unset}"
smoke_00_base() { :; }
PROBE

    output="$(TIMEZONE=America/New_York HOME="${sandbox}/home" "${sandbox}/run.sh" 00-base 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected exit 0, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi

    if [[ "${output}" != *"PROBE_TZ=America/New_York"* ]]; then
        printf "expected 'PROBE_TZ=America/New_York' in output\n"
        printf '%s\n' "${output}"
        return 1
    fi

    return 0
}
