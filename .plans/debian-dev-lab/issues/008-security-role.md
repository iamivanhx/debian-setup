# `security` role with staged SSH

## Type

AFK

## Phase

Phase 1: Foundation

## Parent plan

../../debian-dev-lab.md

## What to build

Implement the `security` role: a templated nftables ruleset (deny-all inbound, allow `lo` + established/related, conditional `tailscale0` allow), a templated `sshd_config` with key-only auth, the staged `ListenAddress` logic that binds SSH to `127.0.0.1` until Tailscale is up and rebinds to the tailnet IP on a later run, and `unattended-upgrades` configured security-only with `APT::Periodic` enabled.

See parent plan, Phase 1 → `security` deliverable, implementation notes ("SSH staging is the cleverness the user should not have to think about"), plus PRD §10 security module.

## Acceptance criteria

- [ ] `/etc/nftables.conf` templated with deny-all inbound, allow `lo`, allow established/related.
- [ ] `tailscale0` allow rule emitted only when interface is present (template conditional).
- [ ] `sshd_config` templated: PasswordAuthentication no, PubkeyAuthentication yes, no root login.
- [ ] `ListenAddress` resolves to `127.0.0.1` when `tailscale ip -4` returns nothing.
- [ ] On a subsequent run with Tailscale up, `ListenAddress` rebinds to the tailnet IPv4.
- [ ] Pre-flight assertion: `ssh_authorized_keys` is non-empty — fail otherwise.
- [ ] `unattended-upgrades` installed, security-only origin allowlist applied.
- [ ] `APT::Periodic::Update-Package-Lists` and friends enabled.
- [ ] `--check --diff` reports 0 changed tasks on a converged run in either staging state.

## Blocked by

- 005-base-role.md

## Implementation notes

- The SSH staging is the marquee piece. Test BOTH states explicitly during the Phase 1 VM rehearsal — once with no tailnet (loopback only), once with tailnet up (rebound).
- nftables `tailscale0` rule is conditional: if you templatize it as a hard `iif tailscale0` line when the interface doesn't exist yet, nft will refuse to load. Use a Jinja `if` and re-render on later runs.
- No fail2ban. PRD §10 explicitly excludes it.

## Requirements addressed

- Phase 1, `security` deliverable.
- PRD §10 security module, §11 security gates.
- Testing strategy → `security` pre-flight assertion.
