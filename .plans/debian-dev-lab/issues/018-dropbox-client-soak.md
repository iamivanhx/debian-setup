# Dropbox desktop client 24-hour soak

## Type

HITL

## Phase

Phase 3: Backup Trilogy

## Parent plan

../../debian-dev-lab.md

## What to build

Run the Dropbox desktop client on the SER8 for 24 hours on encrypted btrfs. Decide whether `install_dropbox_client` stays `true` or flips permanently to `false` in `host_vars/beelink.yml`. Document the decision either way.

See parent plan, Phase 3 → deliverable "Dropbox client 24-hour soak", and locked decision "`install_dropbox_client` default: `true`, but flagged as a smoke-test item in P3".

## Acceptance criteria

- [ ] `install_dropbox_client: true` set; playbook re-run; client installed and signed in.
- [ ] Client runs continuously for ≥24 hours under typical desktop use.
- [ ] Outcome recorded:
  - [ ] **Pass:** no crashes, no inotify exhaustion, no fs corruption. `install_dropbox_client` stays `true`.
  - [ ] **Fail:** any of the above. `install_dropbox_client` flipped to `false` in `host_vars/beelink.yml`, with a comment recording the failure mode.
- [ ] Decision and reasoning logged in `docs/acceptance.md` (or a sibling doc).

## Blocked by

- 015-backup-role.md

## Implementation notes

- HITL: a human runs the client and observes for 24 hours. There is no automation here.
- Restic→Dropbox via rclone is the primary off-site path and is unaffected by this decision. The desktop client is a convenience — losing it is acceptable.
- Do not skip this. The locked decision is explicit that v1 ships only after the soak is judged.

## Requirements addressed

- Phase 3 → "Dropbox client 24-hour soak".
- Locked decision: `install_dropbox_client` default behavior.
