#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
# shellcheck source=lib/guards.sh
source "${REPO_ROOT}/lib/guards.sh"

SETUP_HOME="${SER8_SETUP_HOME:-}"
if [[ -z "${SETUP_HOME}" && -n "${SUDO_USER:-}" ]]; then
    SETUP_HOME="$(getent passwd "${SUDO_USER}" 2>/dev/null | cut -d: -f6 || true)"
fi
if [[ -z "${SETUP_HOME}" ]]; then
    SETUP_HOME="${HOME:-}"
fi
if [[ -z "${SETUP_HOME}" ]]; then
    error "cannot resolve setup home — set SER8_SETUP_HOME or HOME (see docs/install.md)"
fi

SECRETS_FILE="${SETUP_HOME}/.config/ser8-setup/secrets.env"
if [[ ! -f "${SECRETS_FILE}" ]]; then
    error "secrets.env not found at ${SECRETS_FILE} — see docs/install.md for setup instructions"
fi
if ! bash -n "${SECRETS_FILE}" 2>/dev/null; then
    error "secrets.env at ${SECRETS_FILE} has a syntax error — see docs/install.md"
fi
# shellcheck source=/dev/null
source "${SECRETS_FILE}"

TIMEZONE="${TIMEZONE:-Europe/Madrid}"
export TIMEZONE

POWER_PROFILE="${POWER_PROFILE:-balanced}"
export POWER_PROFILE

NVME2_DEVICE="${NVME2_DEVICE:-/dev/nvme1n1}"
export NVME2_DEVICE

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
    shift
fi
export DRY_RUN

for a in "$@"; do
    case "$a" in
        --*) error "flags must come before the subcommand: got '${a}'" ;;
    esac
done

case "${1:-}" in
    smoke)
        [[ $# -gt 2 ]] && error "too many arguments for smoke"
        # Source all modules so smoke_* functions are defined.
        for f in "${REPO_ROOT}/modules/"*.sh; do
            # shellcheck source=/dev/null
            source "$f"
        done

        if [[ -n "${2:-}" ]]; then
            # Single-module smoke run.
            MODULE_NAME="${2}"
            if [[ ! "${MODULE_NAME}" =~ ^[0-9]+-[a-z][a-z0-9-]*$ ]]; then
                error "invalid module name: ${MODULE_NAME}"
            fi
            MODULE_FILE="${REPO_ROOT}/modules/${MODULE_NAME}.sh"
            if [[ ! -f "${MODULE_FILE}" ]]; then
                error "unknown module: ${MODULE_NAME}"
            fi
            SMOKE_FN="smoke_${MODULE_NAME//-/_}"
            "${SMOKE_FN}"
            info "${SMOKE_FN}: ok"
        else
            # Full smoke run: iterate all modules in sorted order.
            for f in "${REPO_ROOT}/modules/"*.sh; do
                base="$(basename "$f" .sh)"
                SMOKE_FN="smoke_${base//-/_}"
                "${SMOKE_FN}"
                info "${SMOKE_FN}: ok"
            done
        fi
        exit 0
        ;;

    "")
        # Default: run all modules.
        for f in "${REPO_ROOT}/modules/"*.sh; do
            # shellcheck source=/dev/null
            source "$f"
        done
        ;;

    lint)
        [[ $# -gt 1 ]] && error "too many arguments for lint"
        if command -v shellcheck >/dev/null 2>&1; then
            shellcheck -x --source-path="${REPO_ROOT}" \
                "${REPO_ROOT}/run.sh" \
                "${REPO_ROOT}"/lib/*.sh \
                "${REPO_ROOT}"/modules/*.sh
            exit $?
        else
            warn "shellcheck not installed — skipping"
        fi
        exit 0
        ;;

    backup)
        [[ $# -gt 2 ]] && error "too many arguments for backup"
        if [[ "${2:-}" == "now" ]]; then
            info "backup now: not yet implemented (placeholder)"
            exit 0
        else
            error "usage: run.sh backup now"
        fi
        ;;

    lab-up)
        [[ $# -gt 2 ]] && error "too many arguments for lab-up"
        if [[ -z "${2:-}" ]]; then
            error "usage: run.sh lab-up <project>"
        fi
        info "lab-up ${2}: not yet implemented (placeholder)"
        exit 0
        ;;

    *)
        # Single named module.
        [[ $# -gt 1 ]] && error "too many arguments for module invocation"
        MODULE_NAME="${1}"
        if [[ ! "${MODULE_NAME}" =~ ^[0-9]+-[a-z][a-z0-9-]*$ ]]; then
            error "invalid module name: ${MODULE_NAME}"
        fi
        MODULE_FILE="${REPO_ROOT}/modules/${MODULE_NAME}.sh"
        if [[ ! -f "${MODULE_FILE}" ]]; then
            error "unknown module: ${MODULE_NAME}"
        fi
        # shellcheck source=/dev/null
        source "${MODULE_FILE}"
        ;;
esac
