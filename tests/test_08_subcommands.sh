#!/usr/bin/env bash
# shellcheck shell=bash

test_08_lint_subcommand_recognized() {
    local sandbox
    local output
    local rc

    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" lint 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected lint to exit 0, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi

    if [[ "${output}" == *"unknown module"* ]]; then
        printf "lint was misrouted to module handler\n%s\n" "${output}"
        return 1
    fi

    return 0
}

test_09_backup_now_recognized() {
    local sandbox
    local output
    local rc

    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" backup now 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected backup now to exit 0, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi

    if [[ "${output}" == *"unknown module"* ]]; then
        printf "backup was misrouted to module handler\n%s\n" "${output}"
        return 1
    fi

    return 0
}

test_10_lab_up_recognized() {
    local sandbox
    local output
    local rc

    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" lab-up whoami 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected lab-up to exit 0, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi

    if [[ "${output}" == *"unknown module"* ]]; then
        printf "lab-up was misrouted to module handler\n%s\n" "${output}"
        return 1
    fi

    return 0
}
