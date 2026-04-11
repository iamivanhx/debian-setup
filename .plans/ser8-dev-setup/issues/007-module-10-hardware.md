# 10-hardware module: backports kernel, AMD firmware, NVMe, power

## Type

AFK

## Phase

Phase 1: Foundation

## Parent plan

../../ser8-dev-setup.md

## What to build

Fill in `modules/10-hardware.sh` so that it lands all SER8-specific hardware tuning.

Concrete deliverables:

- Pin backports kernel high in `/etc/apt/preferences.d/kernel-backports` (template): `linux-image-*`, `linux-headers-*`, and the matching meta packages point at backports.
- Pin AMD firmware high: `firmware-amd-graphics` from backports.
- Install: backports kernel meta-package (`linux-image-amd64/trixie-backports`), `firmware-amd-graphics`, `amd64-microcode`, `fwupd`.
- NVMe scheduler udev rule templated to `/etc/udev/rules.d/60-nvme-scheduler.rules` (set `none` scheduler for NVMe devices per PRD §5.2 hardware tuning notes — reuse the existing script's rule if it's already correct).
- `power-profiles-daemon` installed and enabled; `powerprofilesctl set "$POWER_PROFILE"` where `$POWER_PROFILE` is a variable (default `balanced`).
- `fwupd.service` enabled.
- `smoke_10_hardware`: `uname -r` is a backports kernel, `dpkg -s amd64-microcode firmware-amd-graphics fwupd`, udev rule file matches template via `guard::file_matches_template`, `systemctl is-active power-profiles-daemon`, `powerprofilesctl get` matches configured profile.

## Acceptance criteria

- [ ] `./run.sh 10-hardware` on a converged 00-base machine exits 0 and installs the backports kernel.
- [ ] After reboot, `uname -r` reports a backports kernel version.
- [ ] `./run.sh --dry-run 10-hardware` on the converged box reports zero planned actions.
- [ ] `smoke_10_hardware` passes.
- [ ] `dpkg -l | grep linux-image` shows at least two kernel packages (the new backports one and at least one fallback).
- [ ] Shellcheck + shfmt clean; pre-commit hook clean.

## Blocked by

- Blocked by 006-module-00-base.md

## Implementation notes

- Port the hardware tuning steps from `beelink_debian_post_install.sh` (steps 5, 6, 7, 8 — GPU/microcode/kernel/NVMe). Most of the apt install lines are directly reusable; the logic around `update-grub` after a kernel install may need guarding.
- Kernel install triggers a GRUB update automatically via the post-install hook; no explicit `update-grub` needed unless porting reveals otherwise.
- The `POWER_PROFILE` variable belongs at the top of `run.sh` alongside `TIMEZONE`.
- Unattended-upgrades retaining old kernels is configured in 30-security, not here. But verify the smoke test catches the "only one kernel present" case as a warning — a single kernel is a disaster-drill hazard.

## Requirements addressed

- Plan Phase 1, `10-hardware.sh` bullet
- PRD §5.2 (Base OS kernel/firmware pinning)
- PRD §10.1 table, 10-hardware row
- PRD §12 R7 (backports kernel pin breaking mitigation)
