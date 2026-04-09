# `hardware` role

## Type

AFK

## Phase

Phase 1: Foundation

## Parent plan

../../debian-dev-lab.md

## What to build

Implement the `hardware` role: backports kernel, AMD GPU firmware and microcode, fwupd enablement, NVMe scheduler udev rule, and `power-profiles-daemon` with a default `balanced` profile. Verify a previous kernel is kept around so a bad upgrade is recoverable.

See parent plan, Phase 1 → `hardware` deliverable.

## Acceptance criteria

- [ ] Backports kernel installed (`linux-image-amd64` from `trixie-backports`).
- [ ] `firmware-amd-graphics` and `amd64-microcode` installed from backports.
- [ ] `fwupd` installed and enabled (timer or service per Debian default).
- [ ] NVMe scheduler udev rule templated and active (verify with `cat /sys/block/nvme0n1/queue/scheduler`).
- [ ] `power-profiles-daemon` installed; profile set from `power_profile` var (default `balanced`).
- [ ] Verification step: at least two kernels present in `/boot` after upgrade.
- [ ] `--check --diff` reports 0 changed tasks on a converged run.

## Blocked by

- 005-base-role.md

## Implementation notes

- Beelink SER8 is Ryzen 7 8845HS / Radeon 780M — AMD firmware path is non-negotiable.
- The "previous kernel kept" check protects the operator from a bad backports kernel upgrade. It's a safety net, not aspirational.

## Requirements addressed

- Phase 1, `hardware` deliverable.
- PRD §10 hardware module.
