#!/usr/bin/env bash
# shellcheck shell=bash

test_03_single_module_runs_only_target() {
    local sandbox
    local output
    local rc

    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" 20-storage 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected exit 0, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi

    if [[ "${output}" != *"20-storage"* ]]; then
        printf "expected '20-storage' in output\n"
        printf '%s\n' "${output}"
        return 1
    fi

    if [[ "${output}" == *"00-base"* ]]; then
        printf "expected '00-base' to NOT be in output when only 20-storage was requested\n"
        printf '%s\n' "${output}"
        return 1
    fi

    return 0
}

test_04_unknown_module_fails() {
    local sandbox
    local output
    local rc

    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" 99-nope 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -eq 0 ]]; then
        printf 'expected nonzero exit for unknown module, got 0\n'
        printf '%s\n' "${output}"
        return 1
    fi

    if [[ "${output}" != *"99-nope"* ]]; then
        printf "expected unknown module name '99-nope' in error output\n"
        printf '%s\n' "${output}"
        return 1
    fi

    return 0
}
