#!/usr/bin/env bash
# shellcheck shell=bash
# Module: 30-security — nftables firewall, sshd hardening, unattended-upgrades,
# root-login lock. Per PRD §5.10. LAN-only by construction; no fail2ban.
#
# Knob: LAN_SUBNET (default 192.168.1.0/24). Override via secrets.env or env.

step "30-security"

# LAN_SUBNET comes from run.sh (default 192.168.1.0/24). The nftables template
# expects ${LAN_SUBNET} to be exported by the time deploy_template_subst runs.
[[ -n "${LAN_SUBNET:-}" ]] || error "30-security: LAN_SUBNET is not set (see run.sh)"

# ---------------------------------------------------------------------------
# 1. Apt packages
# ---------------------------------------------------------------------------
_security_packages=(nftables openssh-server unattended-upgrades apt-listchanges gettext-base)
_missing_security=()
for _pkg in "${_security_packages[@]}"; do
    guard::package_installed "${_pkg}" || _missing_security+=("${_pkg}")
done
if [[ "${#_missing_security[@]}" -gt 0 ]]; then
    dry_run_echo "would install security packages: ${_missing_security[*]}" || \
        safe_install "nftables + sshd + unattended-upgrades" "${_missing_security[@]}"
fi

# ---------------------------------------------------------------------------
# 2. nftables ruleset
# ---------------------------------------------------------------------------
_nft_changed=0
# shellcheck disable=SC2016  # '${LAN_SUBNET}' is envsubst's whitelist syntax, must be literal
if [[ ! -f /etc/nftables.conf ]] \
   || ! diff -q <(envsubst '${LAN_SUBNET}' < "${REPO_ROOT}/templates/etc/nftables.conf") /etc/nftables.conf >/dev/null 2>&1; then
    # shellcheck disable=SC2016
    deploy_template_subst /etc/nftables.conf "nftables ruleset (LAN: ${LAN_SUBNET})" '${LAN_SUBNET}'
    _nft_changed=1
fi

# Enable + activate nftables.service (idempotent)
if ! guard::service_enabled nftables; then
    # SAFE_REPLAY: guarded by guard::service_enabled above
    dry_run_echo "would enable nftables.service" || systemctl enable nftables
fi
if [[ "${_nft_changed}" -eq 1 ]]; then
    if ! guard::service_active nftables; then
        dry_run_echo "would start nftables.service" || systemctl start nftables
    else
        dry_run_echo "would reload nftables ruleset" || \
            { systemctl reload nftables 2>/dev/null || systemctl restart nftables; }
    fi
fi

# ---------------------------------------------------------------------------
# 3. sshd hardening drop-in
# ---------------------------------------------------------------------------
_sshd_changed=0
if ! guard::file_matches_template /etc/ssh/sshd_config.d/10-ser8.conf \
        "${REPO_ROOT}/templates/etc/ssh/sshd_config.d/10-ser8.conf"; then
    deploy_template /etc/ssh/sshd_config.d/10-ser8.conf "sshd hardening drop-in"
    _sshd_changed=1
fi
if ! guard::service_enabled ssh; then
    dry_run_echo "would enable ssh.service" || systemctl enable ssh
fi
if [[ "${_sshd_changed}" -eq 1 ]]; then
    # Validate before reload — a bad sshd_config breaks the box if ssh is the
    # only access path. `sshd -t` exits non-zero on invalid config.
    if dry_run_echo "would validate + reload sshd"; then :; else
        if sshd -t 2>/dev/null; then
            systemctl reload ssh
        else
            error "sshd -t failed: refusing to reload; fix the drop-in template"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 4. Unattended-upgrades — security only, kernel held back
# ---------------------------------------------------------------------------
deploy_template /etc/apt/apt.conf.d/50unattended-upgrades "unattended-upgrades security-only config"
deploy_template /etc/apt/apt.conf.d/20auto-upgrades         "periodic apt + auto-upgrades enable"

if ! guard::service_enabled unattended-upgrades; then
    dry_run_echo "would enable unattended-upgrades.service" || \
        systemctl enable unattended-upgrades
fi
if ! guard::service_active unattended-upgrades; then
    dry_run_echo "would start unattended-upgrades.service" || \
        systemctl start unattended-upgrades 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 5. Lock root account (PRD §5.10 — "No root password")
# ---------------------------------------------------------------------------
_root_pw_status="$(passwd -S root 2>/dev/null | awk '{print $2}')"
if [[ "${_root_pw_status}" == "P" ]]; then
    dry_run_echo "would passwd -l root (currently has a password)" || \
        passwd -l root
fi

# ---------------------------------------------------------------------------
# 6. Sudoers safety check — warn loudly on any NOPASSWD entry (don't auto-fix
# sudoers; a typo there can lock the operator out)
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN:-0}" != "1" ]]; then
    if grep -RsHE '^[^#]*NOPASSWD' /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -v '^$' >&2; then
        warn "NOPASSWD sudoers entries found above — PRD §5.10 requires password-prompted sudo"
    fi
fi

smoke_30_security() {
    [[ "${DRY_RUN:-0}" == "1" ]] && return 0

    local pkg
    for pkg in nftables openssh-server unattended-upgrades apt-listchanges gettext-base; do
        guard::package_installed "${pkg}" \
            || { echo "smoke: package not installed: ${pkg}" >&2; return 1; }
    done

    # nftables config matches our render of the template
    # shellcheck disable=SC2016
    diff -q <(envsubst '${LAN_SUBNET}' < "${REPO_ROOT}/templates/etc/nftables.conf") \
            /etc/nftables.conf >/dev/null 2>&1 \
        || { echo "smoke: /etc/nftables.conf does not match rendered template" >&2; return 1; }

    guard::service_enabled nftables \
        || { echo "smoke: nftables.service not enabled" >&2; return 1; }
    guard::service_active nftables \
        || { echo "smoke: nftables.service not active" >&2; return 1; }

    # Active ruleset contains our LAN subnet (catches the case where the file
    # is fine but the kernel never reloaded it)
    nft list ruleset 2>/dev/null | grep -qF "${LAN_SUBNET}" \
        || { echo "smoke: nft ruleset missing LAN subnet ${LAN_SUBNET}" >&2; return 1; }

    guard::file_matches_template \
            /etc/ssh/sshd_config.d/10-ser8.conf \
            "${REPO_ROOT}/templates/etc/ssh/sshd_config.d/10-ser8.conf" \
        || { echo "smoke: sshd drop-in does not match template" >&2; return 1; }
    guard::service_enabled ssh \
        || { echo "smoke: ssh.service not enabled" >&2; return 1; }
    sshd -t 2>/dev/null \
        || { echo "smoke: sshd -t reports config invalid" >&2; return 1; }

    guard::file_matches_template \
            /etc/apt/apt.conf.d/50unattended-upgrades \
            "${REPO_ROOT}/templates/etc/apt/apt.conf.d/50unattended-upgrades" \
        || { echo "smoke: 50unattended-upgrades does not match template" >&2; return 1; }
    guard::file_matches_template \
            /etc/apt/apt.conf.d/20auto-upgrades \
            "${REPO_ROOT}/templates/etc/apt/apt.conf.d/20auto-upgrades" \
        || { echo "smoke: 20auto-upgrades does not match template" >&2; return 1; }
    guard::service_enabled unattended-upgrades \
        || { echo "smoke: unattended-upgrades.service not enabled" >&2; return 1; }

    # Root must not have a usable password
    local _rs
    _rs="$(passwd -S root 2>/dev/null | awk '{print $2}')"
    [[ "${_rs}" == "L" || "${_rs}" == "LK" || "${_rs}" == "NP" ]] \
        || { echo "smoke: root password status is '${_rs}' — expected L / LK / NP" >&2; return 1; }

    # No NOPASSWD sudoers entries
    if grep -RsqE '^[^#]*NOPASSWD' /etc/sudoers /etc/sudoers.d/ 2>/dev/null; then
        echo "smoke: NOPASSWD sudoers entry detected — PRD §5.10 forbids it" >&2
        return 1
    fi
}
