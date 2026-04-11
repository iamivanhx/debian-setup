# Disaster drill execution — the v1 acceptance gate

## Type

HITL

## Phase

Phase 3: Lab + Backup + Disaster Drill

## Parent plan

../../ser8-dev-setup.md

## What to build

The mandatory disaster drill. This is the final issue in v1, the acceptance gate for the project, and the real-world test of Risk R4 (reinstall-and-rerun is load-bearing) and Risk R6 (Docker volumes survive NVMe1 reinstall).

**If this drill fails, v1 is not done. Fix the responsible module, delete the issue tick, and re-run the drill from scratch.**

### Pre-drill state

- All previous issues (001–017) closed, all smoke tests green on the real SER8.
- At least one real project is running in `/srv/data/lab/compose/<project>/` with some state in `/srv/data/docker/volumes/` (can be the `whoami` reference or a throwaway test project — the point is that NVMe2 has real Docker volume data to preserve).
- At least one `./run.sh backup now` has completed successfully and `restic snapshots` shows a recent entry in B2.
- `~/testdir/` has been created with a known file (`~/testdir/canary.txt`) and included in the latest snapshot.

### Drill procedure

1. **Wipe NVMe1.** Boot the Debian 13 netinst USB, use the installer's disk utility or `wipefs -a /dev/nvme0n1` from the installer's shell. **Leave NVMe2 (/dev/nvme1n1) untouched** — do not even unlock it during this step.
2. **Reinstall Debian.** Follow `docs/install.md` exactly. If any step is unclear or wrong, stop and fix the doc before continuing — this drill doubles as a doc test.
3. **First boot.** Log in as the primary user. Install `git` (`sudo apt install git`). Clone the repo.
4. **Recreate secrets.env** from your password manager per `docs/install.md`. Verify every required key is present.
5. **Unlock NVMe2 before running `./run.sh`.** Follow `docs/recovery.md`: `cryptsetup open /dev/nvme1n1 srv-data` (enter the passphrase from `NVME2_LUKS_PASSPHRASE` in secrets.env), `mount /dev/mapper/srv-data /srv/data`. Verify `/srv/data/docker/volumes/` still contains the pre-wipe data.
6. **Run `./run.sh`.** Exits 0 after all nine modules. `20-storage.sh` should NOT reformat NVMe2 (its `cryptsetup isLuks` guard must catch this). Verify via `blkid /dev/nvme1n1` showing the same UUID as pre-wipe.
7. **Run `./run.sh smoke`.** Every module's smoke test passes.
8. **Run `./run.sh --dry-run`.** Zero planned actions across every module.
9. **Restore /home from B2.** Follow `docs/recovery.md`'s restic restore procedure. Verify `~/testdir/canary.txt` is back.
10. **Restart the pre-wipe project(s).** `docker compose up -d` in each `/srv/data/lab/compose/<name>/` directory. Containers come up. `http://<project>.local` resolves from a LAN client and returns the expected response. If any project was using a named Docker volume, verify the volume's data is intact.
11. **Walk `docs/acceptance.md` top-to-bottom.** Tick every checkbox. Any that fail → stop, fix, and restart the drill.
12. **Time the drill.** Record total wall-clock time from "press power button after wipe" to "all checkboxes green." Target is ≤ 4 hours per PRD Success Metric #5.
13. **Commit the drill result.** Add a "v1 acceptance walk passed on <date>" line to `README.md` or create a `v1-acceptance` git tag as the explicit record.

### After the drill passes

- v1 is done.
- Mark issue 018 complete.
- Pipeline has no blocking work left until the next feature or a Phase 3+1 (HTTPS, per-project hooks, retention tuning) arises.

### If the drill fails

- File a bug against the responsible module issue (reopen it).
- Fix the module.
- Nuke the partial-drill state (may require another wipe + reinstall — yes, this is expensive).
- Re-run the drill from step 1. Do not declare v1 done until the drill passes with zero fixes needed mid-drill.

## Acceptance criteria

- [ ] Pre-drill state established (running project, backup snapshot, canary file in /home).
- [ ] NVMe1 wiped cleanly (confirmed via installer showing the disk as empty/uninitialized).
- [ ] Debian reinstalled per `docs/install.md` without doc corrections needed mid-install (doc corrections found become a bug against issue 003).
- [ ] NVMe2 unlocked with passphrase pre-`run.sh` per `docs/recovery.md`.
- [ ] `/srv/data/docker/volumes/` contents match pre-wipe state (spot-checked).
- [ ] `./run.sh` exits 0 on first post-wipe run.
- [ ] `./run.sh --dry-run` and `./run.sh smoke` both clean after the first run.
- [ ] `blkid /dev/nvme1n1` shows the same LUKS UUID pre- and post-drill (NVMe2 was NOT reformatted).
- [ ] `/home/<user>/testdir/canary.txt` restored from restic.
- [ ] Pre-wipe projects restarted and reachable via Traefik from a LAN client.
- [ ] `docs/acceptance.md` walked top-to-bottom, every checkbox green.
- [ ] Total drill wall-clock time recorded and documented (target ≤ 4 hours).
- [ ] `README.md` updated with "v1 acceptance walk passed" line AND/OR a `v1-acceptance` git tag created.

## Blocked by

- Blocked by 014-delete-legacy-beelink.md
- Blocked by 015-module-70-lab.md
- Blocked by 016-module-80-backup.md
- Blocked by 017-docs-flesh-out.md

## Implementation notes

- This drill is expensive and scary, which is exactly why it exists. If you're tempted to skip it, re-read PRD §12 R4 and R6 until the temptation passes.
- Do the drill on a **Saturday morning** (or whatever block of 4–6 hours you have) — not in the middle of a workday.
- Bring a notepad. Expect to find two or three small bugs during the walkthrough. That's normal for a first-time drill; they're what the drill exists to catch.
- If you find a bug that requires a second wipe to retest, do the second wipe. The cost of a second wipe is lower than the cost of shipping a broken recovery story that only surfaces during a real disaster.
- The time budget of 4 hours is tight. If it's taking much longer, the modules have too many manual intervention points and need a follow-up pass to automate them out.
- After the drill, consider whether to run it AGAIN in 6 months as a refresh. This is deferred to user discretion.

## Requirements addressed

- Plan Phase 3, "Disaster drill execution" bullet
- PRD §9 Recovery drill acceptance criteria
- PRD §12 R4 (reinstall-and-rerun is load-bearing)
- PRD §12 R6 (Docker volumes survive reinstall)
- PRD Success Metric #5 (recovery drill time ≤ 4 hours)
- PRD User Story 6, 7, 8
