# Top-level `README.md`

## Type

AFK

## Phase

Phase 0: Pre-flight

## Parent plan

../../debian-dev-lab.md

## What to build

Write the top-level `README.md` that frames the repo for the human operator: the "edit the playbook, not the box" rule, the clone/run command, and the current phase status table.

See parent plan, Phase 0 → deliverables bullet 8.

## Acceptance criteria

- [ ] States the operating principle: "edit the playbook, not the box".
- [ ] Documents the clone command.
- [ ] Documents the canonical run command: `ansible-playbook --ask-vault-pass -K site.yml`.
- [ ] Includes a phase status table (Phase 0 / 1 / 2 / 3 with status: in-progress, blocked, done, etc.).
- [ ] Links to `docs/install.md`, `docs/rehearsal.md`, `.plans/debian-dev-lab.md`, and `ideas/debian-dev-lab/PRD.md`.

## Blocked by

- 001-repo-skeleton.md

## Implementation notes

- Keep this short. README is signpost, not documentation. Detail lives in `docs/`.
- Phase status will be updated continuously as later phases land — leave it in a format that's cheap to edit.

## Requirements addressed

- Phase 0, deliverable 8.
