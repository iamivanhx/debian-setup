#!/usr/bin/env bash
# shellcheck shell=bash

test_02_default_run_iterates_all_modules() {
    local sandbox
    local output
    local rc

    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected exit 0, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi

    local m
    for m in 00-base 10-hardware 20-storage 30-security 40-desktop 50-shell 60-dev 70-lab 80-backup; do
        if [[ "${output}" != *"${m}"* ]]; then
            printf "expected module '%s' in output\n" "${m}"
            printf '%s\n' "${output}"
            return 1
        fi
    done

    return 0
}
