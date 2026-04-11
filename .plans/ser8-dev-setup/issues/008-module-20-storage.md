# 20-storage module: NVMe2 LUKS + ext4 + Docker data-root (DEEP)

## Type

AFK

## Phase

Phase 1: Foundation

## Parent plan

../../ser8-dev-setup.md

## What to build

The deepest, riskiest module in the automation. Fill in `modules/20-storage.sh` so that NVMe2 is brought under management and Docker is pre-configured to use it (Docker itself is installed in Phase 3).

**This module has two operations that are destructive if re-run without a guard: `cryptsetup luksFormat` and `mkfs.ext4`. Both MUST be bulletproof.**

Concrete deliverables:

- Detect NVMe2 device path (variable at top of `run.sh`, default `NVME2_DEVICE="/dev/nvme1n1"` — verifiable with `lsblk`).
- `cryptsetup luksFormat` on NVMe2, **guarded by `cryptsetup isLuks $NVME2_DEVICE`** — if already LUKS, skip. Passphrase for first-time format is sourced from `secrets.env` as `NVME2_LUKS_PASSPHRASE` (one-shot use).
- Generate keyfile at `/etc/luks-keys/srv-data.key` with `dd if=/dev/urandom of=... bs=512 count=8` (mode 0400, owner root:root), **guarded by `guard::file_exists`**.
- Add the keyfile to the LUKS header via `cryptsetup luksAddKey` (guarded — check if the keyfile is already a valid unlock credential using `cryptsetup luksDump` + compare, or attempt `cryptsetup open --test-passphrase --key-file`).
- Template `/etc/crypttab` with the NVMe2 entry referencing the keyfile: `srv-data UUID=<nvme2-luks-uuid> /etc/luks-keys/srv-data.key luks,discard`. Guarded by `guard::file_has_line` checking for the mapper name.
- `cryptsetup open` the container at `/dev/mapper/srv-data` (guarded by existence of the mapper device).
- `mkfs.ext4 -L srv-data /dev/mapper/srv-data`, **guarded by `blkid` reporting ext4** on the mapper — if already ext4, skip.
- Template `/etc/fstab` with the ext4 entry: `LABEL=srv-data /srv/data ext4 defaults,noatime 0 2`. Guarded.
- Create `/srv/data/` mountpoint and `mount -a` (or `mount /srv/data`).
- Create directory skeleton under `/srv/data/`: `projects/`, `lab/compose/`, `docker/` (guarded by `guard::dir_exists`).
- Template `/etc/docker/daemon.json` with `{"data-root": "/srv/data/docker"}` (via `deploy_config`).
- Template `/etc/systemd/system/docker.service.d/waits-for-srv-data.conf` with `[Unit]\nRequiresMountsFor=/srv/data\nAfter=srv-data.mount` (via `deploy_config`). Run `systemctl daemon-reload` if the drop-in was new.
- `smoke_20_storage`: `cryptsetup isLuks $NVME2_DEVICE`, `/srv/data` is a mountpoint, keyfile exists with mode 0400, `/etc/crypttab` and `/etc/fstab` contain the expected lines, `/etc/docker/daemon.json` matches template, drop-in exists.

## Acceptance criteria

- [ ] On a fresh machine with a raw NVMe2, `./run.sh 20-storage` exits 0 and mounts `/srv/data`.
- [ ] On a converged machine, `./run.sh 20-storage` runs zero destructive actions (`./run.sh --dry-run 20-storage` reports nothing).
- [ ] On a converged machine, `./run.sh 20-storage` run twice in a row both exit 0 and the second run does NOT reformat NVMe2 (verified by `blkid` showing the same UUID before and after).
- [ ] After reboot, `/srv/data` is mounted automatically via the keyfile (no passphrase prompt for NVMe2).
- [ ] `smoke_20_storage` passes.
- [ ] Shellcheck + shfmt clean; pre-commit hook clean.
- [ ] The passphrase prompt for the FIRST-TIME format is clearly documented in `docs/install.md` and the `NVME2_LUKS_PASSPHRASE` variable is listed in the secrets.env template.

## Blocked by

- Blocked by 006-module-00-base.md (needs apt sources for `cryptsetup`)

## Implementation notes

- **Test this module on a loop device before running on real hardware.** Create a 2 GB loop file, treat it as `$NVME2_DEVICE`, and verify the full module flow (format, add keyfile, fstab, mount, second run = no-op). Iterate until second-run idempotency is bulletproof.
- The `cryptsetup isLuks` guard is the single most important line in this whole project. If it's wrong, re-running the module reformats NVMe2 and the user loses all project data. Manual verification: run `./run.sh 20-storage` twice in a row against a populated `/srv/data` and confirm no data loss.
- The keyfile must be in `/etc/luks-keys/` NOT under `/boot` — the keyfile exists only on NVMe1 so if NVMe1 is wiped, NVMe2 becomes passphrase-only (and the passphrase from `secrets.env` is the recovery path).
- For the `luksAddKey` step, one reliable idempotency check is: `cryptsetup open --test-passphrase --key-file /etc/luks-keys/srv-data.key $NVME2_DEVICE --type luks2 srv-data-test` (with a `|| true` fallback) — if it succeeds, the keyfile is already a valid slot, skip.
- The Docker ordering drop-in matters: without it, `docker.service` can start before `srv-data.mount` and create `/srv/data/docker/` as an empty directory on the root filesystem, masking the mount. Verify by adding a file to `/srv/data/docker/` on the running box, rebooting, and checking the file is still visible (it will be if the ordering is right).
- **R6 is load-bearing:** this module's correctness is what makes the disaster drill possible. The drill (issue 018) verifies this empirically; the module guarantees it structurally.

## Requirements addressed

- Plan Phase 1, `20-storage.sh` bullet (deep module)
- PRD §5.3 (Storage layout)
- PRD §10.1 table, 20-storage row
- PRD §10.2 (deep-module analysis, 20-storage)
- PRD §10.7 (Docker data-root)
- PRD §12 R6 (Docker volumes survive reinstall)
