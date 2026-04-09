# `backup` role: restic + rclone + Dropbox + retention

## Type

AFK

## Phase

Phase 3: Backup Trilogy

## Parent plan

../../debian-dev-lab.md

## What to build

Implement the `backup` role to deliver the off-site leg of the backup trilogy: restic and rclone installed, `~/.config/rclone/rclone.conf` templated with the vaulted Dropbox token, the restic repository initialized one-shot (idempotent on `stat`), nightly `restic-backup.timer` at 03:00, separate `restic-forget.timer` enforcing `keep 7 daily / 4 weekly / 6 monthly`, and an optional Dropbox desktop client behind the `install_dropbox_client` flag (default `true`).

See parent plan, Phase 3 → `backup` deliverable and implementation notes, plus PRD §5.10.

## Acceptance criteria

- [ ] `restic` and `rclone` installed.
- [ ] `~/.config/rclone/rclone.conf` rendered from a template that consumes the vaulted Dropbox token (`dropbox_rclone_token`).
- [ ] Restic repository init task is guarded on `stat` of the repo (NOT on a creation-time attribute) and is a true no-op after the first run.
- [ ] Restic passphrase consumed from the vaulted `restic_passphrase`.
- [ ] `restic-backup.service` + `restic-backup.timer` templated, scheduled at 03:00 nightly.
- [ ] Backup includes `/home/<user>` and `/etc`, excludes per PRD §5.10 (Docker volumes path included in the exclusion list — this is why `lab` is a dependency).
- [ ] `restic-forget.service` + `restic-forget.timer` templated as a separate unit, retention `keep 7 daily / 4 weekly / 6 monthly`. Two timers, two logs.
- [ ] `install_dropbox_client` var defaults to `true`. When `true`, Dropbox desktop client installed.
- [ ] After a manual `systemctl start restic-backup.service`, `restic snapshots` lists at least one snapshot.
- [ ] `--check --diff` reports 0 changed tasks on a converged run.

## Blocked by

- 007-storage-role.md
- 013-lab-role.md (Docker volumes path must exist for the exclusion to be meaningful)

## Implementation notes

- Restic init is a one-shot. The classic mistake is to re-init on every run; guard on `stat` of `<repo>/config`.
- Backup and forget are TWO timers, not one inline pipeline. PRD §5.10 is explicit about this.
- Vaulted secrets must be populated before this role runs: `dropbox_rclone_token`, `restic_passphrase`.
- The `install_dropbox_client` flag is the toggle for the soak-test (issue 018). Default true; the soak may flip it to false.

## Requirements addressed

- Phase 3, `backup` deliverable.
- PRD §5.10 (backup trilogy, retention, exclusions).
