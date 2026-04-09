# `desktop` role

## Type

AFK

## Phase

Phase 2: Workstation + Lab

## Parent plan

../../debian-dev-lab.md

## What to build

Implement the `desktop` role: minimal Plasma 6 package set per PRD §5.6, SDDM enabled as the display manager, JetBrainsMono Nerd Font fetched from the upstream tarball and installed system-wide, Flatpak with the Flathub remote added but no Flatpaks installed.

See parent plan, Phase 2 → `desktop` deliverable, plus PRD §5.6.

## Acceptance criteria

- [ ] All Plasma 6 packages from PRD §5.6 installed: plasma-desktop, sddm, konsole, dolphin, kate, ark, gwenview, okular, plasma-nm, plasma-pa, kscreen, bluedevil, powerdevil, kwalletmanager, xdg-desktop-portal-kde, breeze-gtk-theme, qt6-wayland, plasma-firewall, fonts-noto, fonts-noto-color-emoji, fonts-jetbrains-mono.
- [ ] SDDM enabled as the display manager.
- [ ] JetBrainsMono Nerd Font tarball downloaded (idempotent), extracted to `/usr/local/share/fonts/JetBrainsMonoNerdFont/`, `fc-cache` handler triggers on change.
- [ ] `flatpak` installed; Flathub remote added at the system level.
- [ ] No Flatpaks installed by the role.
- [ ] Breeze Dark default theme applied (per PRD).
- [ ] `--check --diff` reports 0 changed tasks on a converged run.

## Blocked by

- 009-p1-smoke-test-and-vm-gate.md

## Implementation notes

- Strict minimal package set — no `kde-full`, no `plasma-workspace-wayland-extras`, etc. PRD §5.6 is the canonical list.
- Nerd Font tarball comes from the upstream JetBrainsMono Nerd Font release, not from apt. Pin the version in a var.

## Requirements addressed

- Phase 2, `desktop` deliverable.
- PRD §5.6 (desktop package list).
