# 00-base module: apt sources, backports pinning, core packages

## Type

AFK

## Phase

Phase 1: Foundation

## Parent plan

../../ser8-dev-setup.md

## What to build

Fill in `modules/00-base.sh` so that it converges a fresh Debian 13 Trixie install's apt stack and core tooling.

Concrete deliverables:

- Templated `/etc/apt/sources.list.d/backports.list` enabling `trixie-backports` (main + contrib + non-free-firmware components).
- Templated `/etc/apt/preferences.d/backports` pinning backports packages low by default; kernel and AMD firmware will be pinned high by the 10-hardware module.
- OS gate assertion: detect Trixie via `/etc/os-release`; fail loudly with the detected distro name if non-Trixie.
- `apt update && apt -y upgrade` (guarded to skip if a previous run is fresh enough — or just always run; upgrade is idempotent).
- `apt-mark hold nodejs npm` (guarded by `guard::package_held`).
- Install core CLI packages: `git build-essential make jq curl wget htop ripgrep fd-find bat tree unzip ca-certificates gnupg lsb-release`.
- Locale configuration: generate `en_US.UTF-8` if missing, set it as the default via `update-locale LANG=en_US.UTF-8`.
- Timezone configuration: `timedatectl set-timezone "$TIMEZONE"` where `$TIMEZONE` is sourced from a variable at the top of `run.sh` (default `Europe/Madrid` or whatever the user has indicated — configurable).
- `smoke_00_base` function at the bottom that checks: backports repo present, `dpkg -s` succeeds on every core package, `apt-mark showhold` lists `nodejs` and `npm`, `locale -a | grep -q en_US.utf8`, `timedatectl show -p Timezone --value` matches `$TIMEZONE`.

Every destructive action (`apt install`, `apt-mark hold`, `timedatectl`, `update-locale`, `deploy_config`) wrapped in a `guard::*` check or annotated with `# SAFE_REPLAY:`.

## Acceptance criteria

- [ ] `./run.sh 00-base` on a fresh Trixie install exits 0 and converges all listed state.
- [ ] A second `./run.sh 00-base` run reports zero destructive actions (verified via `./run.sh --dry-run 00-base`).
- [ ] `./run.sh 00-base` on non-Trixie (e.g. Bookworm) fails with the detected distro name.
- [ ] `smoke_00_base` passes on the converged machine.
- [ ] Shellcheck + shfmt clean.
- [ ] Pre-commit hook doesn't flag any unguarded destructive verbs.

## Blocked by

- Blocked by 001-repo-scaffold.md
- Blocked by 002-lib-guards.md
- Blocked by 005-precommit-readme-docs.md (the hook must exist before the first module lands so its rules apply from the start)

## Implementation notes

- Port the apt-sources and locale logic from `beelink_debian_post_install.sh` step 1 (look for the apt sources and upgrade section). Reformat and re-template; don't copy verbatim.
- The `apt-mark hold nodejs npm` + absence-assertion strategy is belt-and-suspenders — the hold prevents accidental install, the assertion in 60-dev catches accidents.
- Locale generation requires running `locale-gen` after editing `/etc/locale.gen`. Guard by checking `locale -a` output.
- `TIMEZONE` should be declared at the top of `run.sh` as `TIMEZONE="${TIMEZONE:-Europe/Madrid}"` so it's overridable by env var at runtime.

## Requirements addressed

- Plan Phase 1, `00-base.sh` bullet
- PRD §5.2 (Base OS + backports)
- PRD §10.1 table, 00-base row
- PRD User Stories 13 (nodejs hold), 35 (OS gate)
