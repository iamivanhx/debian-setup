# PRD §9 acceptance walk on the real SER8

## Type

HITL

## Phase

Phase 3: Backup Trilogy

## Parent plan

../../debian-dev-lab.md

## What to build

Walk every PRD §9 Given/When/Then acceptance criterion manually on the actual Beelink SER8 hardware. Tick each one off in `docs/acceptance.md` with the date and any notes. This is the v1 ship gate.

See parent plan, Phase 3 → "Acceptance runs" and "How to consume this plan".

## Acceptance criteria

- [ ] `docs/acceptance.md` created with one row per PRD §9 user story, columns: ID, summary, status, date, notes.
- [ ] Every PRD §9 story walked on the real SER8 (NOT the UTM VM).
- [ ] Every story marked Pass with a date, OR marked Fail with a pointer to the issue/role that needs fixing.
- [ ] Any failure is treated as a bug in the relevant phase, not as a Phase 3 problem — fix upstream and re-walk.
- [ ] When all stories pass, mark v1 shipped in `README.md` phase status.

## Blocked by

- 014-p2-smoke-test-and-tailnet-rebind.md
- 016-rollback-recovery-drift-docs.md
- 017-smoke-test-final.md

## Implementation notes

- HITL by definition: there is no way to automate "walk the acceptance criteria on the real machine".
- The acceptance walk is a gate, not a ceremony. If something fails, fix it; do not paper over it.
- This is the LAST issue. After this, v1 is shipped and the parked items in PRD §13 become the v2 backlog.

## Requirements addressed

- PRD §9 (every user story).
- Phase 3 → "Acceptance runs", "Acceptance walk".
