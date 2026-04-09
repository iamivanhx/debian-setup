# `shell` role

## Type

AFK

## Phase

Phase 2: Workstation + Lab

## Parent plan

../../debian-dev-lab.md

## What to build

Implement the `shell` role: install zsh, change the primary user's login shell to zsh, install `zsh-autosuggestions` and `zsh-syntax-highlighting` from apt, template `~/.zshrc` (with the pnpm PATH entry placed ahead of system PATH), install starship via the official installer, template `~/.config/starship.toml`. No framework (no oh-my-zsh, no prezto).

See parent plan, Phase 2 → `shell` deliverable, plus the implementation note about pnpm PATH ordering.

## Acceptance criteria

- [ ] `zsh` installed.
- [ ] Primary user's login shell is `/bin/zsh` (`getent passwd <user>`).
- [ ] `zsh-autosuggestions` and `zsh-syntax-highlighting` installed from apt and sourced in `~/.zshrc`.
- [ ] `~/.zshrc` is rendered from a Jinja template under `roles/shell/templates/`.
- [ ] In the rendered `~/.zshrc`, `~/.local/share/pnpm` (or equivalent pnpm bin path) appears in `PATH` BEFORE any system path.
- [ ] starship binary present, installed via the official installer (idempotent — guarded on existence/version).
- [ ] `~/.config/starship.toml` rendered from a template.
- [ ] No oh-my-zsh, no prezto, no zinit.
- [ ] `--check --diff` reports 0 changed tasks on a converged run.

## Blocked by

- 009-p1-smoke-test-and-vm-gate.md

## Implementation notes

- The pnpm PATH placement is load-bearing: it MUST be in place before `dev` runs so VS Code's first launch caches the right Node path. See PRD §10.2 dev module note.
- Starship installer is idempotent enough on its own, but wrap it with a `creates:` or version check so it doesn't re-download every run.

## Requirements addressed

- Phase 2, `shell` deliverable.
- PRD §10.2 (dev/shell PATH ordering note).
