#!/usr/bin/env bash
# shellcheck shell=bash

# C1 — path traversal via module argument must be rejected.
test_20_module_path_traversal_rejected() {
    local sandbox payload_dir output rc
    sandbox="$(mk_sandbox)"
    payload_dir="$(mktemp -d)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}" "${payload_dir}"' RETURN
    write_secrets "${sandbox}"

    mkdir -p "${payload_dir}/evil"
    cat > "${payload_dir}/evil/payload.sh" <<'P'
echo "!!! EVIL EXECUTED !!!"
P

    local rel
    rel="$(realpath --relative-to="${sandbox}/modules" "${payload_dir}/evil/payload")"

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" "${rel}" 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -eq 0 ]]; then
        printf 'expected run.sh to reject path-traversal module arg, got exit 0\n%s\n' "${output}"
        return 1
    fi
    if [[ "${output}" == *"EVIL EXECUTED"* ]]; then
        printf 'path traversal executed the payload\n%s\n' "${output}"
        return 1
    fi
    return 0
}

# C2 — deploy_config backup collisions within one second must not overwrite earlier backups.
test_21_deploy_config_subsecond_backups_preserved() {
    local tmp target
    tmp="$(mktemp -d)"
    trap 'trap - RETURN; rm -rf -- "${tmp}"' RETURN
    target="${tmp}/a.conf"

    bash -c "
        set -euo pipefail
        source '${REPO_ROOT}/lib/common.sh'
        echo v1 | deploy_config '${target}'
        echo v2 | deploy_config '${target}'
        echo v3 | deploy_config '${target}'
    " || {
        printf 'deploy_config calls failed\n'
        return 1
    }

    # Expect at least two distinct backups to survive (v1 and v2).
    local backup_count
    backup_count=$(find "${tmp}" -name 'a.conf.bak.*' | wc -l)
    if (( backup_count < 2 )); then
        printf 'expected >= 2 backups, found %d\n' "${backup_count}"
        ls -la "${tmp}"
        return 1
    fi

    local have_v1=0 have_v2=0 f
    for f in "${tmp}"/a.conf.bak.*; do
        case "$(cat "$f")" in
            v1) have_v1=1 ;;
            v2) have_v2=1 ;;
        esac
    done
    if (( have_v1 == 0 || have_v2 == 0 )); then
        printf 'expected backups for both v1 and v2 to be preserved\n'
        for f in "${tmp}"/a.conf.bak.*; do
            printf '  %s: %s\n' "$f" "$(cat "$f")"
        done
        return 1
    fi
    return 0
}

# C3 — HOME unset must produce a friendly error pointing at docs/install.md, not a raw bash crash.
test_22_home_unset_friendly_error() {
    local sandbox output rc
    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN

    output="$(env -i PATH="${PATH}" "${sandbox}/run.sh" 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -eq 0 ]]; then
        printf 'expected nonzero exit with HOME unset, got 0\n%s\n' "${output}"
        return 1
    fi
    if [[ "${output}" != *"docs/install.md"* ]]; then
        printf "expected 'docs/install.md' in error when HOME unset\n%s\n" "${output}"
        return 1
    fi
    if [[ "${output}" == *"unbound variable"* ]]; then
        printf "got raw 'unbound variable' crash instead of friendly error\n%s\n" "${output}"
        return 1
    fi
    return 0
}

# M1 — --dry-run after a positional argument must be rejected (not silently ignored).
test_23_dry_run_after_module_rejected() {
    local sandbox output rc
    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" 20-storage --dry-run 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -eq 0 ]]; then
        printf 'expected run.sh to reject --dry-run after positional arg, got exit 0\n%s\n' "${output}"
        return 1
    fi
    return 0
}

# M4 — broken secrets.env should fail with a clear error pointing at docs/install.md.
test_24_broken_secrets_env_friendly_error() {
    local sandbox output rc
    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN

    # shellcheck disable=SC2016
    printf 'SOME_VAR=($(\n' > "${sandbox}/home/.config/ser8-setup/secrets.env"

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -eq 0 ]]; then
        printf 'expected nonzero exit on broken secrets.env, got 0\n%s\n' "${output}"
        return 1
    fi
    if [[ "${output}" != *"docs/install.md"* ]]; then
        printf "expected 'docs/install.md' in error for broken secrets.env\n%s\n" "${output}"
        return 1
    fi
    return 0
}
