# 30-security module: nftables, sshd, unattended-upgrades, sudo

## Type

AFK

## Phase

Phase 1: Foundation

## Parent plan

../../ser8-dev-setup.md

## What to build

Fill in `modules/30-security.sh` so that the machine lands a hardened LAN-only security baseline in one pass.

Concrete deliverables:

- Pre-flight assertion: `SSH_AUTHORIZED_KEYS` (from `secrets.env`) is non-empty. If empty, fail with `"refusing to touch sshd until SSH_AUTHORIZED_KEYS is populated"`. This MUST happen before any write to `sshd_config`.
- Templated `/etc/nftables.conf` (via `deploy_config`):
  - Default policy: drop inbound on WAN-side interfaces (determined by `LAN_SUBNET` NOT matching).
  - Allow loopback, `ct state established,related`.
  - Allow `$LAN_SUBNET` (variable, default `192.168.1.0/24`) for ports 22, 80, 443.
  - Rate-limited log-and-drop rule for dropped packets (`limit rate 10/minute`).
- `systemctl enable --now nftables` (guarded).
- Templated `/etc/ssh/sshd_config` (via `deploy_config`):
  - `PermitRootLogin no`, `PasswordAuthentication no`, `PubkeyAuthentication yes`, `ChallengeResponseAuthentication no`.
  - `AuthorizedKeysFile .ssh/authorized_keys`.
  - `ListenAddress 0.0.0.0` (nftables enforces the LAN-only policy at packet level; sshd doesn't need to know).
- Deploy `~/.ssh/authorized_keys` for the primary user with the content of `SSH_AUTHORIZED_KEYS` (via `deploy_config` + `run_as_user chown`); mode 0600, owner = primary user.
- `systemctl reload ssh` (guarded — only if the config or authorized_keys actually changed).
- Templated `/etc/apt/apt.conf.d/50unattended-upgrades` (security-only, `Remove-Unused-Kernel-Packages "false"`).
- Templated `/etc/apt/apt.conf.d/20auto-upgrades` (enable periodic runs).
- `systemctl enable unattended-upgrades.service` (guarded).
- Templated `/etc/sudoers.d/ser8-no-nopasswd` (explicit `Defaults passwd_timeout=0`, no NOPASSWD entries). Deploy with `visudo -c` pre-check.
- `smoke_30_security`: `nft list ruleset` matches the templated ruleset (via `guard::file_matches_template` against a canonicalized snapshot), sshd_config matches template, `systemctl is-active ssh` and `nftables`, `ss -Hltn` shows sshd listening on `0.0.0.0:22`, `apt-config dump APT::Periodic::Update-Package-Lists` returns `"1"`.

## Acceptance criteria

- [ ] `./run.sh 30-security` on a fresh Phase 1 machine exits 0 and locks down the box.
- [ ] `./run.sh --dry-run 30-security` on a converged box reports zero planned actions.
- [ ] With a deliberately empty `SSH_AUTHORIZED_KEYS`, `./run.sh 30-security` fails BEFORE touching sshd.
- [ ] SSH from a LAN client using the authorized key works; SSH from the same client with password auth fails.
- [ ] `nft list ruleset` matches the templated ruleset byte-for-byte.
- [ ] `smoke_30_security` passes.
- [ ] Shellcheck + shfmt clean; pre-commit hook clean.

## Blocked by

- Blocked by 006-module-00-base.md

## Implementation notes

- Port the security bits from `beelink_debian_post_install.sh` step 14 (UFW + fail2ban) — but **replace UFW with nftables** and **drop fail2ban entirely** (PRD non-goal). The existing step is partial inspiration, not a direct port.
- The nftables template should be well-commented so future-you can read it without tcpdump.
- `LAN_SUBNET` variable at the top of `run.sh` alongside `TIMEZONE` and `POWER_PROFILE`. Default `192.168.1.0/24` but expect to override.
- `visudo -c /etc/sudoers.d/ser8-no-nopasswd` MUST run before moving the file into place — a broken sudoers file locks you out of root permanently without a rescue environment.
- The `deploy_config` helper should be extended (or called with a flag) to run a validator command after writing a file for this specific case.

## Requirements addressed

- Plan Phase 1, `30-security.sh` bullet
- PRD §5.10 (Security)
- PRD §10.1 table, 30-security row
- PRD User Stories 26, 27, 28, 29, 36
