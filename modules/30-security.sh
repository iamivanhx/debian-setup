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

# Pre-flight: if SSH_AUTHORIZED_KEYS isn't populated, refuse to do anything
# before the operator could be locked out — sshd hardening flips
# PasswordAuthentication off, so a missing authorized_keys is a one-way ticket
# to a rescue boot.
[[ -n "${SSH_AUTHORIZED_KEYS:-}" ]] \
    || error "refusing to touch sshd until SSH_AUTHORIZED_KEYS is populated"

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
# 3. SSH authorized_keys for the primary user. MUST land before the sshd
# reload below — once PasswordAuthentication is off, a missing or wrong
# authorized_keys means no way back in.
# ---------------------------------------------------------------------------
_authkeys_user="$(stat -c '%U' "${SETUP_HOME}")"
_authkeys_group="$(stat -c '%G' "${SETUP_HOME}")"
_authkeys_dir="${SETUP_HOME}/.ssh"
_authkeys_file="${_authkeys_dir}/authorized_keys"
# Normalize so the on-disk file always ends in a single trailing newline,
# regardless of how the operator pasted the key into secrets.env.
_authkeys_rendered="${SSH_AUTHORIZED_KEYS%$'\n'}"$'\n'

_authkeys_changed=0
if [[ ! -f "${_authkeys_file}" ]] \
   || ! diff -q <(printf '%s' "${_authkeys_rendered}") "${_authkeys_file}" >/dev/null 2>&1; then
    if dry_run_echo "would deploy ${_authkeys_file} (authorized_keys for ${_authkeys_user})"; then :; else
        install -d -o "${_authkeys_user}" -g "${_authkeys_group}" -m 0700 "${_authkeys_dir}"
        printf '%s' "${_authkeys_rendered}" | deploy_config "${_authkeys_file}"
        chown "${_authkeys_user}:${_authkeys_group}" "${_authkeys_file}"
        chmod 0600 "${_authkeys_file}"
    fi
    _authkeys_changed=1
fi

# ---------------------------------------------------------------------------
# 4. sshd hardening drop-in
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
if [[ "${_sshd_changed}" -eq 1 || "${_authkeys_changed}" -eq 1 ]]; then
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
# 5. Unattended-upgrades — security only, kernel held back
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
# 6. Lock root account (PRD §5.10 — "No root password")
# ---------------------------------------------------------------------------
_root_pw_status="$(passwd -S root 2>/dev/null | awk '{print $2}')"
if [[ "${_root_pw_status}" == "P" ]]; then
    dry_run_echo "would passwd -l root (currently has a password)" || \
        passwd -l root
fi

# ---------------------------------------------------------------------------
# 7. Sudoers drop-in — explicit Defaults, no NOPASSWD anywhere. visudo -cf
# pre-validates the template content; a broken sudoers in /etc/sudoers.d/
# disables sudo entirely, so we refuse to deploy without that check.
# ---------------------------------------------------------------------------
_sudoers_dest=/etc/sudoers.d/ser8-no-nopasswd
_sudoers_tmpl="${REPO_ROOT}/templates${_sudoers_dest}"
[[ -f "${_sudoers_tmpl}" ]] \
    || error "30-security: sudoers template missing at ${_sudoers_tmpl}"
if ! guard::file_matches_template "${_sudoers_dest}" "${_sudoers_tmpl}"; then
    if dry_run_echo "would visudo-validate and deploy ${_sudoers_dest}"; then :; else
        command -v visudo >/dev/null 2>&1 \
            || error "30-security: visudo not installed; cannot validate sudoers drop-in"
        visudo -cf "${_sudoers_tmpl}" >/dev/null \
            || error "30-security: visudo -c rejected ${_sudoers_tmpl}; refusing to deploy"
        deploy_template "${_sudoers_dest}" "sudoers no-NOPASSWD policy"
        chown root:root "${_sudoers_dest}"
        chmod 0440 "${_sudoers_dest}"
    fi
fi

# Loud warning on any *other* NOPASSWD entry (we don't auto-fix — operator
# might have an intentional one — but they should see it called out).
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

    # authorized_keys exists, owned by primary user, mode 0600, content matches
    # secrets.env (single trailing newline normalisation, same as deploy).
    local _ak_user _ak_file _ak_rendered _ak_mode _ak_owner
    _ak_user="$(stat -c '%U' "${SETUP_HOME}")"
    _ak_file="${SETUP_HOME}/.ssh/authorized_keys"
    [[ -f "${_ak_file}" ]] \
        || { echo "smoke: ${_ak_file} missing" >&2; return 1; }
    _ak_mode="$(stat -c '%a' "${_ak_file}")"
    [[ "${_ak_mode}" == "600" ]] \
        || { echo "smoke: ${_ak_file} mode is ${_ak_mode}, expected 600" >&2; return 1; }
    _ak_owner="$(stat -c '%U' "${_ak_file}")"
    [[ "${_ak_owner}" == "${_ak_user}" ]] \
        || { echo "smoke: ${_ak_file} owner is ${_ak_owner}, expected ${_ak_user}" >&2; return 1; }
    _ak_rendered="${SSH_AUTHORIZED_KEYS%$'\n'}"$'\n'
    diff -q <(printf '%s' "${_ak_rendered}") "${_ak_file}" >/dev/null 2>&1 \
        || { echo "smoke: ${_ak_file} content does not match SSH_AUTHORIZED_KEYS" >&2; return 1; }

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

    # Sudoers drop-in matches template and parses clean.
    guard::file_matches_template \
            /etc/sudoers.d/ser8-no-nopasswd \
            "${REPO_ROOT}/templates/etc/sudoers.d/ser8-no-nopasswd" \
        || { echo "smoke: /etc/sudoers.d/ser8-no-nopasswd does not match template" >&2; return 1; }
    visudo -cf /etc/sudoers.d/ser8-no-nopasswd >/dev/null 2>&1 \
        || { echo "smoke: visudo -c rejects /etc/sudoers.d/ser8-no-nopasswd" >&2; return 1; }

    # No NOPASSWD sudoers entries
    if grep -RsqE '^[^#]*NOPASSWD' /etc/sudoers /etc/sudoers.d/ 2>/dev/null; then
        echo "smoke: NOPASSWD sudoers entry detected — PRD §5.10 forbids it" >&2
        return 1
    fi
}
