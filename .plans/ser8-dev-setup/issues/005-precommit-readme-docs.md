# Pre-commit hook + README + docs/ skeletons

## Type

AFK

## Phase

Phase 0: Pre-flight

## Parent plan

../../ser8-dev-setup.md

## What to build

The enforcement plumbing and the remaining doc skeletons, wrapping up Phase 0.

### Pre-commit hook

A bash script at `scripts/pre-commit.sh` (the user symlinks it to `.git/hooks/pre-commit` on clone — documented in `README.md`). The hook:

1. Runs `shellcheck` on every changed `.sh` file under `lib/`, `modules/`, or `run.sh`. Errors block commit.
2. Runs `shfmt -d` on the same set. Diffs block commit.
3. Greps diff hunks for known destructive verbs (`apt install`, `apt-get install`, `cryptsetup luksFormat`, `mkfs`, `mount`, `ln -s`, `cp `, `systemctl enable`, `usermod`, `chsh`, `rm -rf`) and fails unless the surrounding context has either a `guard::` call on the same or previous line OR a `# SAFE_REPLAY:` comment on the line above.
4. Exits 0 if all checks pass.

### README.md (full content)

- Project purpose (one paragraph).
- Who it's for (audience of one).
- Clone + first-run command (`git clone <url> && cd debian-setup && ./run.sh`).
- The one-sentence rule: "Edit the automation, not the box."
- Phase status checklist (four boxes corresponding to the four plan phases).
- How to install the pre-commit hook (one line: `ln -sf ../../scripts/pre-commit.sh .git/hooks/pre-commit`).
- Link to `docs/install.md` for the initial install procedure.
- Link to `docs/recovery.md` for disaster recovery.
- Link to `docs/projects.md` for adding a Docker project.

### docs/ skeletons

- `docs/recovery.md` — skeleton document with section headings (`## Overview`, `## Expected time`, `## Reinstall procedure`, `## Restore from B2`, `## Unlock NVMe2`, `## Verify Docker volumes survived`, `## Restart projects`) and a "fleshed out in issue 017" note. Minimal prose — just the outline.
- `docs/projects.md` — skeleton with section headings (`## Overview`, `## Adding a project`, `## Traefik label reference`, `## Avahi alias convention`, `## Known footguns`). Minimal prose — just the outline.
- `docs/acceptance.md` — skeleton with one `### Phase N — <name>` subheading per plan phase and an empty checklist placeholder under each. Populated as each phase lands.

## Acceptance criteria

- [ ] `scripts/pre-commit.sh` exists, is executable, and performs all four checks above.
- [ ] Running `scripts/pre-commit.sh` manually on a clean tree exits 0.
- [ ] Running it on a tree with a `cp -r /etc /tmp/x` added (no guard, no SAFE_REPLAY) exits non-zero with a clear error.
- [ ] `README.md` contains all the sections listed above.
- [ ] `README.md` contains the pre-commit hook install command.
- [ ] `docs/recovery.md`, `docs/projects.md`, `docs/acceptance.md` exist with the documented skeleton structure.
- [ ] `shellcheck scripts/pre-commit.sh` passes.

## Blocked by

- Blocked by 001-repo-scaffold.md (needs `lib/`, `modules/`, `run.sh` to exist so the hook has something to check)

## Implementation notes

- The destructive-verb grep is intentionally simple (substring match, case-sensitive). False positives are expected at first and are a signal that the convention needs a SAFE_REPLAY comment added, not that the hook is wrong.
- The hook is best-effort protection — the real idempotency check is `./run.sh --dry-run` after every module edit.
- `docs/acceptance.md` is a living document: each phase's checklist fills in as the corresponding issues land. Keep this doc under active edit through Phase 3.

## Requirements addressed

- Plan Phase 0, pre-commit hook skeleton bullet
- Plan Phase 0, README and docs/ skeleton bullets
- PRD §12 R1 (idempotency discipline drift — pre-commit enforcement)
