# Phase 2 smoke-test additions + SSH tailnet rebind verification

## Type

HITL

## Phase

Phase 2: Workstation + Lab

## Parent plan

../../debian-dev-lab.md

## What to build

Append Phase 2 assertions to `scripts/smoke-test.sh`, then run a second playbook pass after Tailscale comes up to verify the `security` role rebinds sshd from loopback to the tailnet IP. Demo the whoami round-trip from a second authorized Tailscale peer.

See parent plan, Phase 2 → smoke-test additions, "User-facing changes" (third bullet), implementation notes.

## Acceptance criteria

- [ ] Smoke test asserts `node`, `pnpm`, `python`, `uv`, `go`, `git`, `docker`, `code`, `tailscale` all run successfully (`--version` or equivalent).
- [ ] Smoke test asserts `which node` resolves under the pnpm-managed path.
- [ ] Smoke test asserts `which python` resolves under uv's managed path.
- [ ] Smoke test asserts `docker ps` lists the Traefik container.
- [ ] Smoke test asserts `tailscale status` shows the host as `online`.
- [ ] Smoke test asserts sshd `LISTEN` is now the tailnet IPv4, not loopback.
- [ ] After Tailscale is up, a second `ansible-playbook` run rebinds `ListenAddress` to the tailnet IP and reports `changed=0` on a third run.
- [ ] `curl http://whoami.lab.<tailnet>` from a second authorized Tailscale peer returns the whoami response.
- [ ] `--check --diff` on the converged VM reports 0 changed tasks.

## Blocked by

- 010-desktop-role.md
- 012-dev-role.md
- 013-lab-role.md

## Implementation notes

- HITL: a second Tailscale peer (laptop, phone) is required for the round-trip demo.
- Treat this as the Phase 2 gate. If any check fails, fix the responsible role and re-run; do not patch the smoke test.

## Requirements addressed

- Phase 2, smoke-test additions.
- Phase 2 user-facing changes: SSH reachable over tailnet, whoami reachable.
- PRD §9 Stories 7, 8.
