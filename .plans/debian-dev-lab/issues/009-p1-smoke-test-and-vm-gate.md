# Phase 1 smoke-test additions + VM rehearsal gate

## Type

HITL

## Phase

Phase 1: Foundation

## Parent plan

../../debian-dev-lab.md

## What to build

Add Phase 1 assertions to `scripts/smoke-test.sh` (creating the file if it does not yet exist), then run the full Phase 1 stack against a clean clone of the post-Phase-0 UTM VM. The phase is not done until `--check --diff` reports zero changes on a converged VM and every smoke-test assertion passes.

See parent plan, Phase 1 → `scripts/smoke-test.sh` deliverable, "Implementation notes" (idempotency gate), and Testing strategy → "VM rehearsal gate".

## Acceptance criteria

- [ ] `scripts/smoke-test.sh` exists, executable, exits non-zero on any failed assertion.
- [ ] Asserts `snapper-timeline.timer` and `snapper-cleanup.timer` active.
- [ ] Asserts `btrfs-send.timer` active.
- [ ] Asserts `nft list ruleset` includes the expected chains.
- [ ] Asserts sshd is bound only to loopback (`ss -ltnp` shows `127.0.0.1:22`).
- [ ] Asserts `snapper -c root list` has at least one entry after a triggering apt transaction.
- [ ] Asserts at least two kernels present in `/boot`.
- [ ] On a clean post-Phase-0 VM clone, `ansible-playbook --ask-vault-pass -K site.yml` converges, then a second run reports `changed=0`.
- [ ] `ansible-playbook --check --diff site.yml` on the converged VM reports 0 changed tasks (excluding tasks marked `changed_when: false`).
- [ ] SSH staging verified in BOTH states: clean loopback with no tailnet, then rebound to tailnet IP after `tailscale up` and a re-run.

## Blocked by

- 006-hardware-role.md
- 007-storage-role.md
- 008-security-role.md

## Implementation notes

- HITL: a human drives the VM, the playbook runs, the smoke test runs, and someone confirms the SSH staging both ways.
- Failures here are bugs in the relevant Phase 1 role, not Phase 1 gate problems. Fix upstream, re-run.
- Keep the smoke test additive — Phase 2 and Phase 3 issues will append to it.

## Requirements addressed

- Phase 1, smoke-test deliverable.
- Testing strategy → per-phase, VM rehearsal gate.
