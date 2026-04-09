# `base` role

## Type

AFK

## Phase

Phase 1: Foundation

## Parent plan

../../debian-dev-lab.md

## What to build

Implement the `base` role: apt sources with `trixie-backports` pinned low (kernel + AMD firmware re-pinned high), locale, timezone, core CLI package set, the `nodejs`/`npm` apt hold, and the role-level safety assertions that fail loudly on a wrong distro or missing required vars.

See parent plan, Phase 1 → `base` deliverable, and the testing strategy "per role pre-flight assertions".

## Acceptance criteria

- [ ] `/etc/apt/sources.list.d/` includes `trixie-backports` from a Jinja template.
- [ ] Apt pinning template: backports default low; `linux-image-amd64`, `firmware-amd-graphics`, `amd64-microcode` pinned high.
- [ ] Locale and timezone applied from `host_vars/beelink.yml`.
- [ ] Core CLI installed: `git build-essential make jq curl wget htop ripgrep fd-find bat tree unzip`.
- [ ] `apt-mark hold nodejs npm` enforced (and verified).
- [ ] Pre-flight assertion: distro is Debian Trixie — fail with detected distro name otherwise.
- [ ] Pre-flight assertion: required vars present — fail with missing var name otherwise.
- [ ] `--check --diff` reports 0 changed tasks on a converged run.

## Blocked by

- 003-utm-rehearsal.md (Phase 0 must be green)

## Implementation notes

- Every config file the role writes must come from a Jinja2 template under `roles/base/templates/`. No `lineinfile` for canonical content, no heredocs.
- This is the foundation other roles depend on — keep its variable interface narrow and well-named.
- Mesa stays stock Trixie. Do NOT add Mesa to the high-pin list.

## Requirements addressed

- Phase 1, `base` deliverable.
- PRD §10 base module.
- Testing strategy → `base` pre-flight assertions.
