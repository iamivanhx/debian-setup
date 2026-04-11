# Phase 1 smoke + idempotency gate on the real SER8

## Type

HITL

## Phase

Phase 1: Foundation

## Parent plan

../../ser8-dev-setup.md

## What to build

The Phase 1 acceptance gate. This is the first issue that requires you to actually run the automation against the real SER8 (or a clean VM clone equivalent). Phase 2 cannot start until this passes.

Steps:

1. Do a **clean Debian 13 netinst** on the SER8 following `docs/install.md` (issue 003). This exercises install.md for the first time end-to-end — expect to find errors and fix them.
2. After first boot and creating `secrets.env`, clone the repo and run `./run.sh`. It should execute all four landed modules (`00-base`, `10-hardware`, `20-storage`, `30-security`) and exit 0.
3. **Capture the run output** into `docs/acceptance.md` Phase 1 section — paste the tail of the run log as evidence.
4. Run `./run.sh --dry-run`. It MUST report zero planned actions for every landed module. Any non-zero → file a bug against the responsible module and fix it before this issue closes.
5. Run `./run.sh smoke`. All four `smoke_*` functions must pass.
6. Reboot the SER8. After reboot, `/srv/data` must be mounted automatically (keyfile unlock worked), SSH from a LAN client must work, and `nft list ruleset` must still match the templated ruleset.
7. Attempt SSH from a non-LAN host (use your phone on cellular, or another device on a different subnet). The connection must fail (timeout).
8. Fill in the Phase 1 section of `docs/acceptance.md` with pass/fail for each of the above checks.

## Acceptance criteria

- [ ] A clean Debian 13 install on the real SER8 (or a rehearsed clone) was performed following `docs/install.md`.
- [ ] `./run.sh` on that machine exits 0 after the first pass.
- [ ] `./run.sh --dry-run` reports zero planned actions.
- [ ] `./run.sh smoke` passes for all four modules.
- [ ] Reboot leaves `/srv/data` mounted, SSH reachable from LAN, nftables loaded.
- [ ] SSH from outside the LAN subnet is blocked (demonstrated).
- [ ] `docs/acceptance.md` Phase 1 section filled in with evidence (run log tails, smoke output, screenshots if needed).
- [ ] Any bugs discovered are filed against the responsible module issue and fixed BEFORE this issue closes.

## Blocked by

- Blocked by 003-docs-install.md
- Blocked by 006-module-00-base.md
- Blocked by 007-module-10-hardware.md
- Blocked by 008-module-20-storage.md
- Blocked by 009-module-30-security.md

## Implementation notes

- This is HITL because it requires physically interacting with the SER8 (or equivalent clean install). Expect the first walkthrough to surface `docs/install.md` errors — fix them in-place and update the doc.
- If the SER8 has irreplaceable data on NVMe2 from earlier experiments, back it up OR test on a loop device first (see issue 008). This gate is explicitly about exercising a clean install, so ideally the SER8 is fresh.
- This gate is also an implicit test of the disaster drill's prerequisites — if Phase 1 install + run doesn't converge cleanly, the Phase 3 disaster drill will fail.
- Budget: half a day for the walkthrough + bug-fix cycle. If it takes more than a day, something is fundamentally wrong with the modules and they need a debugging pass.

## Requirements addressed

- Plan Phase 1 Blocking dependencies (Phase 2 cannot start until Phase 1 is green)
- PRD §9 First-run convergence acceptance criteria
- PRD §9 Security posture acceptance criteria
- PRD User Story 1, 2, 3, 4
