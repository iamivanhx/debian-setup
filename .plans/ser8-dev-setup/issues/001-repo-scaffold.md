# Repo scaffold: run.sh + lib/common.sh + empty module stubs

## Type

AFK

## Phase

Phase 0: Pre-flight

## Parent plan

../../ser8-dev-setup.md

## What to build

The runnable-but-no-op repo skeleton. At the end of this issue, `./run.sh` exits 0 on any machine (the modules are empty stubs), and every subsequent issue can land by filling in one module file.

Specifically:

- `README.md` at the repo root — top-level "edit the automation, not the box" rule, clone/run command, a "phase status" checklist.
- `run.sh` — entrypoint. Sources `lib/common.sh`, sources `~/.config/ser8-setup/secrets.env` (fails loudly with a `docs/install.md` pointer if absent), parses CLI flags/subcommands (`./run.sh`, `./run.sh <module>`, `./run.sh --dry-run [module]`, `./run.sh smoke [module]`, `./run.sh backup now`, `./run.sh lint`, `./run.sh lab-up <project>`), iterates `modules/*.sh` in sorted order for the default case, exits non-zero on first module failure.
- `lib/common.sh` — ported from the existing `beelink_debian_post_install.sh`:
  - `deploy_config <target>` (line 68 in the existing script) — atomic config write with timestamped backup. Augmented with a `--diff` mode for `--dry-run`.
  - `safe_install <pkg...>` (line 82) — apt-install-if-absent.
  - `info`/`warn`/`error`/`success`/`step` logging helpers (lines 48–55).
  - `run_as_user <cmd>` — run a command as the primary (non-root) user via `sudo -u`.
- `modules/00-base.sh` … `modules/80-backup.sh` — **empty stubs only**. Each file contains:
  - A top-of-file comment pointing at the PRD and plan section to be filled in.
  - A `step "<module name>"` call.
  - A `smoke_<name>() { :; }` no-op function.
- `templates/` — empty directory tree mirroring target on-disk layout: `templates/etc/`, `templates/home/user/`, `templates/home/user/.config/`, `templates/srv/data/lab/`, `templates/systemd/`. Empty `.gitkeep` files where needed.

## Acceptance criteria

- [ ] `./run.sh` against a fresh clone exits 0 with every module stub reporting its name via `step`.
- [ ] `./run.sh 20-storage` runs only that module's stub.
- [ ] `./run.sh smoke` iterates every `smoke_*` function and reports pass for all (no-ops).
- [ ] `./run.sh` with a missing `secrets.env` fails at the top with a clear error pointing at `docs/install.md`.
- [ ] `shellcheck run.sh lib/*.sh modules/*.sh` passes with no errors.
- [ ] `README.md` documents the rule, the clone/run command, and the phase status checklist.
- [ ] `lib/common.sh` contains the five helpers (`deploy_config`, `safe_install`, `info`/`warn`/`error`/`success`/`step`, `run_as_user`) with doctest-style examples in comments.

## Blocked by

None — can start immediately.

## Implementation notes

- Port the five helpers from `beelink_debian_post_install.sh` lines 48–82 verbatim where the behavior is correct; only rename/reformat.
- `run.sh` is non-interactive by policy — no `read`, no `ask_yes_no`. Everything is a flag, a variable, a secret, or a hard failure.
- Module stubs exist so later issues are "fill in this one file" work, not "create this file AND wire it into the driver." Wiring belongs in `run.sh` and lands here.
- The `--dry-run` flag sets a shell global `DRY_RUN=1` that modules are expected to consult via a `lib/common.sh` helper (e.g. `dry_run_echo "<description>"`). Full dry-run integration is completed in the module issues, not here.

## Requirements addressed

- Plan Phase 0, all bullets
- PRD §4 (Proposed Solution — high-level shape)
- PRD §10.5 (run.sh entrypoint)
- PRD §10.4 (carried-over helpers)
