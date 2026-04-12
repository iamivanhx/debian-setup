#!/usr/bin/env bash
# shellcheck shell=bash

test_05_smoke_runs_all_smoke_functions() {
    local sandbox
    local output
    local rc

    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" --dry-run smoke 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected exit 0, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi

    local n
    for n in 00_base 10_hardware 20_storage 30_security 40_desktop 50_shell 60_dev 70_lab 80_backup; do
        if [[ "${output}" != *"smoke_${n}"* ]]; then
            printf "expected 'smoke_%s' pass line in output\n" "${n}"
            printf '%s\n' "${output}"
            return 1
        fi
    done

    return 0
}

test_06_smoke_single_module_runs_only_that() {
    local sandbox
    local output
    local rc

    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" --dry-run smoke 20-storage 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected exit 0, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi

    if [[ "${output}" != *"smoke_20_storage"* ]]; then
        printf "expected 'smoke_20_storage' in output\n"
        printf '%s\n' "${output}"
        return 1
    fi

    if [[ "${output}" == *"smoke_00_base"* ]]; then
        printf "expected 'smoke_00_base' NOT in output when only 20-storage was requested\n"
        printf '%s\n' "${output}"
        return 1
    fi

    return 0
}
