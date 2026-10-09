# lilypad runs as the user, and each step is its own process

The old `sudo ./run.sh` ran every module as root and dropped to the user for user steps; Omarchy 3 and omadeb source phase files into one shell. lilypad instead runs as the invoking user, and every unit of install work is a **step**: an executable run as its own process under `set -Eeuo pipefail`, with root steps invoked one at a time as `sudo <step>` on sudo's normal timestamp (no keepalive, no `NOPASSWD`). We chose this because the security baseline gives nothing standing root and lets user-level work run without sudo, and because a sourced file shares the runner's shell options and privileges, which is how Omarchy's strict mode was silently dropped (rule R14 in `docs/research/omarchy-criticisms.md`).

## Considered Options

- **Keep `sudo ./run.sh` and drop privileges for user steps.** Rejected: every user step runs inside a root process, and the user's environment reaches root.
- **Two entry points (a system install under sudo, a user install without).** Rejected: two commands, and ordering rules across them, because the firewall and apt sources must run between and before dev steps.
- **Sourced modules exposing `apply_*`/`smoke_*` functions (closed issue #19).** Rejected: it shares shell state across modules and can't split privilege per step. Its point that checking never installs survives as each step's separate `check`.

## Consequences

- A long run can prompt for the sudo password again once the timestamp expires.
- Root steps start with `#!/bin/bash`, a fixed `PATH` and `umask 022`, and write root-owned files only through `install -o root`. Anything root runs unattended is a root-owned copy outside the user-owned installed clone.
