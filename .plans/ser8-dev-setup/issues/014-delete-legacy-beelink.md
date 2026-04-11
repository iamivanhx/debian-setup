# Delete legacy beelink_debian_post_install.sh after port verification

## Type

HITL

## Phase

Phase 2: Workstation

## Parent plan

../../ser8-dev-setup.md

## What to build

The final act of Phase 2. After modules 40-desktop, 50-shell, and 60-dev have landed AND been verified against the real SER8, confirm that every piece of working content from `beelink_debian_post_install.sh` has been ported into one of the new modules, then delete the legacy script.

This is HITL because "every piece has been ported" is a human judgment — a diff review, not an automated check.

Steps:

1. Open `beelink_debian_post_install.sh` and walk its 25 numbered steps.
2. For each step, identify which new module contains the ported equivalent, or confirm the step is intentionally out of scope (e.g. UFW → replaced by nftables; GNOME → replaced by Plasma; oh-my-zsh → dropped entirely).
3. Produce a short porting-audit document (`docs/porting-audit.md` or inline in the PR description) that lists every legacy step with: "ported to <module>" OR "dropped because <reason>" OR "carried forward into <later phase>".
4. If any step is missing a disposition, halt and create a new issue to port or explicitly drop it.
5. Once the audit shows every step is accounted for, `git rm beelink_debian_post_install.sh` and commit with a message that references the audit.
6. Update `README.md` to remove any residual references to the script and to reflect that there is now one source of truth.

## Acceptance criteria

- [ ] `docs/porting-audit.md` (or equivalent PR-description doc) exists and accounts for all 25 numbered steps from the legacy script.
- [ ] Every step is either "ported to module X (line Y)", "dropped (reason)", or "carried forward (issue Z)".
- [ ] `beelink_debian_post_install.sh` no longer exists at the repo root.
- [ ] `README.md` has no references to the legacy script.
- [ ] Commit message includes "delete legacy beelink_debian_post_install.sh after full port" and references the audit.
- [ ] Phase 2 section of `docs/acceptance.md` has a "v1 source of truth consolidated" checkbox ticked.

## Blocked by

- Blocked by 011-module-40-desktop.md
- Blocked by 012-module-50-shell.md
- Blocked by 013-module-60-dev.md

## Implementation notes

- This is not a trivial `rm` — it's the moment where the repo commits to having one source of truth. Rushing this step risks silently losing a working line of config that was in the old script.
- The audit document can live in the PR description, in `docs/porting-audit.md`, or in a commit message body — whichever keeps the provenance most accessible. If in doubt, `docs/porting-audit.md` (short file, permanent record).
- A "dropped" disposition is legitimate for anything the PRD explicitly non-goals. For example: UFW/fail2ban/GNOME-extensions/oh-my-zsh/Gruvbox-theming are all "dropped by PRD §6" and that's the full justification.
- This is the LAST time `beelink_debian_post_install.sh` is referenced in the repo. After this issue closes, it only exists in git history.

## Requirements addressed

- Plan Phase 2, "Legacy cleanup (final)" bullet
- Plan "Decisions resolved during planning" (legacy script fate)
- PRD User Story 40
