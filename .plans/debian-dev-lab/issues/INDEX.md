# Issues for Debian 13 Dev + Lab Automation

Generated from: ../../debian-dev-lab.md

## Overview

| #   | Title                                                  | Type | Phase | Blocked by         |
| --- | ------------------------------------------------------ | ---- | ----- | ------------------ |
| 001 | Repo skeleton + no-op `site.yml`                       | AFK  | 0     | None               |
| 002 | `docs/install.md` manual partitioning cheat sheet      | AFK  | 0     | None               |
| 003 | UTM rehearsal + `docs/rehearsal.md`                    | HITL | 0     | 001, 002           |
| 004 | Top-level `README.md`                                  | AFK  | 0     | 001                |
| 005 | `base` role                                            | AFK  | 1     | 003                |
| 006 | `hardware` role                                        | AFK  | 1     | 005                |
| 007 | `storage` role                                         | AFK  | 1     | 005                |
| 008 | `security` role with staged SSH                        | AFK  | 1     | 005                |
| 009 | Phase 1 smoke-test additions + VM rehearsal gate      | HITL | 1     | 006, 007, 008      |
| 010 | `desktop` role                                         | AFK  | 2     | 009                |
| 011 | `shell` role                                           | AFK  | 2     | 009                |
| 012 | `dev` role                                             | AFK  | 2     | 011                |
| 013 | `lab` role: Docker + Tailscale + Traefik + whoami      | AFK  | 2     | 008, 009           |
| 014 | P2 smoke-test additions + SSH tailnet rebind verify    | HITL | 2     | 010, 012, 013      |
| 015 | `backup` role: restic + rclone + Dropbox + retention   | AFK  | 3     | 007, 013           |
| 016 | `docs/rollback.md` + `recovery.md` + `drift.md`        | AFK  | 3     | 015                |
| 017 | `scripts/smoke-test.sh` final battery                  | AFK  | 3     | 015                |
| 018 | Dropbox desktop client 24-hour soak                    | HITL | 3     | 015                |
| 019 | PRD §9 acceptance walk on the real SER8                | HITL | 3     | 014, 016, 017      |

## Dependency graph

```
Phase 0:
  001 ─┬─► 003 ─► (Phase 1)
  002 ─┘
  001 ─► 004

Phase 1:
  003 ─► 005 ─┬─► 006 ─┐
              ├─► 007 ─┼─► 009 ─► (Phase 2)
              └─► 008 ─┘

Phase 2:
  009 ─┬─► 010 ──────────┐
       ├─► 011 ─► 012 ───┼─► 014 ─► (Phase 3)
       └─► 013 ──────────┘
  008 ─► 013

Phase 3:
  007 ─┐
       ├─► 015 ─┬─► 016 ─┐
  013 ─┘        ├─► 017 ─┼─► 019
                └─► 018  │
  014 ──────────────────┘
```

## HITL items requiring human time

- **003** — UTM walkthrough of `install.md` end-to-end.
- **009** — Drive Phase 1 idempotency gate on a clean VM clone, verify SSH staging in both states.
- **014** — Second Tailscale peer required for whoami round-trip; verify sshd rebinds to tailnet IP.
- **018** — 24-hour Dropbox client soak on encrypted btrfs.
- **019** — Manual walk of every PRD §9 user story on the real SER8.

## Notes

- All AFK issues are developed against the Phase 0 UTM VM clone, not the SER8. The real hardware first sees the playbook only at issue 019 (acceptance walk).
- Vault must be populated before issues 013 (optional `tailscale_auth_key`) and 015 (`dropbox_rclone_token`, `restic_passphrase`).
- v2 items (preset apps, k3s, preseed, TPM2, chezmoi, distrobox, Hyprland, Traefik HTTPS) are explicitly out of scope per PRD §13 and the plan's "Remaining work" section.
