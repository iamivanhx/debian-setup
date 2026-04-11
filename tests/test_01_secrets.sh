#!/usr/bin/env bash
# shellcheck shell=bash

test_01_missing_secrets_fails_with_install_docs_pointer() {
    local sandbox
    local output
    local rc

    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -eq 0 ]]; then
        printf 'expected nonzero exit, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi

    if [[ "${output}" != *"docs/install.md"* ]]; then
        printf "expected 'docs/install.md' in output\n"
        printf '%s\n' "${output}"
        return 1
    fi

    return 0
}
