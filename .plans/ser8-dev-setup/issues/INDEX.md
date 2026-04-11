# Issues for SER8 Dev + Test-Staging Setup

Generated from: ../../ser8-dev-setup.md
Source PRD: ../../../ideas/ser8-dev-setup/PRD.md

## Overview

Pushed to GitHub on 2026-04-11 — repo [iamivanhx/debian-setup](https://github.com/iamivanhx/debian-setup). Local file numbers match GitHub issue numbers 1:1 (issues #1–#18). All 29 blocking relationships wired via GraphQL.

| #   | Title                                                      | Type | Phase | Blocked by                   | GitHub                                                     |
| --- | ---------------------------------------------------------- | ---- | ----- | ---------------------------- | ---------------------------------------------------------- |
| 001 | Repo scaffold + run.sh + lib/common.sh + stubs             | AFK  | 0     | None                         | [#1](https://github.com/iamivanhx/debian-setup/issues/1)   |
| 002 | `lib/guards.sh` idempotency guard vocabulary               | AFK  | 0     | 001                          | [#2](https://github.com/iamivanhx/debian-setup/issues/2)   |
| 003 | `docs/install.md` click-by-click cheat sheet               | HITL | 0     | None                         | [#3](https://github.com/iamivanhx/debian-setup/issues/3)   |
| 004 | Delete four unrelated legacy scripts                       | AFK  | 0     | None                         | [#4](https://github.com/iamivanhx/debian-setup/issues/4)   |
| 005 | Pre-commit hook + README + docs/ skeletons                 | AFK  | 0     | 001                          | [#5](https://github.com/iamivanhx/debian-setup/issues/5)   |
| 006 | `00-base` module (apt + backports + holds + core pkgs)     | AFK  | 1     | 001, 002, 005                | [#6](https://github.com/iamivanhx/debian-setup/issues/6)   |
| 007 | `10-hardware` module (kernel + AMD + microcode + NVMe)     | AFK  | 1     | 006                          | [#7](https://github.com/iamivanhx/debian-setup/issues/7)   |
| 008 | `20-storage` module (NVMe2 LUKS + ext4 + Docker data-root) | AFK  | 1     | 006                          | [#8](https://github.com/iamivanhx/debian-setup/issues/8)   |
| 009 | `30-security` module (nftables + sshd + unattended + sudo) | AFK  | 1     | 006                          | [#9](https://github.com/iamivanhx/debian-setup/issues/9)   |
| 010 | Phase 1 smoke + dry-run gate on real SER8                  | HITL | 1     | 003, 006, 007, 008, 009      | [#10](https://github.com/iamivanhx/debian-setup/issues/10) |
| 011 | `40-desktop` module (Plasma 6 + SDDM + Nerd Font)          | AFK  | 2     | 010                          | [#11](https://github.com/iamivanhx/debian-setup/issues/11) |
| 012 | `50-shell` module (zsh + starship + dotfiles)              | AFK  | 2     | 010                          | [#12](https://github.com/iamivanhx/debian-setup/issues/12) |
| 013 | `60-dev` module (VS Code + pnpm + uv + Go)                 | AFK  | 2     | 010, 012                     | [#13](https://github.com/iamivanhx/debian-setup/issues/13) |
| 014 | Delete legacy beelink script after port verification       | HITL | 2     | 011, 012, 013                | [#14](https://github.com/iamivanhx/debian-setup/issues/14) |
| 015 | `70-lab` module (Docker + Traefik + Avahi + whoami)        | AFK  | 3     | 008, 014                     | [#15](https://github.com/iamivanhx/debian-setup/issues/15) |
| 016 | `80-backup` module (restic + B2 + timers)                  | AFK  | 3     | 008                          | [#16](https://github.com/iamivanhx/debian-setup/issues/16) |
| 017 | Flesh out recovery.md + projects.md + acceptance.md        | AFK  | 3     | 015, 016                     | [#17](https://github.com/iamivanhx/debian-setup/issues/17) |
| 018 | Disaster drill execution (v1 acceptance gate)              | HITL | 3     | 014, 015, 016, 017           | [#18](https://github.com/iamivanhx/debian-setup/issues/18) |

**Total: 18 issues — 14 AFK, 4 HITL.**

**Milestones:** [Phase 0: Pre-flight](https://github.com/iamivanhx/debian-setup/milestone/1), [Phase 1: Foundation](https://github.com/iamivanhx/debian-setup/milestone/2), [Phase 2: Workstation](https://github.com/iamivanhx/debian-setup/milestone/3), [Phase 3: Lab + Backup + Drill](https://github.com/iamivanhx/debian-setup/milestone/4).

## Dependency graph

```
Phase 0: pre-flight
  001 ─┬─► 002 ─┐
       └─► 005 ─┤
  003 (parallel) ┤
  004 (parallel) │
                 ▼ (Phase 1 can start)

Phase 1: foundation
  001+002+005 ─► 006 ─┬─► 007 ─┐
                      ├─► 008 ─┤
                      └─► 009 ─┤
                      003 ─────┤
                               ▼
                              010 (HITL gate)
                               │
                               ▼ (Phase 2 can start)

Phase 2: workstation
  010 ─┬─► 011 ────────────┐
       ├─► 012 ─► 013 ─────┤
       └──────────────────►│
                           ▼
                          014 (HITL cleanup)
                           │
                           ▼ (Phase 3 can start)

Phase 3: lab + backup + drill
  008 ─┐
       ├─► 015 ─┐
  014 ─┘        │
                ├─► 017 ─┐
  008 ─► 016 ───┘        │
                         ├─► 018 (HITL drill, v1 gate)
  014 ─────────────────►│
  015 ─────────────────►│
  016 ─────────────────►│
```

## HITL items requiring human time

- **003** (Phase 0) — walk `docs/install.md` through a real (or UTM) Debian netinst and capture screenshots. Runs in parallel with the AFK Phase 0 work. ~2 hours.
- **010** (Phase 1 gate) — clean install + run the first four modules on the real SER8 (or clean clone). First real bug-fix cycle. ~half a day.
- **014** (Phase 2 cleanup) — porting audit of the legacy beelink script. ~1 hour of careful review, then a single commit.
- **018** (Phase 3 v1 gate) — the disaster drill. Wipe NVMe1, reinstall, rerun, restore, verify NVMe2 volumes survived, walk acceptance.md. **Mandatory; blocks v1.** Target ≤ 4 hours per PRD Success Metric #5.

## Notes on execution order

- **Issues 001–005 can be worked in parallel** except 002 and 005, which require 001's `lib/` and `run.sh` scaffold. 003 (install.md) and 004 (legacy delete) have no blockers.
- **Issues 006–009 (Phase 1 modules) can be worked in parallel** after 006, except they each need 006's apt sources to land first.
- **Issue 010 is the first hard gate** — Phase 2 cannot start until Phase 1 is green on the real SER8. Bugs found here must be fixed in the corresponding module issue and 010 re-run.
- **Issues 011–013 (Phase 2 modules) have one internal ordering constraint**: 013 (60-dev) depends on 012 (50-shell) because pnpm's PATH entry in `~/.zshrc` must land before VS Code first launches and caches its terminal env.
- **Issue 014 is the porting audit** — do not rush. It's short but it's the moment where the repo commits to having one source of truth.
- **Issues 015 and 016 can be worked in parallel** after 014 (Phase 2 clean) and 008 (storage landed) — they touch different modules and only converge in 017's documentation.
- **Issue 018 is the v1 gate.** Everything lands here. If it fails, the responsible issue is reopened.

## Notes on scope

- v1 issues implement the PRD scope **exactly as written**. Parked items in the PRD §13 Open Questions or Plan "Remaining work" section are NOT in these 18 issues:
  - No HTTPS / TLS in the lab (defer until a project needs it).
  - No per-project dev-database backup hooks (defer until it hurts).
  - No auto-removal of Avahi aliases (manual for v1).
  - No retention tuning (default 7d/4w/6m, revisit after a month).
- Secrets (Backblaze B2 keys, restic passphrase, NVMe2 LUKS passphrase, SSH authorized keys, timezone + LAN subnet + power profile variables) must all be populated in `~/.config/ser8-setup/secrets.env` before the corresponding issues execute against real hardware. This is documented in `docs/install.md` (issue 003) and `docs/recovery.md` (issue 017).
- The existing `beelink_debian_post_install.sh` remains in the repo root through the end of Phase 2 and is deleted in issue 014. Treat it as the **porting source of truth** for modules 00-base through 60-dev — when in doubt about a hardware/desktop/shell/dev detail, check the legacy script first, then decide whether to port or drop.
