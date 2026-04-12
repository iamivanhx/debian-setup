#!/usr/bin/env bash
# shellcheck shell=bash
# Module: 10-hardware

step "10-hardware"

# ---------------------------------------------------------------------------
# 1. Backports kernel pinning
# ---------------------------------------------------------------------------
deploy_template /etc/apt/preferences.d/kernel-backports "kernel backports pin"

# ---------------------------------------------------------------------------
# 2. AMD firmware backports pinning
# ---------------------------------------------------------------------------
deploy_template /etc/apt/preferences.d/firmware-amd-backports "AMD firmware backports pin"

# ---------------------------------------------------------------------------
# 3. NVMe scheduler udev rule + legacy cleanup + conditional reload
# ---------------------------------------------------------------------------
_udev_changed=0

if ! guard::file_matches_template /etc/udev/rules.d/60-nvme-scheduler.rules \
        "${REPO_ROOT}/templates/etc/udev/rules.d/60-nvme-scheduler.rules"; then
    deploy_template /etc/udev/rules.d/60-nvme-scheduler.rules "NVMe I/O scheduler udev rule"
    _udev_changed=1
fi

# Remove legacy rule BEFORE reloading so stale rules are not loaded
if guard::file_exists /etc/udev/rules.d/60-nvme-ioscheduler.rules; then
    dry_run_echo "would remove legacy /etc/udev/rules.d/60-nvme-ioscheduler.rules" || \
        rm -f /etc/udev/rules.d/60-nvme-ioscheduler.rules
    _udev_changed=1
fi

if [[ "${_udev_changed}" -eq 1 ]]; then
    dry_run_echo "would reload udev rules (udevadm control --reload-rules && udevadm trigger)" || \
        { udevadm control --reload-rules && udevadm trigger; }
fi

# ---------------------------------------------------------------------------
# 4a. Backports-pinned packages — install or upgrade to backports version
# ---------------------------------------------------------------------------
_backports_packages=(linux-image-amd64 firmware-amd-graphics)
_need_backports=()
for _pkg in "${_backports_packages[@]}"; do
    if ! guard::package_installed "${_pkg}"; then
        _need_backports+=("${_pkg}")
    elif ! apt-cache policy "${_pkg}" 2>/dev/null | grep -A1 ' \*\*\*' | grep -q 'trixie-backports'; then
        _need_backports+=("${_pkg}")
    fi
done
if [[ "${#_need_backports[@]}" -gt 0 ]]; then
    dry_run_echo "would install/upgrade backports-pinned packages: ${_need_backports[*]}" || \
        safe_install "backports hardware packages" "${_need_backports[@]}"
fi

# ---------------------------------------------------------------------------
# 4b. Regular hardware packages
# ---------------------------------------------------------------------------
_regular_packages=(amd64-microcode fwupd power-profiles-daemon)
_missing_regular=()
for _pkg in "${_regular_packages[@]}"; do
    if ! guard::package_installed "${_pkg}"; then
        _missing_regular+=("${_pkg}")
    fi
done
if [[ "${#_missing_regular[@]}" -gt 0 ]]; then
    dry_run_echo "would install missing hardware packages: ${_missing_regular[*]}" || \
        safe_install "hardware packages" "${_missing_regular[@]}"
fi

# ---------------------------------------------------------------------------
# 5. Enable fwupd.service
# ---------------------------------------------------------------------------
if ! guard::service_enabled fwupd; then
    # SAFE_REPLAY: guarded by guard::service_enabled above
    dry_run_echo "would enable fwupd.service" || systemctl enable fwupd
fi

# ---------------------------------------------------------------------------
# 6. Enable and start power-profiles-daemon
# ---------------------------------------------------------------------------
if ! guard::service_enabled power-profiles-daemon; then
    # SAFE_REPLAY: guarded by guard::service_enabled above
    dry_run_echo "would enable power-profiles-daemon.service" || systemctl enable power-profiles-daemon
fi

if ! guard::service_active power-profiles-daemon; then
    dry_run_echo "would start power-profiles-daemon.service" || \
        systemctl start power-profiles-daemon
fi

# ---------------------------------------------------------------------------
# 7. Set power profile
# ---------------------------------------------------------------------------
case "${POWER_PROFILE}" in
    balanced|performance|power-saver) ;;
    *) error "invalid POWER_PROFILE '${POWER_PROFILE}' — must be balanced, performance, or power-saver" ;;
esac

_current_profile="$(powerprofilesctl get 2>/dev/null || true)"
if [[ "${_current_profile}" != "${POWER_PROFILE}" ]]; then
    dry_run_echo "would set power profile to ${POWER_PROFILE} (current: ${_current_profile})" || \
        powerprofilesctl set "${POWER_PROFILE}"
fi

smoke_10_hardware() {
    [[ "${DRY_RUN:-0}" == "1" ]] && return 0

    # Check all hardware packages are installed
    local pkg
    for pkg in linux-image-amd64 firmware-amd-graphics amd64-microcode fwupd power-profiles-daemon; do
        guard::package_installed "${pkg}" \
            || { echo "smoke: package not installed: ${pkg}" >&2; return 1; }
    done

    # Check backports-pinned packages are from trixie-backports
    local _bpkg
    for _bpkg in linux-image-amd64 firmware-amd-graphics; do
        apt-cache policy "${_bpkg}" 2>/dev/null | grep -A1 ' \*\*\*' | grep -q 'trixie-backports' \
            || { echo "smoke: ${_bpkg} is not installed from trixie-backports" >&2; return 1; }
    done

    guard::file_matches_template \
            /etc/apt/preferences.d/kernel-backports \
            "${REPO_ROOT}/templates/etc/apt/preferences.d/kernel-backports" \
        || { echo "smoke: kernel-backports pin file does not match template" >&2; return 1; }

    guard::file_matches_template \
            /etc/apt/preferences.d/firmware-amd-backports \
            "${REPO_ROOT}/templates/etc/apt/preferences.d/firmware-amd-backports" \
        || { echo "smoke: firmware-amd-backports pin file does not match template" >&2; return 1; }

    guard::file_matches_template \
            /etc/udev/rules.d/60-nvme-scheduler.rules \
            "${REPO_ROOT}/templates/etc/udev/rules.d/60-nvme-scheduler.rules" \
        || { echo "smoke: nvme udev scheduler rule does not match template" >&2; return 1; }

    ! guard::file_exists /etc/udev/rules.d/60-nvme-ioscheduler.rules \
        || { echo "smoke: legacy 60-nvme-ioscheduler.rules still present" >&2; return 1; }

    guard::service_enabled fwupd \
        || { echo "smoke: fwupd.service is not enabled" >&2; return 1; }

    guard::service_enabled power-profiles-daemon \
        || { echo "smoke: power-profiles-daemon.service is not enabled" >&2; return 1; }

    guard::service_active power-profiles-daemon \
        || { echo "smoke: power-profiles-daemon is not active" >&2; return 1; }

    local _current_profile
    _current_profile="$(powerprofilesctl get 2>/dev/null || true)"
    [[ "${_current_profile}" == "${POWER_PROFILE}" ]] \
        || { echo "smoke: power profile is '${_current_profile}', expected '${POWER_PROFILE}'" >&2; return 1; }

    # Advisory only: a fresh install legitimately has one kernel; enforcing ≥2
    # would fail on first run. Warn so the operator notices, but don't block.
    local _kernel_count
    _kernel_count="$(dpkg -l 'linux-image-[0-9]*' 2>/dev/null | grep -c '^ii' || true)"
    if [[ "${_kernel_count}" -lt 2 ]]; then
        echo "smoke: warning: only ${_kernel_count} versioned kernel(s) installed; consider keeping at least 2" >&2
    fi
}
