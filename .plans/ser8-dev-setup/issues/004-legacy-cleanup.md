# Legacy script cleanup: delete unrelated experiments

## Type

AFK

## Phase

Phase 0: Pre-flight

## Parent plan

../../ser8-dev-setup.md

## What to build

Delete the four legacy scripts that are unrelated to this project:

- `xfce-setup.sh`
- `hyprland-setup.sh`
- `debian-post-install.sh`
- `beelink_ubuntu_post_install.sh`

**Retain** `beelink_debian_post_install.sh` — it's the porting source for Phases 1 and 2 and is only deleted at the end of Phase 2 (see issue 014).

Update `README.md` to remove any references to the deleted scripts.

## Acceptance criteria

- [ ] `xfce-setup.sh`, `hyprland-setup.sh`, `debian-post-install.sh`, `beelink_ubuntu_post_install.sh` no longer exist at the repo root.
- [ ] `beelink_debian_post_install.sh` is still present (deleted later in issue 014).
- [ ] `README.md` does not reference any of the deleted scripts.
- [ ] `git log` for each deleted file preserves its history (they're recoverable if ever needed).
- [ ] The commit message names each deleted file explicitly.

## Blocked by

None — can start immediately, runs in parallel with 001/002/003.

## Implementation notes

- This is a single-commit deletion. No porting, no salvaging, no archive subdirectory.
- `git log --follow` will recover any of these files later if the user changes their mind.
- Do not delete `beelink_debian_post_install.sh` in this issue — that's explicitly issue 014's job.

## Requirements addressed

- Plan Phase 0, Legacy cleanup bullet
- Plan "Decisions resolved during planning" (legacy script fate)
- PRD §6 (Non-goals — "No GNOME, XFCE, or Hyprland for this project")
