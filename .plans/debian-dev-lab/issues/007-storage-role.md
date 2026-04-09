# `storage` role

## Type

AFK

## Phase

Phase 1: Foundation

## Parent plan

../../debian-dev-lab.md

## What to build

Implement the `storage` role — the deepest module per PRD §10.2. Format and unlock NVMe2 (LUKS + btrfs), wire its keyfile into `/etc/crypttab` so NVMe1 auto-unlocks NVMe2 at boot, template `/etc/fstab` for both disks, configure snapper on `@` and `@home` with the PRD retention, hook snapper into apt pre/post snapshots, and template the nightly `btrfs send` + prune systemd timers. The role must assert NVMe1's subvolume layout matches `docs/install.md` and fail loudly otherwise.

See parent plan, Phase 1 → `storage` deliverable, plus PRD §5.4 (layout), §10.2 (storage module), and "per role pre-flight assertions".

## Acceptance criteria

- [ ] NVMe2 LUKS container created (idempotent — guarded on header detection).
- [ ] LUKS keyfile generated on NVMe1 with restrictive perms; NVMe2 entry added to `/etc/crypttab` referencing the keyfile.
- [ ] btrfs filesystem on NVMe2 with `@data` and `@backups` subvolumes.
- [ ] `/etc/fstab` templated covering both disks (NVMe1 OS subvols + NVMe2 data/backups).
- [ ] `snapper` configs `root` and `home` created with PRD retention (timeline hourly on `@home`, keep 10h/10d).
- [ ] `/etc/apt/apt.conf.d/80snapper` enables pre/post snapshots on apt transactions.
- [ ] `btrfs-send.service` + `btrfs-send.timer` templated, nightly schedule.
- [ ] `btrfs-send-prune.service` + `btrfs-send-prune.timer` templated, retention enforced.
- [ ] Pre-flight assertion: NVMe1 subvolumes match expected layout — fail with "your install.md layout doesn't match" otherwise.
- [ ] Manual `systemctl start btrfs-send.service` produces a read-only snapshot under `/srv/backups/`.
- [ ] `--check --diff` reports 0 changed tasks on a converged run.

## Blocked by

- 005-base-role.md

## Implementation notes

- Variable interface: `nvme2_device`, retention vars. Everything else internal — do not let `storage` leak knobs.
- Idempotency: every destructive primitive (LUKS format, mkfs.btrfs, subvolume create) MUST be guarded on existence checks. The role runs many times.
- This role + `docs/install.md` are tightly coupled. If you change subvolume names here, change them there in the same PR.

## Requirements addressed

- Phase 1, `storage` deliverable.
- PRD §5.4 (storage layout), §10.2 (storage module is the deepest in the system).
- Testing strategy → `storage` pre-flight assertion.
