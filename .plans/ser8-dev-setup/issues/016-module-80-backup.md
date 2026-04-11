# 80-backup module: restic + Backblaze B2 + timers + retention

## Type

AFK

## Phase

Phase 3: Lab + Backup + Disaster Drill

## Parent plan

../../ser8-dev-setup.md

## What to build

Fill in `modules/80-backup.sh` so that nightly restic snapshots land in Backblaze B2 and retention is enforced.

Concrete deliverables:

- Install `restic` from apt. Verify the version is recent enough to support B2 native backend (restic ≥ 0.9.0). If apt's version is too old, install from backports or from the upstream tarball (guarded — decide based on actual Debian 13 apt version at implementation time).
- Template `/etc/restic/includes.txt` with the four backup paths: `/home/<user>/`, `/srv/data/projects/`, `/srv/data/lab/compose/`, `/srv/data/docker/volumes/`.
- Template `/etc/restic/excludes.txt` with the exclude patterns from PRD §5.9: `.cache`, `.local/share/Trash`, `node_modules`, `.venv`, `target`, `build`, `dist`, `.next`, `.turbo`, `/srv/data/docker/*` (except `volumes/`), `*.backupignore`, content under `.backupignore` files.
- Template `/etc/restic/ser8.env` — contains `RESTIC_REPOSITORY`, `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY`. The file is written from the values in `~/.config/ser8-setup/secrets.env` via a one-line `envsubst` during module run. Mode 0600, root:root. (`RESTIC_PASSWORD` is NOT written to this file — it's passed via `RESTIC_PASSWORD_COMMAND` that reads `secrets.env` at runtime to avoid a plaintext password file on disk.)
- **One-shot `restic init`** on B2, guarded by the presence of a marker file `/srv/data/.restic-initialized`. If the marker is absent: run `restic init`, and on success create the marker. If the marker is present: skip. This is the single most important guard in the backup module — re-initing burns the repo.
- Template `/etc/systemd/system/restic-backup.service` — a oneshot unit that runs `restic backup --files-from /etc/restic/includes.txt --exclude-file /etc/restic/excludes.txt`, sourcing env from `/etc/restic/ser8.env`.
- Template `/etc/systemd/system/restic-backup.timer` — nightly at 03:00, `Persistent=true` so missed runs catch up.
- Template `/etc/systemd/system/restic-forget.service` — a oneshot unit that runs `restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune`.
- Template `/etc/systemd/system/restic-forget.timer` — weekly (Sunday 04:00), `Persistent=true`.
- `systemctl daemon-reload` (if any unit file was changed).
- `systemctl enable --now restic-backup.timer restic-forget.timer`, guarded.
- Wire `./run.sh backup now` → `systemctl start restic-backup.service` in `run.sh`.
- `smoke_80_backup`: restic installed, `/etc/restic/includes.txt` matches template, `/etc/restic/excludes.txt` matches template, `/etc/restic/ser8.env` exists with mode 0600, `systemctl is-enabled restic-backup.timer`, `systemctl is-enabled restic-forget.timer`, marker file `/srv/data/.restic-initialized` exists. (The "at least one snapshot exists" check is deferred to issue 018 when a manual backup run is actually triggered.)

## Acceptance criteria

- [ ] `./run.sh 80-backup` on a converged Phase 3 70-lab machine installs restic, initializes the B2 repo (once), and enables both timers.
- [ ] `./run.sh --dry-run 80-backup` on the converged box reports zero planned actions.
- [ ] Re-running `./run.sh 80-backup` after init does NOT re-init the repo (marker file is checked).
- [ ] `./run.sh backup now` triggers an immediate backup service run.
- [ ] After a manual `./run.sh backup now`, `restic snapshots` lists at least one snapshot.
- [ ] After a manual `./run.sh backup now`, deleting `~/testdir/` and running the documented restore procedure (from issue 017 once landed) recovers it.
- [ ] `smoke_80_backup` passes.
- [ ] Shellcheck + shfmt + pre-commit clean.

## Blocked by

- Blocked by 008-module-20-storage.md (needs `/srv/data` for the init marker file and for the backup include paths)

## Implementation notes

- **`restic init` is the one operation that must run exactly once per B2 repository.** The marker file approach at `/srv/data/.restic-initialized` is the simplest reliable idempotency mechanism. Do not query B2 to ask "is this repo initialized?" — that can give false negatives if B2 is temporarily unreachable, and it's slower.
- **If the marker file is lost** (e.g. NVMe2 wipe), the reinstall procedure in `docs/recovery.md` must either (a) re-run `restic init` on an existing repo (which is a noop and exits with a "repository already exists" warning — treat as success for the marker re-creation) OR (b) document that the operator should recreate the marker manually after verifying the repo still exists on B2. The second is safer.
- `RESTIC_PASSWORD_COMMAND` example: `cat ~/.config/ser8-setup/secrets.env | grep ^RESTIC_PASSWORD= | cut -d= -f2`. Or simpler: use `RESTIC_PASSWORD_FILE` pointing at a mode-0400 file that's copied out of secrets.env on demand. Evaluate both at implementation time.
- The `ser8.env` file holds credentials, not the password — keeping the password out of on-disk state reduces one leak surface.
- Docker volume backup has a known consistency caveat (PRD §12 R5). Documented in `docs/recovery.md` (issue 017). Do not add a pause/fsfreeze hook in v1.
- Retention policy (7d/4w/6m) is baked into the `restic-forget.service` unit but values come from variables at the top of `run.sh` so they're easy to change. Revisit after one month of observed B2 usage (PRD §13 Open Question #1).

## Requirements addressed

- Plan Phase 3, `80-backup.sh` bullet
- PRD §5.9 (Backup)
- PRD §10.1 table, 80-backup row
- PRD §10.2 (deep-module analysis, 80-backup)
- PRD User Story 21, 22, 23, 24, 25
- PRD §12 R5 (dev-database loss window mitigation)
