#!/usr/bin/env bash
# shellcheck shell=bash
# pre-commit hook — run before every commit to enforce project standards

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_warn() { printf '[WARN]  %s\n' "$*" >&2; }
_error() { printf '[ERROR] %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# 1. Collect staged .sh files under lib/, modules/, or exactly run.sh
# ---------------------------------------------------------------------------
mapfile -t STAGED < <(
    git diff --cached --name-only --diff-filter=ACM \
    | grep -E '^(lib/|modules/|run\.sh$)' \
    | grep -E '\.sh$|^run\.sh$'
)

if [[ "${#STAGED[@]}" -eq 0 ]]; then
    exit 0
fi

FAIL=0

# ---------------------------------------------------------------------------
# 2. shellcheck (skip if unavailable)
# ---------------------------------------------------------------------------
if command -v shellcheck >/dev/null 2>&1; then
    for f in "${STAGED[@]}"; do
        if ! shellcheck -x "${f}" 2>&1; then
            FAIL=1
        fi
    done
else
    _warn "shellcheck not installed — skipping shellcheck"
fi

# ---------------------------------------------------------------------------
# 3. shfmt (skip if unavailable)
# ---------------------------------------------------------------------------
if command -v shfmt >/dev/null 2>&1; then
    for f in "${STAGED[@]}"; do
        if ! shfmt -d "${f}" 2>&1; then
            FAIL=1
        fi
    done
else
    _warn "shfmt not installed — skipping shfmt"
fi

# ---------------------------------------------------------------------------
# 4. Destructive-verb guard check
# ---------------------------------------------------------------------------
# Verbs that must be preceded by a guard:: or # SAFE_REPLAY: annotation.
DESTRUCTIVE_VERBS=(
    'apt install'
    'apt-get install'
    'cryptsetup luksFormat'
    'mkfs'
    'mount'
    'ln -s'
    'cp '
    'systemctl enable'
    'usermod'
    'chsh'
    'rm -rf'
)

# Build a single ERE pattern for all verbs.
VERB_PATTERN=""
for verb in "${DESTRUCTIVE_VERBS[@]}"; do
    if [[ -z "${VERB_PATTERN}" ]]; then
        VERB_PATTERN="${verb}"
    else
        VERB_PATTERN="${VERB_PATTERN}|${verb}"
    fi
done

# Process diff output line by line.
# prev_added_line tracks the most recent added (+) line only; context lines
# and deleted lines reset it so they cannot act as guard exemptions.
prev_added_line=""
current_file=""

while IFS= read -r line; do
    # Track which file we are in; reset prev_added_line on file boundary.
    if [[ "${line}" =~ ^\+\+\+\ b/(.+)$ ]]; then
        current_file="${BASH_REMATCH[1]}"
        prev_added_line=""
        continue
    fi

    # Non-added lines (context, deleted, hunk headers): reset prev_added_line
    # so pre-existing code cannot serve as a guard exemption.
    if [[ ! "${line}" =~ ^\+ || "${line}" =~ ^\+\+\+ ]]; then
        prev_added_line=""
        continue
    fi

    # From here: line starts with + and is not a +++ header.
    # Skip comment lines — they cannot be executed, but still update
    # prev_added_line so the next line can use a # SAFE_REPLAY: annotation.
    stripped="${line:1}"
    stripped="${stripped#"${stripped%%[! ]*}"}"  # ltrim whitespace
    if [[ "${stripped}" == \#* ]]; then
        prev_added_line="${line}"
        continue
    fi

    # Check if the added line contains a destructive verb.
    if printf '%s\n' "${line}" | grep -Eq "${VERB_PATTERN}"; then
        # Determine which verb matched.
        matched_verb=""
        for verb in "${DESTRUCTIVE_VERBS[@]}"; do
            if printf '%s\n' "${line}" | grep -Fq "${verb}"; then
                matched_verb="${verb}"
                break
            fi
        done

        # Pass condition 1: current line contains guard:: on the same added line.
        if printf '%s\n' "${line}" | grep -Fq 'guard::'; then
            prev_added_line="${line}"
            continue
        fi

        # Pass condition 2: previous ADDED line contains guard:: and is NOT a comment.
        if printf '%s\n' "${prev_added_line}" | grep -Fq 'guard::'; then
            prev_stripped="${prev_added_line:1}"
            prev_stripped="${prev_stripped#"${prev_stripped%%[! ]*}"}"  # ltrim whitespace
            if [[ "${prev_stripped}" != \#* ]]; then
                prev_added_line="${line}"
                continue
            fi
        fi

        # Pass condition 3: previous ADDED line has # SAFE_REPLAY: annotation.
        if printf '%s\n' "${prev_added_line}" | grep -Fq '# SAFE_REPLAY:'; then
            prev_added_line="${line}"
            continue
        fi

        _error "unguarded destructive verb detected — blocked"
        _error "  file : ${current_file}"
        _error "  verb : ${matched_verb}"
        _error "  line : ${line#+}"
        _error "Wrap the call with a guard:: function or annotate the preceding"
        _error "line with '# SAFE_REPLAY: <reason>' to suppress this check."
        FAIL=1
    fi

    prev_added_line="${line}"
done < <(git diff --cached -U1 -- "${STAGED[@]}")

# ---------------------------------------------------------------------------
# Exit
# ---------------------------------------------------------------------------
if [[ "${FAIL}" -ne 0 ]]; then
    exit 1
fi

exit 0
