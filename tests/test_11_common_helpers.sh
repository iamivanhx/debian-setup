#!/usr/bin/env bash
# shellcheck shell=bash

# Source lib/common.sh into a subshell and inspect helpers.
_common_sourced_subshell() {
    bash -c "
        set -uo pipefail
        source '${REPO_ROOT}/lib/common.sh'
        $*
    "
}

test_11_common_has_deploy_config() {
    if ! _common_sourced_subshell 'declare -F deploy_config >/dev/null'; then
        printf 'deploy_config not defined in lib/common.sh\n'
        return 1
    fi
}

test_12_common_has_safe_install() {
    if ! _common_sourced_subshell 'declare -F safe_install >/dev/null'; then
        printf 'safe_install not defined in lib/common.sh\n'
        return 1
    fi
}

test_13_common_has_run_as_user() {
    if ! _common_sourced_subshell 'declare -F run_as_user >/dev/null'; then
        printf 'run_as_user not defined in lib/common.sh\n'
        return 1
    fi
}

test_14_deploy_config_writes_and_backs_up() {
    local tmp
    tmp="$(mktemp -d)"
    trap 'trap - RETURN; rm -rf -- "${tmp}"' RETURN

    local target="${tmp}/sub/target.conf"

    # First write — no backup should exist yet.
    bash -c "
        set -euo pipefail
        source '${REPO_ROOT}/lib/common.sh'
        echo 'v1' | deploy_config '${target}'
    " || {
        printf 'first deploy_config failed\n'
        return 1
    }

    if [[ "$(cat "${target}")" != "v1" ]]; then
        printf 'expected target to contain v1, got: %s\n' "$(cat "${target}")"
        return 1
    fi

    # Second write — should create a .bak.* backup of v1.
    bash -c "
        set -euo pipefail
        source '${REPO_ROOT}/lib/common.sh'
        echo 'v2' | deploy_config '${target}'
    " || {
        printf 'second deploy_config failed\n'
        return 1
    }

    if [[ "$(cat "${target}")" != "v2" ]]; then
        printf 'expected target to contain v2 after second write, got: %s\n' "$(cat "${target}")"
        return 1
    fi

    local backups
    backups=( "${tmp}/sub/target.conf.bak."* )
    if [[ ! -f "${backups[0]}" ]]; then
        printf 'expected a .bak.* file after second deploy_config\n'
        ls -la "${tmp}/sub/" >&2
        return 1
    fi

    if [[ "$(cat "${backups[0]}")" != "v1" ]]; then
        printf 'expected backup to contain v1, got: %s\n' "$(cat "${backups[0]}")"
        return 1
    fi

    return 0
}

test_17_deploy_template_empty_dest_errors() {
    local stderr_file
    stderr_file="$(mktemp)"
    trap 'rm -f -- "${stderr_file}"' RETURN

    if bash -c "
        set -euo pipefail
        REPO_ROOT='${REPO_ROOT}'
        source '${REPO_ROOT}/lib/guards.sh'
        source '${REPO_ROOT}/lib/common.sh'
        deploy_template ''
    " >/dev/null 2>"${stderr_file}"; then
        printf 'deploy_template with empty dest should exit non-zero\n'
        return 1
    fi

    if ! grep -qi 'dest' "${stderr_file}"; then
        printf 'expected stderr to mention dest, got: %s\n' "$(cat "${stderr_file}")"
        return 1
    fi
}

test_18_deploy_template_missing_template_errors() {
    local tmp stderr_file dest
    tmp="$(mktemp -d)"
    stderr_file="$(mktemp)"
    trap 'rm -rf -- "${tmp}"; rm -f -- "${stderr_file}"' RETURN
    dest="${tmp}/missing-template.conf"

    if bash -c "
        set -euo pipefail
        REPO_ROOT='${REPO_ROOT}'
        source '${REPO_ROOT}/lib/guards.sh'
        source '${REPO_ROOT}/lib/common.sh'
        deploy_template '${dest}'
    " >/dev/null 2>"${stderr_file}"; then
        printf 'deploy_template with a missing template should exit non-zero\n'
        return 1
    fi

    if ! grep -q '\[ERROR\]' "${stderr_file}"; then
        printf 'expected an [ERROR] message for missing template, got: %s\n' "$(cat "${stderr_file}")"
        return 1
    fi
}
