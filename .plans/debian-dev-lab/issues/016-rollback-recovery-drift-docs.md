# `docs/rollback.md` + `docs/recovery.md` + `docs/drift.md`

## Type

AFK

## Phase

Phase 3: Backup Trilogy

## Parent plan

../../debian-dev-lab.md

## What to build

Write the three operator docs that close the loop on rollback, recovery, and template drift. These are the runbooks the operator reaches for when something is on fire (or about to be).

See parent plan, Phase 3 → deliverables 3, 4, 5.

## Acceptance criteria

- [ ] `docs/rollback.md` documents a single-command snapper rollback procedure (and what to expect on the next boot).
- [ ] `docs/recovery.md` covers four scenarios:
  - [ ] (a) Local file recovery from `/srv/backups` btrfs snapshots.
  - [ ] (b) File recovery from restic.
  - [ ] (c) Tailscale-down LAN SSH recovery — flip `nftables_allow_lan_ssh`, re-run the playbook, regain access.
  - [ ] (d) Full disaster recovery: reinstall via `docs/install.md`, run the playbook, restic restore.
- [ ] `docs/drift.md` is a config-file-to-template traceability checklist: every on-box config file the playbook owns is mapped back to its template path under `ansible/roles/<role>/templates/`.
- [ ] All three docs use absolute paths and copy-pasteable commands.

## Blocked by

- 015-backup-role.md

## Implementation notes

- These docs are written for someone who is panicking. Optimize for "find the right command in 30 seconds", not for narrative.
- `drift.md` is the implementation of PRD §9 Story 30 — it makes the "edit the playbook, not the box" rule auditable.
- The LAN SSH recovery procedure assumes a `nftables_allow_lan_ssh` var exists in `security`. If not, add it as part of this issue (small).

## Requirements addressed

- Phase 3, deliverables 3, 4, 5.
- PRD §9 Story 30 (drift traceability).
