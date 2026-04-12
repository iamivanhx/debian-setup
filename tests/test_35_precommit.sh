#!/usr/bin/env bash
# shellcheck shell=bash

test_35_precommit_script_exists() {
    local script
    script="${REPO_ROOT}/scripts/pre-commit.sh"

    if [[ ! -e "${script}" ]]; then
        printf 'expected %s to exist\n' "${script}"
        return 1
    fi

    return 0
}

test_36_precommit_script_is_executable() {
    local script
    script="${REPO_ROOT}/scripts/pre-commit.sh"

    if [[ ! -x "${script}" ]]; then
        printf 'expected %s to be executable\n' "${script}"
        return 1
    fi

    return 0
}

test_37_precommit_script_passes_shellcheck() {
    local script
    local output
    local rc

    script="${REPO_ROOT}/scripts/pre-commit.sh"
    output="$(shellcheck "${script}" 2>&1)" && rc=0 || rc=$?

    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected shellcheck %s to exit 0, got %s\n' "${script}" "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi

    return 0
}

test_38_precommit_clean_tree_exits_zero() {
    local rc
    (
        cd "${REPO_ROOT}" || exit 1
        "${REPO_ROOT}/scripts/pre-commit.sh"
    )
    rc=$?

    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected %s/scripts/pre-commit.sh to exit 0 on a clean working tree, got %s\n' "${REPO_ROOT}" "${rc}"
        return 1
    fi

    return 0
}

test_39_precommit_unguarded_destructive_verb_exits_nonzero() {
    local sandbox output rc

    sandbox="$(mktemp -d)"

    if output="$(
        (
            cd "${sandbox}" || exit 1
            mk_git_sandbox "${REPO_ROOT}"

            cat > lib/bad.sh <<'EOF'
#!/usr/bin/env bash
cp -r /etc /tmp/x
EOF

            git add lib/bad.sh
            ./scripts/pre-commit.sh
        ) 2>&1
    )"; then
        rc=0
    else
        rc=$?
    fi

    if [[ "${rc}" -eq 0 ]]; then
        printf 'expected sandbox pre-commit hook to exit non-zero for staged unguarded destructive verb, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        rm -rf "${sandbox}"
        return 1
    fi

    if ! printf '%s\n' "${output}" | grep -Eq 'cp |destructive|unguarded|reject|blocked'; then
        printf 'expected pre-commit output to mention the destructive pattern, got:\n%s\n' "${output}"
        rm -rf "${sandbox}"
        return 1
    fi

    rm -rf "${sandbox}"
    return 0
}

test_40_precommit_guard_call_passes() {
    local sandbox output rc

    sandbox="$(mktemp -d)"

    if output="$(
        (
            cd "${sandbox}" || exit 1
            mk_git_sandbox "${REPO_ROOT}"

            cat > lib/guarded.sh <<'EOF'
#!/usr/bin/env bash
guard::file_exists /etc && cp -r /etc /tmp/x
EOF

            git add lib/guarded.sh
            ./scripts/pre-commit.sh
        ) 2>&1
    )"; then
        rc=0
    else
        rc=$?
    fi

    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected sandbox pre-commit hook to exit 0 for guarded destructive verb on the same line, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        rm -rf "${sandbox}"
        return 1
    fi

    rm -rf "${sandbox}"
    return 0
}

test_41_precommit_safe_replay_comment_passes() {
    local sandbox output rc

    sandbox="$(mktemp -d)"

    if output="$(
        (
            cd "${sandbox}" || exit 1
            mk_git_sandbox "${REPO_ROOT}"

            cat > lib/safe.sh <<'EOF'
#!/usr/bin/env bash
# SAFE_REPLAY: mount is idempotent with --make-shared
mount --make-shared /
EOF

            git add lib/safe.sh
            ./scripts/pre-commit.sh
        ) 2>&1
    )"; then
        rc=0
    else
        rc=$?
    fi

    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected sandbox pre-commit hook to exit 0 for SAFE_REPLAY destructive verb exemption, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        rm -rf "${sandbox}"
        return 1
    fi

    rm -rf "${sandbox}"
    return 0
}

test_42_precommit_does_not_flag_test_files() {
    local sandbox output rc

    sandbox="$(mktemp -d)"
    trap 'rm -rf "${sandbox}"' RETURN

    if output="$(
        (
            cd "${sandbox}" || exit 1
            mk_git_sandbox "${REPO_ROOT}"
            mkdir -p tests

            cat > lib/clean.sh <<'EOF'
#!/usr/bin/env bash
echo hello
EOF

            cat > tests/test_cleanup.sh <<'EOF'
#!/usr/bin/env bash
rm -rf /tmp/testdir
EOF

            git add lib/clean.sh tests/test_cleanup.sh
            ./scripts/pre-commit.sh
        ) 2>&1
    )"; then
        rc=0
    else
        rc=$?
    fi

    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected sandbox pre-commit hook to ignore destructive verbs in staged test files, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi

    return 0
}

test_43_precommit_guard_comment_does_not_exempt() {
    local sandbox output rc

    sandbox="$(mktemp -d)"
    trap 'rm -rf "${sandbox}"' RETURN

    if output="$(
        (
            cd "${sandbox}" || exit 1
            mk_git_sandbox "${REPO_ROOT}"

            cat > lib/tricky.sh <<'EOF'
#!/usr/bin/env bash
# guard:: this is just a comment mentioning the convention
cp -r /etc /tmp/x
EOF

            git add lib/tricky.sh
            ./scripts/pre-commit.sh
        ) 2>&1
    )"; then
        rc=0
    else
        rc=$?
    fi

    if [[ "${rc}" -eq 0 ]]; then
        printf 'expected sandbox pre-commit hook to reject a destructive verb after a guard:: comment, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi

    return 0
}

test_44_precommit_context_line_does_not_exempt() {
    local sandbox output rc

    sandbox="$(mktemp -d)"
    trap 'rm -rf "${sandbox}"' RETURN

    if output="$(
        (
            cd "${sandbox}" || exit 1
            mk_git_sandbox "${REPO_ROOT}"

            cat > lib/existing.sh <<'EOF'
#!/usr/bin/env bash
guard::file_exists /etc
EOF

            git add lib/existing.sh
            git commit -qm "seed existing guard line"

            cat >> lib/existing.sh <<'EOF'
cp -r /etc /tmp/x
EOF

            git add lib/existing.sh
            ./scripts/pre-commit.sh
        ) 2>&1
    )"; then
        rc=0
    else
        rc=$?
    fi

    if [[ "${rc}" -eq 0 ]]; then
        printf 'expected sandbox pre-commit hook to reject a destructive verb guarded only by a context line, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi

    return 0
}
