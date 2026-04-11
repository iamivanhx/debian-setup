# 40-desktop module: Plasma 6 minimal + SDDM + Nerd Font + Flathub

## Type

AFK

## Phase

Phase 2: Workstation

## Parent plan

../../ser8-dev-setup.md

## What to build

Fill in `modules/40-desktop.sh` so that the SER8 lands a minimal, stock Plasma 6 desktop session.

Concrete deliverables:

- Install the explicit allow-list from PRD §5.5: `plasma-desktop sddm konsole dolphin kate ark gwenview okular plasma-nm plasma-pa kscreen kwalletmanager xdg-desktop-portal-kde breeze-gtk-theme qt6-wayland fonts-noto fonts-noto-color-emoji fonts-jetbrains-mono`.
- **Explicitly do NOT install** any of: `kde-full`, `kde-standard`, `kde-plasma-desktop` (the meta-packages). Module should abort if any of these are detected (guard + error).
- `systemctl enable sddm.service` (guarded).
- Set the default session to Wayland via `/etc/sddm.conf.d/wayland.conf` templated.
- Fetch JetBrainsMono Nerd Font tarball from upstream (GitHub releases) to a deterministic path under `/usr/local/share/fonts/JetBrainsMonoNerdFont/`, **guarded by `guard::dir_exists` on the target directory**. Specific version pinned in a variable at the top of the module (e.g. `NERD_FONT_VERSION="3.2.1"`).
- Run `fc-cache -fv` **only if** the font directory was just created.
- Install `flatpak` and add the Flathub remote (`flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo`). **Do not install any Flatpaks.**
- `smoke_40_desktop`: every allow-list package installed, none of the forbidden meta-packages installed, `systemctl is-enabled sddm`, `/etc/sddm.conf.d/wayland.conf` exists and matches template, a JetBrainsMono font file exists under `/usr/local/share/fonts/`, `fc-list | grep -qi JetBrainsMono`, `flatpak remotes` lists `flathub`.

## Acceptance criteria

- [ ] `./run.sh 40-desktop` on a converged Phase 1 machine installs Plasma 6 minimal.
- [ ] Reboot → SDDM greeter appears; login → Plasma session starts.
- [ ] `./run.sh --dry-run 40-desktop` on the converged machine reports zero planned actions.
- [ ] Attempting to run the module on a machine with `kde-full` pre-installed fails loudly.
- [ ] `smoke_40_desktop` passes.
- [ ] Konsole opens, renders JetBrainsMono Nerd Font correctly.
- [ ] Shellcheck + shfmt + pre-commit clean.

## Blocked by

- Blocked by 010-phase1-smoke-gate.md (Phase 1 must be green on the real box before Phase 2 lands)

## Implementation notes

- Port the desktop bits from `beelink_debian_post_install.sh` step 3 (minimal GNOME) as inspiration for the "minimal desktop" pattern, but replace GNOME packages with the Plasma allow-list.
- The Nerd Font tarball URL is: `https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONT_VERSION}/JetBrainsMono.zip`. Download, unzip, move `.ttf` files into place. Wrap the network fetch in a guard so re-runs don't re-download.
- The forbidden meta-package check prevents a future accidental `apt install kde-full` from bloating the box — if the user ever runs that, they'll get yelled at on next `./run.sh`.
- Do not install SDDM themes, Plasma themes, or cursor themes. Breeze Dark stock is the rule.
- If the existing beelink script has Dash-to-Dock / Yaru / Gruvbox GNOME theming — ignore all of that. Non-goal.

## Requirements addressed

- Plan Phase 2, `40-desktop.sh` bullet
- PRD §5.5 (Desktop)
- PRD §10.1 table, 40-desktop row
- PRD User Story 9
