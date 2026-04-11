# lib/guards.sh — idempotency guard vocabulary

## Type

AFK

## Phase

Phase 0: Pre-flight

## Parent plan

../../ser8-dev-setup.md

## What to build

The reusable guard library that every module consumes. This is the specific mitigation for Risk #1 (idempotency discipline drift) from the PRD. No module is allowed to implement its own ad-hoc "is this already done" checks — they go here.

The full vocabulary from PRD §10.3:

```
guard::package_installed <pkg>
guard::package_held <pkg>
guard::apt_repo_present <keyword>
guard::service_enabled <unit>
guard::service_active <unit>
guard::unit_file_exists <unit>
guard::file_exists <path>
guard::dir_exists <path>
guard::symlink_is <link> <target>
guard::file_has_line <path> <regex>
guard::file_matches_template <path> <template>
guard::user_in_group <user> <group>
guard::user_shell_is <user> <shell>
guard::command_exists <cmd>
guard::docker_network_exists <name>
guard::container_running <name>
guard::port_listening <proto> <port>
```

Each guard:

- Is a small bash function with a single responsibility.
- Returns 0 when the desired state is already present, 1 otherwise.
- **Reads state only** — never mutates the system. No side effects.
- Has a top-of-function comment with a usage example.
- Has a matching entry in a `tests/guards_test.sh` file that exercises it against a deterministic fixture or a safe real check (e.g. `guard::command_exists ls` should always pass).

## Acceptance criteria

- [ ] All 17 guards from PRD §10.3 exist in `lib/guards.sh` with the exact names listed.
- [ ] Every guard has a usage example in its comment.
- [ ] `tests/guards_test.sh` runs each guard at least once with both a passing and a failing input and reports pass/fail.
- [ ] `./run.sh lint` (shellcheck + shfmt) passes.
- [ ] No guard mutates any state (verified by code review of the diff).
- [ ] A `README.md` section in `lib/guards.sh` (top-of-file comment block) documents the convention: "every destructive call in a module must be wrapped in a `guard::*` check OR preceded by `# SAFE_REPLAY: <reason>`."

## Blocked by

- Blocked by 001-repo-scaffold.md (needs `lib/` to exist)

## Implementation notes

- Implement `guard::file_matches_template` using `cmp -s` (silent compare) against the checked-in template path. This is the pairing for `deploy_config` — before writing, check if the target already matches.
- `guard::port_listening` should use `ss -Hln` with `-t`/`-u` per protocol argument.
- `guard::docker_network_exists` should `docker network inspect <name> >/dev/null 2>&1`.
- `guard::apt_repo_present` should grep `/etc/apt/sources.list.d/*.list` and `/etc/apt/sources.list` for the keyword.
- Keep each function under 10 lines. If a guard needs more, it's probably two guards.

## Requirements addressed

- Plan Phase 0, lib/guards.sh bullet
- PRD §10.3 (full interface specification)
- PRD §12 R1 (idempotency discipline drift mitigation)
