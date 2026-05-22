# 60-dev module: VS Code + mise + Ruby/Rails build deps + sfw

## Type

AFK

## Phase

Phase 2: Workstation

## Parent plan

../../ser8-dev-setup.md

## What to build

Fill in `modules/60-dev.sh` so that the primary user has the full daily
toolchain installed.  Runtime strategy is **mise** (Node, Python, Ruby,
Go) — superseding the earlier pnpm + uv + apt-`golang-go` plan.

Concrete deliverables:

- **Mise apt repo + GPG key:**
  - Dearmor the mise GPG key to `/etc/apt/keyrings/mise-archive-keyring.gpg` (guarded by `guard::file_exists`).
  - Template `/etc/apt/sources.list.d/mise.list` referencing the keyring (guarded).
  - `apt update` only if either of the two above changed.
- **Apt installs (one `safe_install` batch):**
  - `mise` — the runtime manager.
  - **Ruby/Rails build deps** (used by mise's `ruby-build` and by common gem natives): `autoconf bison clang libssl-dev libreadline-dev zlib1g-dev libyaml-dev libncurses-dev libffi-dev libgdbm-dev libjemalloc2 libpq-dev libsqlite3-dev default-libmysqlclient-dev`.
  - **DB clients:** `postgresql-client redis-tools sqlite3`.
  - **Dev TUI:** `lazygit`.
- **VS Code:** download the official `.deb` from `code.visualstudio.com` and install via `apt-get install`; the postinst registers `/etc/apt/sources.list.d/vscode.sources` so future updates flow via apt.  Guarded by `guard::package_installed code`.
- **lazydocker:** download the pinned upstream tarball (`LAZYDOCKER_VERSION`), extract, install to `/usr/local/bin/lazydocker`.  Guarded by `guard::command_exists lazydocker`.
- **Socket Firewall (sfw) — supply-chain wrapper:**
  - As the primary user (`run_as_user`): `mise use --global node@lts`, `mise install node@lts`, `mise exec node@lts -- npm install -g sfw`, `mise reshim`.
  - Guarded by `test -x ~/.local/share/mise/shims/sfw`.
  - The `pnpm()` function wrapper in the 50-shell `.zshrc` template routes `pnpm install` through `sfw` whenever it is on PATH.
- **`smoke_60_dev`:** asserts the mise apt repo + keyring + sources file, the apt-installed package set, `mise lazygit lazydocker code` on PATH, the `node` and `sfw` shims under `~/.local/share/mise/shims/`, and that apt's `ruby` (if installed) is held by `apt-mark` (00-base sets the hold).

## Acceptance criteria

- [x] `./run.sh 60-dev` on a converged Phase 1 + 40-desktop + 50-shell machine lands the full toolchain.
- [x] `./run.sh --dry-run 60-dev` on the converged box reports zero planned actions.
- [x] In a new shell: `mise`, `code`, `lazygit`, `lazydocker`, `git`, and `sfw` resolve on PATH.  After `mise install`, `node` resolves under `~/.local/share/mise/shims/`, not `/usr/bin/`.
- [x] `apt install nodejs` (attempted) fails or is held (enforced by 00-base; 50-shell smoke verifies PATH ordering; 60-dev smoke verifies the ruby hold).
- [x] `pnpm install` in any project is automatically wrapped by `sfw` (function defined in `~/.zshrc`).
- [x] `smoke_60_dev` passes.
- [x] Shellcheck clean.

## Blocked by

- Blocked by 010-phase1-smoke-gate.md
- Blocked by 012-module-50-shell.md (mise activation must be in `.zshrc` before VS Code first launches and caches its terminal env; `pnpm` function wrapper also lives in the same template)

## Implementation notes

- Apt-mark hold on `nodejs npm ruby` is set in `00-base`; 60-dev re-asserts the `ruby` hold in its smoke because it's the module that depends on mise winning over apt's Ruby.
- `mise install node@lts` downloads + builds Node (~30s on first run, ~200MB on disk).  The `~/.local/share/mise/shims/sfw` guard makes the whole bootstrap a one-time cost.
- `mise reshim` is called explicitly after `npm install -g sfw` so the shim is created in the same run; otherwise the user would not see `sfw` on PATH until the next `mise activate`.
- VS Code extension sync is the user's responsibility; this module only installs the `code` binary.

## Direction notes

- **2026-05-20:** PRD §5.7 rewritten — `mise` replaces the earlier pnpm + uv + apt-`golang-go` plan as the single runtime manager.  See memory `project-runtime-manager`.
- **2026-05-22:** PRD §5.7 amended — Socket Firewall (`sfw`) is now installed host-globally by this module (was previously documented as user-level).

## Requirements addressed

- Plan Phase 2, `60-dev.sh` bullet
- PRD §5.7 (Dev environment)
- PRD §10.1 table, 60-dev row
- PRD User Story 10, 13, 38
- PRD §12 R8 (nodejs/npm shadowing)
