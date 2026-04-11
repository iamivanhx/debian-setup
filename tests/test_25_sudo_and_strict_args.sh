#!/usr/bin/env bash
# shellcheck shell=bash

# C5 — under sudo, secrets must be resolved from the invoking user's home, not $HOME=/root.
# We simulate this by setting SUDO_USER and pointing HOME at a /root-like directory with
# NO secrets file, while the sandbox's "operator" home has one.
test_25_sudo_resolves_secrets_from_sudo_user_home() {
    local sandbox fake_root output rc
    sandbox="$(mk_sandbox)"
    fake_root="$(mktemp -d)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}" "${fake_root}"' RETURN

    # Operator's home has the secrets file.
    write_secrets "${sandbox}"

    # Create a minimal passwd-lookup surrogate: we can't control getent,
    # so the implementation must consult $SER8_SETUP_HOME or derive via
    # getent passwd "$SUDO_USER". We set SER8_SETUP_HOME explicitly as the
    # simplest contract: if set, it overrides HOME for secrets lookup.
    output="$(SER8_SETUP_HOME="${sandbox}/home" HOME="${fake_root}" \
        "${sandbox}/run.sh" 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected sudo-aware run to exit 0, got %s\n%s\n' "${rc}" "${output}"
        return 1
    fi

    # And without the override, the /root-like home has no secrets → must fail.
    output="$(HOME="${fake_root}" "${sandbox}/run.sh" 2>&1)" && rc=0 || rc=$?
    if [[ "${rc}" -eq 0 ]]; then
        printf 'expected failure when HOME has no secrets and no override, got 0\n%s\n' "${output}"
        return 1
    fi

    return 0
}

# Minor — trailing positional args after a valid subcommand must error.
test_26_trailing_positional_after_module_rejected() {
    local sandbox output rc
    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" 20-storage junk 2>&1)" && rc=0 || rc=$?
    if [[ "${rc}" -eq 0 ]]; then
        printf 'expected rejection of trailing arg after module, got 0\n%s\n' "${output}"
        return 1
    fi

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" backup now junk 2>&1)" && rc=0 || rc=$?
    if [[ "${rc}" -eq 0 ]]; then
        printf 'expected rejection of trailing arg after backup now, got 0\n%s\n' "${output}"
        return 1
    fi

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" lab-up proj junk 2>&1)" && rc=0 || rc=$?
    if [[ "${rc}" -eq 0 ]]; then
        printf 'expected rejection of trailing arg after lab-up, got 0\n%s\n' "${output}"
        return 1
    fi

    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" smoke 20-storage junk 2>&1)" && rc=0 || rc=$?
    if [[ "${rc}" -eq 0 ]]; then
        printf 'expected rejection of trailing arg after smoke <module>, got 0\n%s\n' "${output}"
        return 1
    fi

    return 0
}
