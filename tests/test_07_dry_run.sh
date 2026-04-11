#!/usr/bin/env bash
# shellcheck shell=bash

test_07_dry_run_flag_sets_global() {
    local sandbox
    local output
    local rc

    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"

    cat > "${sandbox}/modules/00-base.sh" <<'PROBE'
#!/usr/bin/env bash
# shellcheck shell=bash
step "00-base"
echo "PROBE_DRY_RUN=${DRY_RUN:-unset}"
smoke_00_base() { :; }
PROBE

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" --dry-run 00-base 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected exit 0, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi

    if [[ "${output}" != *"PROBE_DRY_RUN=1"* ]]; then
        printf "expected 'PROBE_DRY_RUN=1' in output (DRY_RUN should be set to 1 when --dry-run flag is passed)\n"
        printf '%s\n' "${output}"
        return 1
    fi

    return 0
}
