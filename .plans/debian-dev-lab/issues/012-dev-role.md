# `dev` role

## Type

AFK

## Phase

Phase 2: Workstation + Lab

## Parent plan

../../debian-dev-lab.md

## What to build

Implement the `dev` role: VS Code from the Microsoft apt repository, pnpm via the official install script with `pnpm env use --global lts`, uv via the official install script, Go from `trixie-backports`, and a pre-flight assertion that `nodejs` and `npm` from apt are absent (with a clear remediation message pointing at `apt purge nodejs npm`).

See parent plan, Phase 2 → `dev` deliverable, plus PRD §10.2 dev module.

## Acceptance criteria

- [ ] Microsoft apt repo + signing key configured idempotently; `code` package installed.
- [ ] pnpm installed via the upstream script for the primary user (idempotent — guarded on `pnpm --version`).
- [ ] `pnpm env use --global lts` has been run as the primary user; `node --version` resolves under pnpm-managed path.
- [ ] uv installed via the upstream script (idempotent — guarded on `uv --version`).
- [ ] `golang-go` installed from `trixie-backports`.
- [ ] Pre-flight assertion: `dpkg -s nodejs` and `dpkg -s npm` both fail. Otherwise role aborts with a message instructing the operator to `apt purge nodejs npm`.
- [ ] `--check --diff` reports 0 changed tasks on a converged run.

## Blocked by

- 011-shell-role.md

## Implementation notes

- The `shell` → `dev` ordering exists because VS Code's first launch caches the Node path from the user's current PATH. If `~/.zshrc` doesn't yet have the pnpm path first, VS Code will pin the wrong Node and stay broken until its caches are nuked.
- pnpm and uv installers run as the primary user, not root. Use `become_user`.
- Apt `nodejs` is permanently held by `base` — this assertion exists to catch human error if someone unholds it.

## Requirements addressed

- Phase 2, `dev` deliverable.
- PRD §10.2 dev module (PATH ordering risk).
- User memory: Node via pnpm (no npm/nvm), Python via uv only, Go.
