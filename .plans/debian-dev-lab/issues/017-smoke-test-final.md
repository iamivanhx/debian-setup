# `scripts/smoke-test.sh` final battery

## Type

AFK

## Phase

Phase 3: Backup Trilogy

## Parent plan

../../debian-dev-lab.md

## What to build

Finalize `scripts/smoke-test.sh` with the Phase 3 assertions on top of everything from Phase 1 and Phase 2. After this issue lands, the smoke test is the canonical "is the SER8 healthy" check.

See parent plan, Phase 3 → smoke-test deliverable.

## Acceptance criteria

- [ ] All Phase 1 + Phase 2 assertions remain present and passing.
- [ ] Asserts `restic-backup.timer` is active.
- [ ] Asserts `restic-forget.timer` is active.
- [ ] Asserts `restic snapshots` lists at least one snapshot.
- [ ] Asserts `tailscale status` is online.
- [ ] Asserts `nft list ruleset` includes the expected chains (loopback, established/related, tailscale0).
- [ ] Asserts `ss -ltnp` shows sshd bound only to loopback OR the tailnet IP — never `0.0.0.0`.
- [ ] Script exits non-zero on the first failed assertion and prints which check failed.
- [ ] Runs cleanly on the converged VM and on the real SER8.

## Blocked by

- 015-backup-role.md

## Implementation notes

- This is the canonical health check post-ship. Keep the output readable so the operator can scan it after a manual run.
- No new dependencies — pure shell over already-installed binaries.

## Requirements addressed

- Phase 3, smoke-test deliverable.
- Testing strategy → smoke-test grows per phase.
