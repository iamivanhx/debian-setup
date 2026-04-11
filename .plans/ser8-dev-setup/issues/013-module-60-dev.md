# 60-dev module: VS Code + pnpm + uv + Go

## Type

AFK

## Phase

Phase 2: Workstation

## Parent plan

../../ser8-dev-setup.md

## What to build

Fill in `modules/60-dev.sh` so that the primary user has the full daily toolchain installed.

Concrete deliverables:

- **Absence assertion first:** check that apt `nodejs` and `npm` packages are absent. If present, fail with `"apt purge nodejs npm"` instruction. This catches accidental installs by transitive deps since Phase 1.
- Microsoft apt repo + GPG key:
  - Dearmor the Microsoft GPG key to `/etc/apt/keyrings/microsoft.gpg` (guarded by `guard::file_exists`).
  - Template `/etc/apt/sources.list.d/vscode.list` referencing the keyring (guarded).
  - `apt update` (only if the sources file was just created).
- Install VS Code: `apt install code` (guarded by `guard::command_exists code`).
- Install pnpm as the primary user: `curl -fsSL https://get.pnpm.io/install.sh | sh -`, **guarded by `guard::command_exists pnpm`** (running as the primary user via `run_as_user`).
- `run_as_user pnpm env use --global lts`, guarded by checking if `~/.local/share/pnpm/node` symlink exists and points at a version.
- Install uv as the primary user: `curl -LsSf https://astral.sh/uv/install.sh | sh`, guarded by `guard::command_exists uv`.
- Install Go from backports: `apt install golang-go/trixie-backports` (guarded).
- `smoke_60_dev`: `command -v code pnpm uv go node git`, `dpkg -s nodejs 2>/dev/null` returns non-zero, `which node` resolves under `~/.local/share/pnpm` not `/usr/bin`, `node --version` prints an LTS version, `go version` prints a version.

## Acceptance criteria

- [ ] `./run.sh 60-dev` on a converged Phase 1 + 40-desktop + 50-shell machine lands the full toolchain.
- [ ] `./run.sh --dry-run 60-dev` on the converged box reports zero planned actions.
- [ ] In a new Konsole instance: `node`, `pnpm`, `python`, `uv`, `go`, `git`, `code` all resolve on PATH.
- [ ] `which node` resolves under pnpm's managed path, NOT `/usr/bin`.
- [ ] `apt install nodejs` (attempted) fails or is held.
- [ ] `smoke_60_dev` passes.
- [ ] Shellcheck + shfmt + pre-commit clean.

## Blocked by

- Blocked by 010-phase1-smoke-gate.md
- Blocked by 012-module-50-shell.md (pnpm PATH must be in `.zshrc` before VS Code first launches and caches its terminal env)

## Implementation notes

- The pre-flight `nodejs`/`npm` absence assertion is PRD User Story 38 in practice. Do not skip it.
- pnpm's install script writes to `~/.local/share/pnpm` — run it as the primary user, not root. `run_as_user` helper from `lib/common.sh`.
- After `pnpm env use --global lts`, `which node` inside a new shell must resolve under `~/.local/share/pnpm`. If it resolves to `/usr/bin/node`, something in apt pulled nodejs — the absence assertion should have caught it, and if it didn't, update the guard.
- Go from backports is a single `apt install` with the version selector. The backports repo is already configured by `00-base`.
- Socket.dev supply-chain scanning is a user-level decision (pnpm plugin config), not a machine concern — do not install anything here for it.
- VS Code extension sync is the user's responsibility; this module only installs the `code` binary.

## Requirements addressed

- Plan Phase 2, `60-dev.sh` bullet
- PRD §5.7 (Dev environment)
- PRD §10.1 table, 60-dev row
- PRD User Story 10, 13, 38
- PRD §12 R8 (nodejs/npm shadowing)
