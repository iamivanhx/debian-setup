# `docs/install.md` manual partitioning cheat sheet

## Type

AFK

## Phase

Phase 0: Pre-flight

## Parent plan

../../debian-dev-lab.md

## What to build

Write `docs/install.md`: a literal click-by-click walkthrough of the Debian 13 Trixie netinst installer that produces the exact disk layout the `storage` role will assert against. Two LUKS-encrypted btrfs disks, split-role per PRD §5.4, with the subvolume names the rest of the playbook depends on. This document is treated as production documentation: numbered steps, screenshots, zero branching.

See parent plan, Phase 0 → deliverables bullet 5, and Phase 0 implementation notes.

## Acceptance criteria

- [ ] Numbered, linear walkthrough — no "if/then" branches.
- [ ] Covers BIOS/UEFI setup, boot media selection, network/locale picks.
- [ ] LUKS container creation on both NVMes with the labels referenced by `storage`.
- [ ] btrfs subvolumes created on NVMe1: `@`, `@home`, `@var`, `@containers`, `@snapshots`.
- [ ] btrfs subvolumes created on NVMe2: `@data`, `@backups`.
- [ ] Documents fstab intent (mountpoints, options) for what `storage` will template.
- [ ] Screenshots embedded for every non-obvious installer screen.
- [ ] Reader with no prior context can complete the install end-to-end.

## Blocked by

None — can start immediately.

## Implementation notes

- This is the single most important deliverable of Phase 0. Treat the writing standard accordingly.
- Subvolume naming is locked — `storage` will fail loudly with "your install.md layout doesn't match" if names drift. Keep this doc and the `storage` role assertions in lockstep.
- Document the manual partitioning path in the Debian installer (guided + LVM is NOT what we want).

## Requirements addressed

- Phase 0, deliverable 5.
- PRD §5.4 (storage layout).
