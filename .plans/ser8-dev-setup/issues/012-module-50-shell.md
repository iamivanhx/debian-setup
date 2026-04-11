# 50-shell module: zsh + starship + templated dotfiles

## Type

AFK

## Phase

Phase 2: Workstation

## Parent plan

../../ser8-dev-setup.md

## What to build

Fill in `modules/50-shell.sh` so that the primary user has zsh as their login shell, starship as their prompt, and templated dotfiles from the repo.

Concrete deliverables:

- Install apt packages: `zsh zsh-autosuggestions zsh-syntax-highlighting`.
- `chsh -s /usr/bin/zsh $USER` for the primary user, **guarded by `guard::user_shell_is`** (read `getent passwd` field 7).
- Install starship via `curl -sS https://starship.rs/install.sh | sh -s -- -y -b /usr/local/bin`, **guarded by `guard::command_exists starship`**. Pin to a specific version if feasible (check if starship's install script supports `--version`).
- Template `~/.zshrc` from `templates/home/user/.zshrc` via `deploy_config` run as the primary user. The template includes:
  - PATH export with `~/.local/share/pnpm` prepended ahead of `/usr/bin` (critical — see Implementation notes).
  - History config (size, ignoredups, extended history).
  - Source lines for `zsh-autosuggestions` and `zsh-syntax-highlighting` from their apt-installed paths.
  - `eval "$(starship init zsh)"`.
- Template `~/.config/starship.toml` from `templates/home/user/.config/starship.toml` via `deploy_config` run as the primary user.
- `smoke_50_shell`: `getent passwd $USER | cut -d: -f7 == /usr/bin/zsh`, `command -v starship`, `~/.zshrc` matches template, `~/.config/starship.toml` matches template, `zsh -ic 'echo $PATH' | tr : '\n' | head -1` resolves to the pnpm path (or is the FIRST segment that matches `pnpm`).

## Acceptance criteria

- [ ] `./run.sh 50-shell` on a converged Phase 1 + 40-desktop machine lands zsh as the primary user's shell.
- [ ] `./run.sh --dry-run 50-shell` on the converged box reports zero planned actions.
- [ ] Opening a new Konsole instance starts in zsh with the starship prompt visible.
- [ ] `echo $PATH` inside the shell shows `~/.local/share/pnpm` BEFORE `/usr/bin`.
- [ ] `smoke_50_shell` passes.
- [ ] Shellcheck + shfmt + pre-commit clean.

## Blocked by

- Blocked by 010-phase1-smoke-gate.md

## Implementation notes

- The pnpm PATH ordering is load-bearing: `60-dev` runs after this module and installs VS Code. If VS Code launches before pnpm is in PATH, its integrated terminal caches the wrong Node path and doesn't refresh cleanly. The `~/.zshrc` template must land the pnpm PATH entry before `60-dev` runs.
- Starship install is a `curl | sh`. Wrap with a `guard::command_exists starship` check so re-runs are instant no-ops.
- Use `run_as_user` for `chsh` (actually `chsh` needs root to change another user's shell — use `chsh -s /usr/bin/zsh $PRIMARY_USER` as root, not as the user). Verify the guard pattern.
- The existing `beelink_debian_post_install.sh` step 22 installs oh-my-zsh + a Gruvbox starship theme. **Ignore all of that.** Framework-free zsh, stock starship config. Non-goal.
- `deploy_config` writing to a user home directory must be `run_as_user` — otherwise the files end up owned by root and the user can't edit them.

## Requirements addressed

- Plan Phase 2, `50-shell.sh` bullet
- PRD §5.6 (Shell)
- PRD §10.1 table, 50-shell row
- PRD User Story 11, 12
- PRD Implementation notes on pnpm PATH ordering
