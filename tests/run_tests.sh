#!/usr/bin/env bash
# Minimal test runner: sources every tests/test_*.sh file, each of which defines
# one or more `test_*` functions. Each test function returns 0 on pass, non-zero
# on fail. A sandbox helper (`mk_sandbox`) gives each test an isolated HOME and
# REPO copy so run.sh can be exercised without touching the host.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="${REPO_ROOT}/tests"

PASS=0
FAIL=0
FAILED_NAMES=()

TEST_OUT="$(mktemp)"
trap 'rm -f "${TEST_OUT}"' EXIT

# Create a throwaway sandbox with a fake HOME and a copy of the repo so run.sh
# can source ~/.config/ser8-setup/secrets.env without affecting the real user.
# Echoes the sandbox dir. Caller is expected to `trap "rm -rf $dir" EXIT`.
mk_sandbox() {
    local dir
    dir="$(mktemp -d)"
    mkdir -p "${dir}/home/.config/ser8-setup"
    cp -r "${REPO_ROOT}/run.sh" "${REPO_ROOT}/lib" "${REPO_ROOT}/modules" "${dir}/" 2>/dev/null || true
    cp -r "${REPO_ROOT}/templates" "${dir}/" 2>/dev/null || true
    echo "${dir}"
}

# Initialise a git repo in the current directory with a test identity,
# create lib/ and scripts/, and install the pre-commit hook from the
# given repo root. Must be called from inside the target directory.
# Usage (inside a subshell that has already cd'd into the sandbox):
#   mk_git_sandbox "${REPO_ROOT}"
mk_git_sandbox() {
    local repo_root="$1"
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"
    mkdir -p lib scripts
    cp "${repo_root}/scripts/pre-commit.sh" scripts/pre-commit.sh
    chmod +x scripts/pre-commit.sh
}

# Write a valid stub secrets.env into a sandbox.
write_secrets() {
    local sandbox="$1"
    cat > "${sandbox}/home/.config/ser8-setup/secrets.env" <<'EOF'
# stub secrets for tests
NVME2_LUKS_PASSPHRASE="test-passphrase-not-for-production"
SSH_AUTHORIZED_KEYS="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITESTKEYTESTKEYTESTKEYTESTKEYTESTKEY00 stub@ser8-tests"
EOF
}

run_one() {
    local name="$1"
    if ( set -e; "$name" ) >"${TEST_OUT}" 2>&1; then
        PASS=$((PASS + 1))
        printf '  \033[0;32mPASS\033[0m  %s\n' "$name"
    else
        FAIL=$((FAIL + 1))
        FAILED_NAMES+=("$name")
        printf '  \033[0;31mFAIL\033[0m  %s\n' "$name"
        sed 's/^/        /' "${TEST_OUT}"
    fi
}

shopt -s nullglob
for f in "${TESTS_DIR}"/test_*.sh; do
    printf '\n%s\n' "$(basename "$f")"
    # shellcheck source=/dev/null
    source "$f"
done

# Collect every test_* function defined by the sourced files, in declaration order.
mapfile -t TEST_FUNCS < <(declare -F | awk '$3 ~ /^test_/ {print $3}')

printf '\nRunning %d tests\n' "${#TEST_FUNCS[@]}"
for t in "${TEST_FUNCS[@]}"; do
    run_one "$t"
done

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if (( FAIL > 0 )); then
    exit 1
fi
