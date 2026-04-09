# UTM rehearsal + `docs/rehearsal.md`

## Type

HITL

## Phase

Phase 0: Pre-flight

## Parent plan

../../debian-dev-lab.md

## What to build

Write `docs/rehearsal.md` (UTM setup instructions for macOS) and then actually walk `docs/install.md` end-to-end inside a UTM VM until a clean run produces a booting Debian 13 system with the expected disk layout. Errors caught during rehearsal are fixed in `install.md`, never papered over in prose.

See parent plan, Phase 0 → deliverables bullets 6–7, implementation notes.

## Acceptance criteria

- [ ] `docs/rehearsal.md` documents UTM VM sizing (4 CPU / 8 GB RAM / 40 GB disk1 / 20 GB disk2), Debian 13 netinst ISO source, BIOS vs UEFI choice, network mode.
- [ ] At least one full UTM walkthrough of `docs/install.md` reaches a login prompt.
- [ ] Any deviation between `install.md` and the actual installer flow has been corrected in `install.md` and re-validated.
- [ ] Resulting VM has the PRD §5.4 subvolume layout (`btrfs subvolume list /` shows the expected names).
- [ ] A snapshot/clone of the post-install VM exists, ready to be used as the development substrate for Phase 1.

## Blocked by

- 001-repo-skeleton.md
- 002-install-cheat-sheet.md

## Implementation notes

- HITL: a human must drive the UTM installer. Plan that time.
- The "post-rehearsal VM clone" is the substrate every later phase develops against — name it and keep it. Don't develop against the SER8 until Phase 3 acceptance.
- UTM uses Hypervisor.framework on Apple Silicon; document any architecture-specific gotchas you hit.

## Requirements addressed

- Phase 0, deliverables 6, 7.
- Phase 0 → blocking dependency on Phase 1.
