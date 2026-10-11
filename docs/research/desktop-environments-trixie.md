# Desktop environments on Debian trixie

Research for [Research: Desktop environments on Debian trixie](https://github.com/iamivanhx/debian-setup/issues/45), a ticket on the map [Map: SER8 Debian setup refactor (Omarchy/omadeb-inspired)](https://github.com/iamivanhx/debian-setup/issues/44). Gathered 2026-10-11. The decision is made in [Desktop choice and composition](https://github.com/iamivanhx/debian-setup/issues/51); this note gives the evidence only and does not pick a desktop.

**Question.** Which desktop environments can be installed on Debian trixie for the SER8, and how do they compare on availability, integration vs. assembly, churn, automatability, keyboard-first workflow, Mac habits, theming reach and fit with the security baseline?

## Answer in brief

- **Only GNOME, KDE Plasma and Sway (among the main candidates) are in Debian, and none of them is in trixie-backports.** trixie has GNOME 48.7, Plasma 6.3.6 and Sway 1.10.1. Each stays on that version for trixie's whole life, apart from point updates. Upstream is now at GNOME 51, Plasma 6.7.5 (6.8 is due 2026-10-14) and Sway 1.12.
- **COSMIC and niri are not in any Debian suite.** COSMIC has only two RFP bugs (requests for someone to package it). niri has an ITP (someone intends to package it) with packaging work on salsa that "hasn't yet reached an uploadable state". On trixie, COSMIC means building about 30 Rust components from unsigned git tags, with rustc ≥ 1.93; trixie-backports has rustc 1.95. niri means a source build from an unsigned release tarball, or a third party's apt repo (omakasui's, which carries niri 26.04 for trixie).
- **Integration.** Plasma covers every role the ticket lists with packages from trixie. GNOME covers every role except clipboard history and tiling, and both of those come as extensions. COSMIC covers every role except clipboard history. Sway ships a bar and leaves everything else to be assembled. niri ships an overview, an Alt-Tab switcher and a screenshot UI, and leaves the rest to be assembled.
- **Churn is concentrated in different places.** For GNOME it is the extensions:
  - GNOME breaks extension APIs every six months, and GNOME 45 broke all of them at once (the switch to ES modules).
  - A trixie-to-forky upgrade moves GNOME 48 to 50 or later, and the extension set has to move with it.
  - Plasma's last large break was Plasma 5 to 6 (bookworm to trixie). Trixie to forky stays within Plasma 6.
  - Sway's i3-style config has been stable across releases.
  - niri has a written policy that releases should not break existing config.
  - COSMIC reached 1.0 in December 2025 and has released 1.1 through 1.10 since June 2026, so it has no multi-release record yet.
- **Automatability is best where configuration is plain files.** Sway (text with `include`), niri (KDL with `include` since 25.11) and COSMIC (one RON file per key, with system defaults) are declarative. Plasma uses INI files that cascade from `/etc/xdg` to `~/.config`, with locks. GNOME is declarative only through dconf keyfiles in `/etc/dconf/db/*.d` (what `modules/40-desktop.sh` already does), whereas omadeb uses imperative `gsettings` scripts.
- **Mac Cmd habits.** No environment except Hyprland translates Super+C into Ctrl+C or Ctrl+Shift+C on its own. Everywhere else that takes keyd (in Debian; its per-app mapper supports only X, Sway and GNOME) or Toshy (not in Debian; it covers GNOME, Plasma 6, COSMIC, Sway and niri).
- **Security baseline.** GNOME, Plasma and Sway can be installed entirely from Debian, provided GNOME is limited to Debian-packaged extensions. Any extensions.gnome.org (EGO) extension, COSMIC, and niri would each have to come in as an **exception** under `ADR-20261010-pin-outside-apt`, or from a third-party apt repo, because none of them publishes a signature.

## How this was gathered

- **Debian versions** come from the archive's `Packages.xz` indices for trixie (Release 13.7, 2026-09-12), trixie-updates, trixie-backports (Release dated 2026-10-11), sid and experimental, `main/binary-amd64` ([deb.debian.org/debian/dists/](https://deb.debian.org/debian/dists/)). Forky and sid rows are cross-checked against [madison](https://qa.debian.org/madison.php), which lists backports rows too: for example, `hyprland` shows `trixie-backports`, while `gnome-shell`, `plasma-workspace` and `sway` show none. Each package can be checked at `https://packages.debian.org/<suite>/<package>`.
- **Packaging requests** come from Debian's WNPP lists ([being packaged](https://www.debian.org/devel/wnpp/being_packaged), [requested](https://www.debian.org/devel/wnpp/requested)) and the bug logs linked from them.
- **Upstream** facts come from each project's own release pages, release APIs, docs and source, pinned where a commit matters:

  | Label | Source | Pin |
  |---|---|---|
  | omadeb | [omakasui/omadeb](https://github.com/omakasui/omadeb) | `654f5964` (= `v1.4.3`, 2026-10-02) |
  | omari | [codeberg.org/omakasui/omari-setup](https://codeberg.org/omakasui/omari-setup) | `3d7e4d27` (`dev`) |
  | COSMIC | [pop-os/cosmic-epoch](https://github.com/pop-os/cosmic-epoch) | `epoch-1.10.0`; libcosmic `dbc62f2d`, cosmic-settings-daemon `9e4ae69f`, cosmic-comp `4d14528f`, cosmic-osd `9b14ee01`, cosmic-greeter `98df07df` |
  | niri | [niri-wm/niri](https://github.com/niri-wm/niri) (formerly YaLTeR/niri) | `v26.04` (`8ed0da44`) |
  | keyd | [rvaiya/keyd](https://github.com/rvaiya/keyd) | `v2.5.0` (`f33dca87`), the version in trixie |
  | Toshy | [RedBearAK/toshy](https://github.com/RedBearAK/toshy) | `35407672` (2026-09-18) |

- **EGO availability** comes from `https://extensions.gnome.org/extension-info/?uuid=<uuid>` (the `shell_version_map`), read on 2026-10-11.
- **Inputs from the earlier map:**
  - `origin/research/hyprland-stack-trixie` (Hyprland on trixie, the Radeon 780M, backports risks)
  - `origin/research/omarchy-omadeb-architecture` (omadeb's GNOME layering)
  - `origin/research/macos-inventory-and-tools` (Cmd habits)
  - Today's `modules/40-desktop.sh`

**Reading the versions.** "—" means no package in that suite. amd64 is the only architecture checked: the map scopes machines to the SER8 and the amd64 test VM ([GLOSSARY: Test VM](../../GLOSSARY.md)).

## Availability at a glance

| Candidate | Key package | trixie | trixie-backports | forky / sid | experimental | Upstream latest |
|---|---|---|---|---|---|---|
| GNOME | `gnome-shell` | 48.7-0+deb13u2 | — | 50.5-1 | 51.0-2 | 51 (2026-09-16) ([GNOME calendar](https://release.gnome.org/calendar/)) |
| KDE Plasma | `plasma-workspace` | 4:6.3.6-2 | — | 4:6.7.4-2 | — | 6.7.5 (2026-09-08); 6.8.0 due 2026-10-14 ([KDE announcements](https://kde.org/announcements/), [Plasma 6 schedule](https://community.kde.org/Schedules/Plasma_6)) |
| COSMIC | `cosmic-session` | — | — | — | — | epoch-1.10.0 (2026-10-08) ([releases](https://github.com/pop-os/cosmic-epoch/releases)) |
| Sway | `sway` | 1.10.1-2 | — | 1.12-1 | — | 1.12 (2026-05-25) ([release](https://github.com/swaywm/sway/releases/tag/1.12)) |
| niri | `niri` | — | — | — | — | v26.04 (2026-04-25) ([release](https://github.com/niri-wm/niri/releases/tag/v26.04)) |
| Hyprland (dropped; reference) | `hyprland` | — | 0.55.2+ds-1~bpo13+1 | 0.56.2+ds-3 | — | 0.56.2 (input note) |

**Other environments installable on trixie.** These were screened, not scored in full. Each is either X11-first or a bare compositor that needs the same assembly as Sway.

| Environment | trixie | forky / sid | Why not scored |
|---|---|---|---|
| Xfce (`xfce4-session`) | 4.20.2-2 | 4.20.4-1 | Xfce 4.20 has only "experimental Wayland support for most components" ([Xfce 4.20 announcement](https://www.xfce.org/about/news/?post=1734220800)). |
| Budgie (`budgie-desktop`) | 10.9.2-8 | 10.10.3-2 | Upstream moved to Wayland (on labwc) only in 10.10 ([Budgie 10.10](https://buddiesofbudgie.org/blog/budgie-10-10-released)), and that version isn't in trixie. |
| Cinnamon (`cinnamon`) | 6.4.10-2+deb13u1 | 6.6.9-3 | X11-first. Its Wayland status was not checked. |
| LXQt (`lxqt-session`) | 2.1.1-1 | 2.4.0-1 | Its Wayland session runs on a separate compositor (labwc, KWin, …). It is a panel suite over another WM, not an integrated environment. Not checked further. |
| labwc | 0.8.3-1 | 0.20.2-1 | A stacking wlroots compositor: Sway-level assembly without tiling. |
| Wayfire | 0.9.0-5 | 0.10.0-1 (sid only) | A wlroots compositor: Sway-level assembly. |
| river | — | — | Not in Debian ([ITP #1006593](https://bugs.debian.org/1006593), open since 2022). |
| Miriway | — | 26.06.3-2 (forky only) | Not in trixie. |

**Hardware.** Every candidate above is amd64-native. The SER8's Radeon 780M is driven by trixie's 6.12 kernel, and the repo pins the backports kernel and `firmware-amd-graphics` (input note `hyprland-stack-trixie`, section "AMD Radeon 780M"). No candidate-specific GPU requirement was found.

## GNOME

### Availability

- **Versions.**
  - trixie has GNOME 48: `gnome-shell` 48.7, `mutter` 48.7, `gdm3` 48.0 (Packages index). There is no backport.
  - GNOME 48 was released 2025-03-20. Since then GNOME 49 (2025-09-17), 50 (2026-03-18) and 51 (2026-09-16) have shipped ([GNOME calendar](https://release.gnome.org/calendar/)), so trixie is three majors behind.
  - GNOME marks the previous stable branch EOL when a new one ships (same page), so upstream no longer maintains 48. Debian's stable updates carry it (48.7-0+deb13u2).
  - sid and forky have 50.5. experimental has 51.0.
- **Debian-packaged extensions** are pinned to the GNOME major. For example, `gnome-shell-extension-tiling-assistant` 51-2 `Depends: gnome-shell (>= 48~), gnome-shell (<< 49~)` (Packages index). trixie packages, among others:
  - `dashtodock` 100
  - `appindicator` 59
  - `tiling-assistant` 51
  - `gpaste` 45.3 (clipboard history)
  - `user-theme`, `blur-my-shell`, `caffeine`, `dash-to-panel`, `arc-menu`, `gsconnect`, and the `gnome-shell-extensions` set 48.2

  Several that today's module and omadeb use are **not** in trixie:
  - `space-bar`
  - `tactile`
  - `just-perfection` (sid only, 37.0)
  - `paperwm` (sid only, 50.0.1)
  - `tophat`, `rounded-window-corners`, `undecorate`, `quick-settings-tweaks`

### Integration vs. assembly

| Role | GNOME 48 | Source |
|---|---|---|
| Bar | Shell top bar | `gnome-shell` |
| Launcher | Overview search (Super) | `gnome-shell` |
| Notifications | Shell | `gnome-shell` |
| Lock / idle | Shell lock screen, gnome-settings-daemon | `gnome-shell`, `gnome-session` 48.0 |
| Portal | `xdg-desktop-portal-gnome` 48.0-2 | Packages index |
| Polkit agent | Built into the shell | `gnome-shell` (the trixie note found no standalone `polkit-gnome`) |
| OSD | Shell | `gnome-shell` |
| Screenshots | Built-in screenshot and screencast UI since GNOME 42: "take screenshots and screen recordings, all from the same tool" ([GNOME 42](https://release.gnome.org/42/)) | `gnome-shell` |
| Clipboard history | **None built in.** GPaste extension (`gnome-shell-extension-gpaste` 45.3, Debian) | Packages index |
| Tiling | **Edge snapping only.** Tiling comes from an extension: Tiling Assistant (Debian), or Tactile, Forge, Tiling Shell or PaperWM (EGO) | Packages index; EGO |

Two roles are left to choose, clipboard history and tiling, and both are extensions.

### Churn

- **The extension API breaks every major release.** The official porting guides list removed and renamed APIs each cycle:
  - GNOME 49 removed `Meta.Rectangle`, `AppMenuButton`, `Meta.MaximizeFlags` and `Clutter.ClickAction` ([porting to 49](https://gjs.guide/extensions/upgrading/gnome-shell-49.html)).
  - GNOME 50 removed keyboard-manager and restart APIs, and "removed X11 support" ([porting to 50](https://gjs.guide/extensions/upgrading/gnome-shell-50.html)).
  - GNOME 45 "moved to ESM", and extensions for 44 and earlier "won't be compatible" ([porting to 45](https://gjs.guide/extensions/upgrading/gnome-shell-45.html)). Bookworm (GNOME 43) to trixie (GNOME 48) crossed that break.
- **Version gating.** `metadata.json` must list supported majors in `shell-version`, and `disable-extension-version-validation` is `false` by default ([extension anatomy](https://gjs.guide/extensions/overview/anatomy.html)). An extension that hasn't declared the new major therefore stops loading after an upgrade.
- **The EGO record as of 2026-10-11** (majors with a build, from 43 up):
  - **Covers through 51:** dash-to-dock, space-bar, tactile, just-perfection, appindicator, blur-my-shell.
  - **Stops at 50:** tophat, undecorate, paperwm, tilingshell.
  - **Stops at 50, from 46:** rounded-window-corners.
  - **Stops at 49:** forge.
  - **Stops at 48:** quick-settings-tweaks.

  Four weeks after GNOME 51, the widely used extensions have caught up and the smaller ones haven't.
- **What trixie to forky would do.** It would take GNOME 48 to at least 50, the current forky version. That crosses the 49 and 50 API changes above and the removal of the X11 session. Debian-packaged extensions move in lockstep, because their `Depends` pins them to the shell major. EGO extensions must each publish a build for the new major, or they stop loading. omadeb handles this with `gext update` after each system update ([`bin/omadeb-update-gnome-extensions`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-update-gnome-extensions)).

### Automatability

- **The declarative route** is dconf keyfiles. System databases are built from keyfiles in `/etc/dconf/db/<db>.d/`, written in GVariant text, and `dconf update` regenerates the database and notifies running apps ([GNOME admin guide: dconf keyfiles](https://help.gnome.org/admin/system-admin-guide/stable/dconf-keyfiles.html.en)). Today's `modules/40-desktop.sh` already uses this: `/etc/dconf/db/local.d/40-gruvbox`, plus a GDM db.
- **Caveat: an extension's settings can only go in a keyfile if its gsettings schema is installed system-wide.** Debian-packaged extensions ship their schemas system-wide. EGO extensions ship them per user, and omadeb works around that by `sudo cp`-ing each extension's schema from `~/.local/share/gnome-shell/extensions/…` into `/usr/share/glib-2.0/schemas/` and recompiling ([`install/config/gnome/extensions.sh` L16-34](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/config/gnome/extensions.sh#L16-L34)).
- **omadeb's route is imperative.** It writes every setting with `gsettings set`:
  - [`settings.sh`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/config/gnome/settings.sh)
  - [`hotkeys.sh`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/config/gnome/hotkeys.sh), which adds custom keybindings through its own `omadeb-gnome-keybinding-add`
  - extension settings in `extensions.sh` L36-92

  "Restore defaults" means re-running those scripts (input note `omarchy-omadeb-architecture`, section on config layering).
- **User changes land in the binary user dconf db**, not in a file the repo can diff. Locks (keeping a system value from being overridden) were not covered by the page cited above.

### Keyboard-first workflow

- Workspaces, Super for the overview and search, and Super+number workspace binds are all available. omadeb binds Super+1..6 to workspaces, fixes 6 static workspaces, and makes Super+W close a window ([`hotkeys.sh` L2, L39-45](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/config/gnome/hotkeys.sh#L39-L45); [`settings.sh` L14-15](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/config/gnome/settings.sh#L14-L15)).
- **Tiling is not native.** omadeb uses Tactile, a keyboard-driven grid placer configured as a 4×2 grid with 10 px gaps ([`extensions.sh` L37-43](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/config/gnome/extensions.sh#L37-L43)), and Space Bar for workspace indicators. Today's module installs the same pair plus Just Perfection, Dash to Dock and AppIndicator from EGO (`modules/40-desktop.sh` §5).
- omadeb's launcher is Walker, from omakasui's own apt package (`omadeb-walker`), bound to Super+Space ([`hotkeys.sh` L58](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/config/gnome/hotkeys.sh#L58)).

### Mac habits

- Window-manager shortcuts (close, switch app, workspaces, launcher) can be bound to Super in dconf.
- In-app Cmd+C/V needs a key translator:
  - keyd's application mapper supports GNOME and installs a GNOME extension for it on first run ([keyd-application-mapper(1) @v2.5.0](https://github.com/rvaiya/keyd/blob/v2.5.0/docs/keyd-application-mapper.scdoc)). Debian packages it as `keyd-application-mapper` 2.5.0-4.
  - Toshy supports GNOME 40 and later, but on Wayland it needs one of three EGO extensions (Xremap, Window Calls Extended or Focused Window D-Bus) ([Toshy README](https://github.com/RedBearAK/toshy/blob/354076728e5009e40fb6aa84a658e0e01b5e8faf/README.md)).

### Theming reach

- **Shell, GTK and accent colour** are `gsettings` keys, and they change at runtime. omadeb's theme switcher sets `color-scheme`, `gtk-theme`, `accent-color`, `cursor-theme` and `icon-theme` live ([`bin/omadeb-theme-set-gnome`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-theme-set-gnome)).
- **libadwaita (GTK4)** apps take only the accent colour and light/dark. A full palette needs the unsupported `~/.config/gtk-4.0/gtk.css` override that today's module symlinks (`modules/40-desktop.sh` §7).
- **The shell theme** needs the `user-theme` extension, which Debian packages.
- **Qt and the terminal** are outside GNOME's reach. omadeb themes them with its own templates (input note, "Theme system").

### Security baseline fit

- The core, and the Debian-packaged extensions, come from Debian. That is the baseline's first source.
- **EGO extensions don't fit the "verified" tier.**
  - EGO reviews uploads "for malicious code, malware and security risks, but not for bugs", and forbids binaries in extensions ([EGO review guidelines](https://gjs.guide/extensions/review-guidelines/review-guidelines.html)).
  - The guidelines don't mention code signing.
  - An EGO zip is therefore integrity-only at best, which makes each one an **exception** with a pinned, reviewed digest (`ADR-20261010-pin-outside-apt`).
- **Today's module and omadeb both fall short of that.**
  - Today's module downloads the current EGO build unpinned and unverified, then warns and continues on failure (`modules/40-desktop.sh` §5).
  - omadeb installs `gnome-extensions-cli` from PyPI via `pipx` ([`install/packaging/pipx.sh`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/packaging/pipx.sh)). It also copies schemas from user-writable paths into `/usr/share` as root. Under the baseline, privileged code takes nothing from user-writable paths.

## KDE Plasma

### Availability

- **Versions.**
  - trixie has Plasma 6.3.6 (`plasma-workspace` 4:6.3.6-2, `kwin-wayland` 4:6.3.6-1, `plasma-desktop` 4:6.3.6-1). There is no backport.
  - Since 6.3, upstream has released 6.4.0 (2025-06-17), 6.5.0 (2025-10-21), 6.6.0 (2026-02-17) and 6.7.0 (2026-06-16). 6.8.0 is scheduled for 2026-10-14 ([Plasma 6 schedule](https://community.kde.org/Schedules/Plasma_6)). The newest bugfix release is 6.7.5 ([KDE announcements](https://kde.org/announcements/)).
  - sid and forky have 6.7.4.
- **Cadence.** Feature releases every four months, each with six bugfix releases. "Plasma 6.6 is the current LTS release, supported until approximately February 2029" (schedule page). Trixie's 6.3 is not that LTS.
- **The Debian metapackage** `kde-plasma-desktop` 5:162 Recommends `kwin-x11` and `xserver-xorg`, so a Wayland-only install has to pass `--no-install-recommends` or name packages explicitly (Packages index).

### Integration vs. assembly

| Role | Plasma 6.3 (trixie) | Package |
|---|---|---|
| Bar | Plasma panel | `plasma-workspace` |
| Launcher | KRunner (`/usr/bin/krunner`) and the app menu | `plasma-workspace` ([filelist](https://packages.debian.org/trixie/amd64/plasma-workspace/filelist)) |
| Notifications | Plasma | `plasma-workspace` |
| Lock | KScreenLocker | `libkscreenlocker6` 6.3.5-1 |
| Idle / power | PowerDevil | `powerdevil` 4:6.3.6-1 |
| Portal | `xdg-desktop-portal-kde` 6.3.5-1 | Packages index |
| Polkit agent | `polkit-kde-agent-1` 4:6.3.6-1 | Packages index |
| OSD | Plasma | `plasma-workspace` |
| Clipboard history | Klipper, built into the shell (`…/plasma/private/clipboard/libklipperplugin.so`) | `plasma-workspace` filelist |
| Screenshots | Spectacle | `kde-spectacle` 4:6.3.5-2 |
| Tiling | KWin custom tile layouts (built in) | `kwin-wayland` |

Every role is covered by Plasma's own packages from trixie.

### Churn

- **The last big break was Plasma 5 to 6**, which is also what bookworm (5.27) to trixie (6.3) crossed. "In Plasma 6, all plasmoids must use JSON metadata", and those without `X-Plasma-API-Minimum-Version: 6.0` "are assumed to only work with Plasma 5 and will not be made available" ([porting widgets to KF6](https://develop.kde.org/docs/plasma/widget/porting_kf6/)).
- **Trixie to forky** would move 6.3 to at least 6.7, within the same major: per-desktop tile layouts (6.4) and scheduled light/dark switching (6.5) would arrive. No Plasma 7 is scheduled (schedule page lists through 6.9).
- **Add-ons.** Third-party KWin scripts (autotilers such as Krohnkite or Polonium) and widgets come from the KDE Store, not Debian. None was found in the trixie or sid indices. Their churn record across 6.x was not checked.

### Automatability

- **Config is INI files merged key by key.** System defaults live in `$XDG_CONFIG_DIRS` (for example `/etc/xdg`) and users override them in `~/.config`. `[$i]` locks a key, a group or a whole file against user changes ([KDE Kiosk introduction](https://develop.kde.org/docs/administration/kiosk/introduction/)). So system-wide defaults can be versioned and layered like dconf keyfiles, but as plain text.
- **Runtime appliers** ship in `plasma-workspace`: `plasma-apply-colorscheme`, `plasma-apply-lookandfeel`, `plasma-apply-desktoptheme`, `plasma-apply-cursortheme` and `plasma-apply-wallpaperimage` ([filelist](https://packages.debian.org/trixie/amd64/plasma-workspace/filelist)).
- **Not verified here, and my inference:**
  - Panel and widget layout lives in a generated file (`plasma-org.kde.plasma.desktop-appletsrc`) that Plasma rewrites. Laying it out declaratively would need Plasma's layout scripting.
  - The user-level files (`kwinrc`, `kglobalshortcutsrc`, `kdeglobals`) are rewritten by System Settings, so committing them directly would conflict with GUI changes. Putting defaults in `/etc/xdg` avoids that.

### Keyboard-first workflow

- **Tiling.** Built-in tiling arrived in 5.27: custom layouts are edited with Meta+T and windows are tiled by Shift-dragging. KDE says it is "not designed to completely replicate all the features of a more mature tiling window manager yet" ([Plasma 5.27](https://kde.org/announcements/plasma/5/5.27.0/)). It is not automatic. Plasma 6.4 added "a different tile layout for each of your virtual desktops" ([Plasma 6.4](https://kde.org/announcements/plasma/6/6.4.0/)), which is not in trixie's 6.3.
- **Launcher and workspaces.** KRunner is the launcher, and virtual desktops are native.
- **Keyboard-driven automatic tiling** needs a KDE Store KWin script.

### Mac habits

- Global shortcuts can be rebound to Meta (Super).
- **In-app Cmd+C** needs a translator. keyd v2.5.0's application mapper lists only "X, Sway and Gnome" ([keyd-application-mapper(1)](https://github.com/rvaiya/keyd/blob/v2.5.0/docs/keyd-application-mapper.scdoc)). Toshy supports Plasma 6 through its own KWin script and D-Bus service, and offers KDE-specific options for a macOS-like task switcher ([Toshy README](https://github.com/RedBearAK/toshy/blob/354076728e5009e40fb6aa84a658e0e01b5e8faf/README.md)).

### Theming reach

- **Within Plasma.** Colour schemes and global themes apply to Plasma and Qt/KDE apps, and can be switched at runtime with the `plasma-apply-*` tools above.
- **GTK.** GTK 2/3 styling goes through `kde-config-gtk-style` 4:6.3.4-1, "KDE configuration module for GTK+ 2.x and GTK+ 3.x styles selection", plus `breeze-gtk-theme` 6.3.4-1 (Packages index). Whether colours carry into libadwaita (GTK4) apps was not verified.
- **Scheduled light/dark.** Plasma 6.5 added "Configure when your theme will transition from light to dark and back" ([Plasma 6.5](https://kde.org/announcements/plasma/6/6.5.0/)). It is not in trixie.

### Security baseline fit

- Everything listed above comes from Debian main.
- KDE Store add-ons (scripts, widgets, themes) would each be an **exception**, or would be avoided. Whether KDE Store downloads carry signatures was not checked.

## COSMIC

### Availability

- **Not in Debian.** No `cosmic-*` package exists in trixie, backports, sid or experimental (Packages indices). WNPP has two RFPs: [#1120089](https://bugs.debian.org/1120089) "RFP: cosmic" (2025-11-05) and [#1130240](https://bugs.debian.org/1130240) "RFP: cosmic-desktop" (2026-03-10). There is no ITP.
- **Upstream** is distributed as Pop!_OS, Arch, Fedora, NixOS, openSUSE and Gentoo packages. For other distributions the README gives a source build: "The rustc and just packages of your distro may be too old, so we recommend installing rustc and cargo with rustup" ([cosmic-epoch README @epoch-1.10.0](https://github.com/pop-os/cosmic-epoch/blob/epoch-1.10.0/README.md)).
- **Pop!_OS's apt repo** serves only Ubuntu suites (`impish`, `jammy`, `noble`, `resolute`) ([apt.pop-os.org/release/dists/](http://apt.pop-os.org/release/dists/)). It has no Debian suite.
- **Building on trixie.**
  - `cosmic-comp` and libcosmic declare `rust-version = "1.93"` with edition 2024 ([cosmic-comp Cargo.toml @epoch-1.10.0](https://github.com/pop-os/cosmic-comp/blob/epoch-1.10.0/Cargo.toml)). Trixie's rustc is 1.85.1. **trixie-backports' rustc is 1.95.0** (Packages index), so a Debian-sourced toolchain is possible.
  - The epoch repo pins 31 component submodules (`.gitmodules`).
- **Cadence.** epoch-1.0.0 was tagged 2025-12-10. Releases from 1.0.3 to 1.0.14 came roughly weekly until 2026-05-26. Since then: 1.1.0 (2026-06-23), 1.2.0 (2026-06-30), and 1.3.0 (2026-07-14) through 1.10.0 (2026-10-08), every one to three weeks ([releases](https://github.com/pop-os/cosmic-epoch/releases); tag commit dates).

### Integration vs. assembly

The epoch's own components ([cosmic-epoch tree @epoch-1.10.0](https://github.com/pop-os/cosmic-epoch/tree/epoch-1.10.0)) cover:

| Role | Component |
|---|---|
| Bar / dock | `cosmic-panel`, `cosmic-applets` |
| Launcher | `cosmic-launcher` (+ `pop-launcher`), `cosmic-app-library` |
| Notifications | `cosmic-notifications` |
| Lock | `cosmic-greeter` (has `src/locker.rs`) |
| Idle | `cosmic-idle` |
| Portal | `xdg-desktop-portal-cosmic` |
| Polkit agent | `cosmic-osd` (`src/subscriptions/polkit_agent.rs`, `src/components/polkit_dialog.rs`) |
| OSD | `cosmic-osd` |
| Screenshots | `cosmic-screenshot` |
| Clipboard history | **None among the epoch components** |
| Tiling | Built into `cosmic-comp` (`autotile`, `autotile_behavior` global or per-workspace) ([cosmic-comp-config](https://github.com/pop-os/cosmic-comp/blob/4d14528f9108cbc0df5404b3b4b8fa6db75ddb41/cosmic-comp-config/src/lib.rs)) |

### Churn

- **Too young for a record.** COSMIC is ten months past 1.0, with ten feature releases since June 2026.
- **Config migration is built in.** Configs are versioned per component (`<name>/v<N>`), and lookup falls back to the previous version (`look_for_previous` in [cosmic-config `lib.rs`](https://github.com/pop-os/libcosmic/blob/dbc62f2d899cdbfbe43d170689ddc0290db663f4/cosmic-config/src/lib.rs)).
- **A Debian major upgrade doesn't move COSMIC itself**, because it isn't from Debian. It would rebuild the system libraries it links against.

### Automatability

- **One RON file per key.**
  - User settings live in `~/.config/cosmic/<name>/v<N>/<key>`.
  - System defaults are found under `$XDG_DATA_DIRS/cosmic/<name>/v<N>` (for example `/usr/share/cosmic/…`).

  Both are in [cosmic-config `lib.rs`](https://github.com/pop-os/libcosmic/blob/dbc62f2d899cdbfbe43d170689ddc0290db663f4/cosmic-config/src/lib.rs). This is declarative, versionable and layered: a system default with a user override.
- **Keybindings** are `com.system76.CosmicSettings.Shortcuts`, with separate `defaults` and `custom` keys, and custom bindings are merged over the defaults ([cosmic-settings-daemon `config/src/shortcuts/mod.rs`](https://github.com/pop-os/cosmic-settings-daemon/blob/9e4ae69fc175191f15789d35423806ea0f093c9d/config/src/shortcuts/mod.rs)).

### Keyboard-first workflow

Built-in autotiling (global or per workspace), focus-follows-cursor options, workspaces and a launcher are all native (cosmic-comp-config fields above). No extension is needed.

### Mac habits

COSMIC has no built-in key translation. Toshy supports COSMIC through a D-Bus service (Toshy README). keyd's application mapper doesn't list COSMIC.

### Theming reach

- **The theme engine writes outputs for other toolkits.** libcosmic's `cosmic-theme` writes:
  - GTK4 CSS to `~/.config/gtk-4.0/cosmic/{dark,light}.css`, and symlinks both `~/.config/gtk-4.0/gtk.css` and `~/.config/gtk-3.0/gtk.css` to it ([`gtk4_output.rs`](https://github.com/pop-os/libcosmic/blob/dbc62f2d899cdbfbe43d170689ddc0290db663f4/cosmic-theme/src/output/gtk4_output.rs))
  - Qt and qt5ct/qt6ct outputs
  - a VS Code output

  These are listed in [`cosmic-theme/src/output/`](https://github.com/pop-os/libcosmic/tree/dbc62f2d899cdbfbe43d170689ddc0290db663f4/cosmic-theme/src/output). So one palette reaches the shell, GTK3, GTK4 and Qt, at runtime.
- **Terminals** other than `cosmic-term` were not checked.

### Security baseline fit

- **No Debian, backports or signed vendor apt repo exists for Debian.**
- **The source route can't meet "verified".** The source is git tags, and `epoch-1.10.0` is an annotated tag that GitHub reports as `unsigned` (tag API). There are no release assets. Building it would mean pinning about 31 submodule commits (plus `Cargo.lock` crate checksums), which is integrity-only and therefore an **exception** under `ADR-20261010-pin-outside-apt`. It would also be a large, long build on every bump.

## Sway

### Availability

- trixie has 1.10.1-2 on wlroots 0.18 (`Depends: libwlroots-0.18`). There is no backport. sid and forky have 1.12-1.
- Upstream releases 1.11 (2025-06-08, wlroots 0.19) and 1.12 (2026-05-25, wlroots 0.20) ship signed tarballs (`.tar.gz.sig`) ([releases](https://github.com/swaywm/sway/releases)).

### Integration vs. assembly

- **Ships:** the compositor, `swaybar`, `swaynag`, and the i3 IPC.
- **Recommends** `polkitd`, `foot` and `wmenu` (Packages index).
- **Everything else is chosen and assembled, though each part is in trixie:**
  - launcher (`wmenu`, `fuzzel` 1.12)
  - notifications (`mako-notifier` 1.10, `sway-notification-center` 0.11)
  - lock (`swaylock` 1.8.2)
  - idle (`swayidle` 1.8.0)
  - portal (`xdg-desktop-portal-wlr` 0.7.1 plus `-gtk`)
  - polkit agent (`polkit-kde-agent-1`, `lxpolkit`, …)
  - OSD (`swayosd` 0.1.0)
  - clipboard (`wl-clipboard`, `cliphist` 0.5.0)
  - screenshots (`grim`, `slurp`)

  The per-role table in the input note `hyprland-stack-trixie` applies here unchanged.

### Churn

- **The config is i3-compatible and has been stable.** 1.11's changes to defaults were new default key bindings, a `wmenu-run` default menu, and the `sway.desktop` `DesktopNames`. 1.12 added default `playerctl` bindings and changed the `srgb` colour profile meaning while keeping the effective default ([1.11](https://github.com/swaywm/sway/releases/tag/1.11), [1.12](https://github.com/swaywm/sway/releases/tag/1.12)).
- **Trixie to forky** goes 1.10 to 1.12. Neither release note lists a removed config command. The assembled parts each move on their own schedule.

### Automatability

Sway uses one text config with `include` and a system default config. It is fully declarative and reloadable.

### Keyboard-first workflow

Sway is a manual tiling WM (i3 model), with workspaces and a launcher bound in config.

### Mac habits

- keyd's application mapper supports Sway, and so does Toshy (via its `ipc` module).
- Sway has no built-in synthetic shortcut sending. This is my inference: no such command appears in the release notes read.

### Theming reach

Sway has no palette system. Every component has its own config, so a palette is spread with templates, Omarchy-style (input note, "Theme system").

### Security baseline fit

Everything, including the assembled parts listed, comes from Debian main.

## niri

### Availability

- **Not in Debian** (no `niri` in any suite; sid has only an unrelated `niri-companion`).
  - WNPP: [#1065355](https://bugs.debian.org/1065355) began as an RFP in 2024-03 and was retitled ITP on 2026-03-22.
  - A follow-up says "there is packaging work for niri on salsa under the rust import, and it hasn't yet reached an uploadable state".
  - The Rust team notes that "the tricky part is packaging all the dependencies" (bug log).
- **Upstream.**
  - v26.04 was released 2026-04-25. Releases come every three to six months: v25.05, 25.08, 25.11, 26.04 ([releases](https://github.com/niri-wm/niri/releases)).
  - Each release ships only a `*-vendored-dependencies.tar.xz`, with no binary and no signature. The `v26.04` tag is annotated and reported `unsigned` (tag API).
  - The MSRV is 1.85 ("our minimum supported Rust version is now 1.85", v26.04 notes), which matches trixie's rustc 1.85.1.
- **Installing on Debian.** niri's Getting Started points Debian-based users to a pacstall package or a source build. Its quick start covers only Fedora, Arch and Ubuntu 25.10+ (via a PPA) ([Getting Started @v26.04](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Getting-Started.md)).
- **omari as reference.** omakasui's Debian+niri setup, omari, now lives on [Codeberg](https://codeberg.org/omakasui/omari-setup); the GitHub repo is read-only. It installs `niri`, `xwayland-satellite`, `walker`, `waybar`, `mako-notifier`, `swaylock`, `swayidle`, `mate-polkit` and the portals ([`install/omari-base.packages`](https://codeberg.org/omakasui/omari-setup/src/commit/3d7e4d27ac4f8c68d57f6aa5cbb093c2d2cf92ee/install/omari-base.packages)). niri and xwayland-satellite come from **omakasui's own apt repo**:
  - `https://packages.omakasui.org trixie main` carries `niri 26.04-1+trixie`, `xwayland-satellite 0.8.3-1+trixie`, `ghostty 1.3.1-1+trixie` and `walker 2.17.1-1+trixie` ([Release](https://packages.omakasui.org/dists/trixie/Release), Packages index, 74 entries, dated 2026-10-10).
  - omari fetches the repo's keyring over HTTPS, with no fingerprint check, and writes a `signed-by` sources entry with no pin ([`bin/omari-update-keyring`](https://codeberg.org/omakasui/omari-setup/src/commit/3d7e4d27ac4f8c68d57f6aa5cbb093c2d2cf92ee/bin/omari-update-keyring)).

### Integration vs. assembly

- **niri itself provides** the compositor, an overview (Mod+O), a built-in screenshot UI (`Print`, `Ctrl+Print`, `Alt+Print`), a hotkey overlay and, since 25.11, an Alt-Tab recent-windows switcher ([default-config.kdl @v26.04](https://github.com/niri-wm/niri/blob/v26.04/resources/default-config.kdl); [v25.11 notes](https://github.com/niri-wm/niri/releases/tag/v25.11)).
- **It needs separately**, by its own account ("niri is not a complete desktop environment", [Important Software @v26.04](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Important-Software.md)):
  - a notification daemon
  - portals: `xdg-desktop-portal-gtk`, `xdg-desktop-portal-gnome` "required for screencasting", and `gnome-keyring`
  - a polkit agent
  - xwayland-satellite for X11 apps (not in Debian)
- **The default config** spawns `waybar`, `fuzzel`, `alacritty` and `swaylock`.
- **Left to choose, besides those above:** bar, launcher, lock, idle, OSD and clipboard history.

### Churn

- **Written policy:** "As a rule, niri updates should not break existing config files … the default config from niri v0.1.0 still parses fine on v25.02". The policy applies to releases, not to commits in between ([Configuration: Introduction @v26.04](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Configuration:-Introduction.md)).
- **Deprecations are soft.** For example, `output { background-color }` became deprecated in 25.11 in favour of `layout { background-color }` (v25.11 notes).
- **A Debian major upgrade doesn't move niri itself**, because it isn't from Debian.

### Automatability

- The config is KDL, loaded from `~/.config/niri/config.kdl`, falling back to `/etc/niri/config.kdl`. It is live-reloaded, and `niri validate` checks it (Configuration: Introduction).
- **Includes** (since 25.11) are positional, and included files merge section by section, "useful for … third-party tools to robustly inject niri configuration" ([v25.11 notes](https://github.com/niri-wm/niri/releases/tag/v25.11)). omari layers its defaults and the user's files this way. Its `config.kdl` `include`s `~/.local/share/omari/default/niri/*.kdl` first, then `include optional=true` user files such as `bindings.kdl` and `input.kdl` that override them ([`config/niri/config.kdl`](https://codeberg.org/omakasui/omari-setup/src/commit/3d7e4d27ac4f8c68d57f6aa5cbb093c2d2cf92ee/config/niri/config.kdl)).

### Keyboard-first workflow

- niri uses scrollable tiling: columns on an infinite horizontal strip, with dynamic vertical workspaces.
- `Mod` is Super on a TTY and can be configured (since 25.05) ([Key Bindings @v26.04](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Configuration:-Key-Bindings.md)).
- Per-output and per-workspace layout overrides arrived in 25.11.

### Mac habits

- niri has no built-in key translation.
- Toshy supports niri "via `wlroots` method" (Toshy README). keyd's application mapper doesn't list niri.

### Theming reach

- niri has no palette system. Each component is themed separately, and omari renders `default/themed/niri.kdl.tpl` from a theme palette (omari tree).
- Flatpak and GTK apps read GNOME's settings through `xdg-desktop-portal-gnome`, so dark mode is set with `dconf write /org/gnome/desktop/interface/color-scheme` (Important Software).

### Security baseline fit

The baseline admits no niri source as **verified**:

- **Upstream tarball:** unsigned. It would come in as an **exception** with a pinned sha256 and be built with trixie's rustc.
- **omakasui apt repo:** a signed third-party repo, but omakasui rebuilds niri rather than publishing it. The baseline's "signed vendor apt repo" assumes the vendor publishes it. Admitting it would mean committing its fingerprint and pinning the repo to its own packages, and it also carries `ghostty`, `walker` and `elephant`.
- **xwayland-satellite** carries the same choice.

## Hyprland (dropped; for reference)

The map dropped Hyprland for its churn and the work of assembling it (map Notes). From the input note `hyprland-stack-trixie`:

- It is only in trixie-backports (0.55.2), and upstream 0.56 is blocked by build dependencies that trixie lacks.
- Since 0.55 its config is Lua.
- The backports plugins can't be installed.
- Backports has no security support.

It is the only candidate with compositor-level Super→Ctrl shortcut sending (`send_shortcut`; input note `macos-inventory-and-tools`).

## Comparison table

This table summarises the sections above; each cell's citation is in its candidate's section. "Parts to assemble" counts the ticket's ten roles (bar, launcher, notifications, lock, idle, portal, polkit agent, OSD, clipboard, screenshots) that the environment does not cover itself, plus tiling where it isn't native.

| Criterion | GNOME | KDE Plasma | COSMIC | Sway | niri |
|---|---|---|---|---|---|
| **In trixie** | 48.7 | 6.3.6 | no | 1.10.1 | no |
| **In trixie-backports** | no | no | no | no | no |
| **Upstream now** | 51 (3 majors ahead) | 6.7.5; 6.8 on 2026-10-14 (4 feature releases ahead) | epoch 1.10.0 | 1.12 (2 minors ahead) | 26.04 |
| **Off-Debian route** | EGO for extensions not in Debian | KDE Store for scripts/widgets | source build (rustc ≥ 1.93; bpo has 1.95), ~31 repos | none needed | source build (rustc 1.85 OK), or omakasui apt repo |
| **Parts to assemble** | 2: clipboard history and tiling (both extensions; GPaste and Tiling Assistant are in Debian) | 0 (autotiling would be a KDE Store script) | 1: clipboard history | 9 of 10 (bar is built in), plus portal config | 8 of 10 (screenshots and switcher built in), plus xwayland-satellite |
| **Churn** | Extension API changes every 6 months; ESM break at 45; X11 removed in 50; trixie→forky = 48→50+ | 5→6 break already behind trixie; forky stays in 6.x | 1.0 in Dec 2025; 1.1–1.10 since Jun 2026; versioned config with fallback | Stable i3 syntax; 1.10→1.12 without removed commands | Written no-break policy for releases; soft deprecations |
| **Automatability** | dconf keyfiles (system db, declarative) or `gsettings` (imperative); EGO schemas complicate keyfiles | INI cascade `/etc/xdg` → `~/.config` with `[$i]` locks; panel layout is generated | RON file per key, system defaults + user overrides, versioned | Text config + `include` | KDL + `include`, `/etc/niri` fallback, live reload, `niri validate` |
| **Keyboard-first** | Workspaces + overview; tiling only via extension | Manual tile layouts (Meta+T), KRunner; per-desktop layouts need ≥ 6.4 | Built-in autotiling, launcher, workspaces | Manual tiling (i3) | Scrollable tiling, overview, Alt-Tab |
| **Mac Cmd habits** | keyd app mapper (Debian) or Toshy (+ EGO extension) | Toshy (KWin script); keyd mapper doesn't list Plasma | Toshy (D-Bus); keyd mapper doesn't list it | keyd app mapper or Toshy | Toshy (wlroots method); keyd mapper doesn't list it |
| **Theming reach** | Shell + GTK3 + accent/light-dark for libadwaita at runtime; full libadwaita and Qt need hacks/templates | Plasma + Qt at runtime; GTK2/3 via kde-gtk-config; scheduled light/dark needs ≥ 6.5 | Shell + GTK3 + GTK4 + Qt + VS Code from one palette, runtime | None built in; templates per component | None built in; templates per component |
| **Baseline fit** | Debian-only if limited to Debian-packaged extensions; each EGO extension is an exception (unsigned zip) | All Debian | Exception only (unsigned tags, source build) | All Debian | Exception (unsigned tarball) or third-party signed apt repo |

## What I couldn't establish

- **No install or apt solver run.** Installability comes from reading `Depends` in the indices. A trial in the test VM (`apt install -s` for each desktop's package set, and a COSMIC or niri build) would confirm it.
- **Library floors for building COSMIC on trixie.** COSMIC was only checked for its Rust version. Whether its C library floors (libinput, wayland-protocols, libdisplay-info, gstreamer) are met by trixie wasn't checked against each component's build files.
- **Clipboard history for COSMIC** in third-party applets wasn't surveyed.
- **Plasma.** Whether KDE Store downloads are signed, how far Plasma colour schemes reach into libadwaita apps, and the churn record of autotiling KWin scripts across 6.x were not checked.
- **GNOME locks and profiles.** dconf locks and profile layering (`user-db` over `system-db`) were not covered by the admin page cited; the repo already uses a profile file.
- **Cinnamon's and LXQt's Wayland status** wasn't read from upstream; they were screened only.
- **No time-based light/dark switch was found in the GNOME 50 or 51 release notes** (to match the Mac's automatic switching). An extension or a script would have to do it.
- **Toshy on Debian** (its venv and services) wasn't measured against the baseline. The input note `macos-inventory-and-tools` already rates it heavy.
- **Forky's release date and its final GNOME/Plasma versions** are unknown. "48→50+" and "6.3→6.7+" are today's forky contents.
