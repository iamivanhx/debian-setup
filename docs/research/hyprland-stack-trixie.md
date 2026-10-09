# Hyprland stack on Debian trixie (amd64 and arm64)

Research for [Research: Hyprland stack on trixie](https://github.com/iamivanhx/debian-setup/issues/29), a ticket on the map [Map: Hyprland dev environment refactor (SER8 replaces the Mac)](https://github.com/iamivanhx/debian-setup/issues/26). Gathered 2026-10-09.

**Question.** What does a complete Hyprland desktop look like on Debian trixie plus trixie-backports, on both amd64 and arm64? Where are the gaps?

## Answer in brief

- **The core is all in trixie-backports, with the same version on amd64 and arm64.** That covers hyprland 0.55.2, xdg-desktop-portal-hyprland, uwsm, hyprlock, hypridle, hyprpaper, hyprpolkitagent, hyprlauncher, hyprpicker, hyprsunset, and every hypr\* library. Trixie itself has no Hyprland packages at all.
- **Every role has at least one Debian candidate on both arches.** No role is empty. What is missing are specific preferred tools: Ghostty, walker/elephant, satty, gpu-screen-recorder, awww (formerly swww), impala, bluetui, wiremix, pwvucontrol, hyprshot, ashell, ironbar, eww, ReGreet and wl-clip-persist. None of them is in trixie, trixie-backports, or the mise registry.
- **Backports trails upstream by one minor release, and the next one is stuck.** Backports has 0.55.2, while upstream and forky have 0.56.2. hyprland 0.56 needs libinput >= 1.29, Lua 5.5 and wayland-protocols >= 1.49, and neither trixie nor trixie-backports has any of them.
- **Two traps for the spec.**
  - The `hyprland-plugin-*` packages in backports cannot be installed. They need an ABI that the backports hyprland doesn't provide.
  - Since 0.55, Hyprland's config is Lua (`hyprland.lua`). The old hyprlang `.conf` is deprecated, and the default wiki documents git HEAD, not 0.55.
- **The SER8's GPU is covered.** The Radeon 780M is handled by trixie's 6.12 kernel and by the backports 7.2 kernel. The backports firmware ships all the GPU blobs it needs. The repo already pins kernel and firmware to backports.

## How this was gathered

- **Debian versions** come from the archive's own `Packages.xz` indices. The suites are trixie (Release 13.7, dated 2026-09-12), trixie-updates, trixie-security and trixie-backports (Release dated 2026-10-09). Each was fetched for both `binary-amd64` and `binary-arm64`, in main, contrib, non-free and non-free-firmware ([deb.debian.org/debian/dists/](https://deb.debian.org/debian/dists/), [security.debian.org](https://security.debian.org/debian-security/dists/trixie-security/)). Each package can be checked on `https://packages.debian.org/<suite>/<package>`.
- **Unstable, forky and source-level versions** come from [madison](https://qa.debian.org/madison.php) and [tracker.debian.org](https://tracker.debian.org/pkg/hyprland).
- **Upstream versions** come from each project's GitHub (or Codeberg) releases API, read on 2026-10-09.
- **mise registry** entries come from [`jdx/mise` `registry/`](https://github.com/jdx/mise/tree/aa9a27ef01b50d24fa437deaa32ba35c5cc4cbd4/registry) at `aa9a27e`, which has 1018 entries.

**Reading the versions.**

- "trixie" includes trixie-security when that is newer.
- **amd64 and arm64 carry the same version unless a cell shows `amd64 / arm64`.** Every such difference is a binNMU suffix (`+bN`), meaning a rebuild of the same source.
- "—" means no package in that suite on either architecture.

## Role-by-role table

### Hyprland itself and its ecosystem

| Role | Candidate (Debian binary) | trixie | trixie-backports | Upstream latest | Notes |
|---|---|---|---|---|---|
| Compositor | `hyprland` | — | 0.55.2+ds-1~bpo13+1 | [v0.56.2](https://github.com/hyprwm/Hyprland/releases/tag/v0.56.2) (2026-08-05) | Forky and sid have 0.56.2+ds-3 ([madison](https://qa.debian.org/madison.php?package=hyprland&text=on)). The package ships `hyprland`, `hyprctl`, `hyprpm`, `start-hyprland`, and both `hyprland.desktop` and `hyprland-uwsm.desktop` ([filelist](https://packages.debian.org/trixie-backports/arm64/hyprland/filelist)). |
| Plugins | `hyprland-plugin-*` (hyprexpo, hyprbars, …) | — | 0.53.0-3~bpo13+1 | tag v0.56.0 | **Cannot be installed.** They depend on `hyprland-abi-c8f4c09`, but backports hyprland provides only `hyprland-abi-ff3b2cb` (Packages index). |
| Portal | `xdg-desktop-portal-hyprland` | — | 1.4.1-1~bpo13+1 | [v1.4.1](https://github.com/hyprwm/xdg-desktop-portal-hyprland/releases/tag/v1.4.1) | Up to date. Recommends `xdg-desktop-portal-gtk`, which is 1.15.3-1 in trixie and handles the file picker. `xdg-desktop-portal` is 1.20.3+ds-1 in trixie. |
| Session start | `uwsm` | — | 0.26.7+ds-2~bpo13+1 | tag v0.27.0 | Forky has 0.27.0. Depends on `systemd`, `python3-xdg` and `python3-dbus`, and Recommends a launcher (`fuzzel \| wofi \| rofi \| …`). |
| Session start | `start-hyprland` (in `hyprland`) | — | 0.55.2 | — | The wiki's launch wrapper ([wiki: Configuring/Core](https://github.com/hyprwm/hyprland-wiki/blob/ede823b521d8bade91894cf1b3ff25b5ab7ee64b/content/configuring/core/_index.md)). |
| Session start | `app2unit` | — | — | tag v1.4.4, no release assets | Not in Debian: [ITP #1137593](https://bugs.debian.org/1137593). The Debian Hyprland team already has a [salsa repo](https://salsa.debian.org/hyprland-team/app2unit). |
| Polkit agent | `hyprpolkitagent` | — | 0.1.3-2~bpo13+1 | [v0.2.0](https://github.com/hyprwm/hyprpolkitagent/releases/tag/v0.2.0) | Sid and forky have 0.2.0-1, so backports is one release behind. Needs `qml6-module-org-hyprland-style` (from hyprland-qt-support, 0.1.0-1~bpo13+1). |
| Lock | `hyprlock` | — | 0.9.6-1~bpo13+1 | v0.9.6 | Up to date. |
| Idle | `hypridle` | — | 0.1.8-1~bpo13+1 | v0.1.8 | Up to date. |
| Wallpaper | `hyprpaper` | — | 0.8.4-1~bpo13+1 | v0.8.4 | Up to date. |
| Launcher | `hyprlauncher` | — | 0.1.6-1~bpo13+1 | v0.1.6 | Up to date. |
| Colour picker | `hyprpicker` | — | 0.4.7-1~bpo13+1 | v0.4.7 | Up to date. |
| Night light | `hyprsunset` | — | 0.4.0-1~bpo13+1 | v0.4.0 | Up to date. |
| Shutdown UI | `hyprshutdown` | — | 0.1.1-1~bpo13+1 | v0.1.1 | Up to date. |
| GUI dialogs | `hyprland-guiutils` (+ transitional `hyprland-qtutils`) | — | 0.2.2-1~bpo13+1 | v0.2.2 | Up to date. |
| Not packaged | `hyprsysteminfo`, `hyprqt6engine`, `hyprpwcenter` | — | — | v0.2.0, v0.1.0, v0.1.2 | None ship release binaries. hyprpwcenter has [ITP #1137557](https://bugs.debian.org/1137557). |

### Hyprland utility libraries

All of these are in trixie-backports only, with identical versions on amd64 and arm64. Backports keeps several old SONAMEs side by side so that tools built against older versions still install.

| Source | Binary packages in trixie-backports | Upstream latest | Notes |
|---|---|---|---|
| hyprutils | `libhyprutils13` 0.14.2-1~bpo13+1, plus older `libhyprutils12` 0.13.1 and `libhyprutils10` 0.11.1 | v0.14.2 | hyprland 0.55.2 links `libhyprutils12`. hyprlauncher and hyprshutdown still link `libhyprutils10`. |
| hyprlang | `libhyprlang2` 0.6.8-4~bpo13+1 | v0.6.8 | |
| aquamarine | `libaquamarine14` 0.15.1, plus `13` 0.14.0, `10` 0.11.0 and `9` 0.10.0 | v0.15.1 | hyprland 0.55.2 links `libaquamarine10`. |
| hyprgraphics | `libhyprgraphics4` 0.5.1-2~bpo13+1 | v0.5.1 | |
| hyprcursor | `libhyprcursor0`, `hyprcursor-util` 0.1.13-2~bpo13+1 | v0.1.13 | |
| hyprwire | `libhyprwire3`, `hyprwire-scanner` 0.3.1-3~bpo13+1 | v0.3.1 | |
| hyprtoolkit | `libhyprtoolkit5` 0.5.3-1~bpo13+1 | v0.6.0 | Sid has 0.6.0-3. |
| hyprland-protocols | `hyprland-protocols` 0.7.1-2~bpo13+1 | v0.7.1 | |
| hyprwayland-scanner | `hyprwayland-scanner` 0.4.6-1~bpo13+1 | v0.4.6 | |
| hyprland-qt-support | `qml6-module-org-hyprland-style` 0.1.0-1~bpo13+1 | v0.1.0 | |

### Login manager

| Candidate | trixie | trixie-backports | Upstream | Notes |
|---|---|---|---|---|
| `greetd` | 0.10.3-4 | 0.10.3-7~bpo13+1 | — | |
| `tuigreet` | 0.9.1-5 | — | [0.11.1](https://github.com/apognu/tuigreet/releases/tag/0.11.1) | Two minor releases behind. |
| `nwg-hello` (GTK greeter for greetd) | 0.3.0-1 | — | — | |
| ReGreet | — | — | [0.5.0](https://github.com/rharish101/ReGreet/releases/tag/0.5.0), no binary assets | Not in Debian and not in mise. |
| `sddm` | 0.21.0+git20250502.4fe234b-2 | — | — | Omarchy (reference only) uses SDDM ([omarchy-base.packages @988f44e](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/install/omarchy-base.packages)). |
| `gdm3` | 48.0-2 | — | — | |
| none (TTY + uwsm) | — | — | — | The wiki documents launching uwsm from a TTY, and warns that PAM keyring unlock then has to be set up by hand ([wiki: uwsm.md](https://github.com/hyprwm/hyprland-wiki/blob/ede823b521d8bade91894cf1b3ff25b5ab7ee64b/content/useful-utilities/uwsm.md)). |

### Desktop roles

| Role | Candidate | trixie | trixie-backports | Upstream latest | Off-Debian route (mise registry / upstream artifacts) |
|---|---|---|---|---|---|
| Bar | `waybar` | 0.12.0-1 | — | [0.15.0](https://github.com/Alexays/Waybar/releases/tag/0.15.0) | Forky has 0.15.0. |
| Bar / shell toolkit | `quickshell` | — | 0.3.0-1~bpo13+1 | — | Sid has 0.3.1. Omarchy's current base list uses quickshell instead of waybar. |
| Bar | ashell | — | — | [0.11.0](https://github.com/MalpenZibo/ashell/releases/tag/0.11.0) | **x86_64 only** (`.deb`, `.rpm`, `.tar.xz`). No checksum file, though GitHub reports per-asset sha256 digests. |
| Bar | ironbar | — | — | [v0.19.1](https://github.com/JakeStanger/ironbar/releases/tag/v0.19.1) | arm64 and x86_64 tarballs, no checksum file. [RFP #1059637](https://bugs.debian.org/1059637). |
| Bar | eww | — | — | v0.6.0 (2024), no assets | Source only. [RFP #1056072](https://bugs.debian.org/1056072). |
| Launcher | `fuzzel` | 1.12.0+ds-1 | — | 1.15.0 ([Codeberg](https://codeberg.org/dnkl/fuzzel/releases), tarball + `.sig`) | |
| Launcher | `wofi` 1.4.1-1+b2; `tofi` 0.9.1-2+b1 / +b2; `bemenu` 0.6.15; `wmenu` 0.1.9-2 / -2+b1 | as listed | — | — | |
| Launcher | `rofi` | 1.7.5-0.1+b2 | — | [2.0.0](https://github.com/davatorium/rofi/releases/tag/2.0.0), source only | **Debian's 1.7.5 is an X11 build** (depends only on libxcb\*), so on Hyprland it runs under XWayland. Native Wayland arrived upstream in 2.0.0 ("Wayland is now an officially supported backend"). |
| Launcher | walker (+ elephant backend) | — | — | [walker v2.17.2](https://github.com/abenz1267/walker/releases/tag/v2.17.2), [elephant v2.22.1](https://github.com/abenz1267/elephant/releases/tag/v2.22.1) | **x86_64/amd64 only** for both. No checksum file. |
| Launcher | anyrun | — | — | v26.6.1, no assets | [RFP #1057118](https://bugs.debian.org/1057118). |
| Notifications | `mako-notifier` | 1.10.0-1 | — | [v1.11.0](https://github.com/emersion/mako/releases/tag/v1.11.0) (tarball + `.sig`) | |
| Notifications | `sway-notification-center` | 0.11.0-1 | — | v0.12.6 | |
| Notifications | `dunst` 1.12.2-1; `fnott` 1.7.1+ds-1 | as listed | — | — | The wiki's must-have list names dunst, mako, fnott and swaync ([must-have.md](https://github.com/hyprwm/hyprland-wiki/blob/ede823b521d8bade91894cf1b3ff25b5ab7ee64b/content/useful-utilities/must-have.md)). |
| Lock (alt) | `swaylock` 1.8.2-1; `gtklock` 4.0.0-1 | as listed | — | — | |
| Idle (alt) | `swayidle` | 1.8.0-1 / 1.8.0-1+b1 | — | — | |
| Wallpaper (alt) | `swaybg` | 1.2.1-1 / 1.2.1-1+b1 | — | — | |
| Wallpaper (alt) | awww (formerly swww) | — | — | [v0.12.1 on Codeberg](https://codeberg.org/LGFae/awww/releases), no assets | The GitHub repo is archived and renamed ([LGFae/swww](https://github.com/LGFae/swww)). [ITP #1084753](https://bugs.debian.org/1084753) is filed under the old name. |
| Polkit agent (alt) | `polkit-kde-agent-1` 4:6.3.6-1; `lxqt-policykit` 2.1.0-1; `mate-polkit` 1.26.1-4+b1 / +b2; `lxpolkit` 0.5.6-2 | as listed | — | — | `polkit-gnome` / `policykit-1-gnome` is not in trixie. |
| Screenshot | `grim` 1.4.0+ds-2+b1 / +b2; `slurp` 1.5.0-1 / -1+b1; `grimshot` 1.10.1-1 (src sway-contrib); `swappy` 1.5.1-2 | as listed | — | — | |
| Screenshot | `flameshot` | 12.1.0+ds-2 | 13.3.0+git20251204-1~bpo13+1 | — | |
| Screenshot annotate | satty | — | — | [v0.22.0](https://github.com/gabm/Satty/releases/tag/v0.22.0) | aarch64 and x86_64 tarballs, no checksum file. |
| Screenshot | hyprshot | — | — | 1.3.0 (2024), no assets | A shell script over grim and slurp. [RFP #1124305](https://bugs.debian.org/1124305). |
| Screen recording | `wf-recorder` 0.5.0-2; `obs-studio` 30.2.3+dfsg-3; `kooha` 2.3.0-5 | as listed | — | — | |
| Screen recording | gpu-screen-recorder | — | — | upstream not on GitHub (not checked) | **Only sid and forky**, at 5.13.8-1. Madison lists only a source row there, no binaries ([madison](https://qa.debian.org/madison.php?package=gpu-screen-recorder&text=on)). [ITA #1142238](https://bugs.debian.org/1142238). |
| Screen recording | wl-screenrec | — | — | v0.3.1, no assets | [RFP #1040786](https://bugs.debian.org/1040786). |
| Clipboard | `wl-clipboard` | 2.2.1-2 | 2.3.0-1~bpo13+1 | — | |
| Clipboard history | `cliphist` | 0.5.0-1+b9 | — | [v0.7.0](https://github.com/sentriz/cliphist/releases/tag/v0.7.0) | Upstream binaries are amd64, 386 and 32-bit arm, **no arm64**. Debian's build covers both arches. |
| Clipboard history | `clipman` 1.2.0+git20200218; `copyq` 10.0.0-1; `nwg-clipman` 0.2.4-1 | as listed | — | — | |
| Clipboard persistence | wl-clip-persist | — | — | v0.5.0, no assets | |
| Network UI | `network-manager` 1.52.1-1 (`nmcli`, `nmtui`); `network-manager-gnome` 1.36.0-3+b1 / 1.36.0-3 (nm-applet); `iwd` 3.8-2 (`iwctl`) | as listed | — | — | `nmtui` ships in `network-manager` ([filelist](https://packages.debian.org/trixie/arm64/network-manager/filelist)). |
| Network UI | impala (iwd TUI) | — | — | [v0.9.0](https://github.com/pythops/impala/releases/tag/v0.9.0) | aarch64 and x86_64 static musl binaries, no checksum file. |
| Bluetooth UI | `bluez` 5.82-1.1 (`bluetoothctl`); `blueman` 2.4.4-1 | as listed | — | — | |
| Bluetooth UI | bluetui | — | — | [v0.8.2](https://github.com/pythops/bluetui/releases/tag/v0.8.2) | aarch64 and x86_64 musl binaries, no checksum file. [ITP #1120128](https://bugs.debian.org/1120128). |
| Bluetooth UI | overskride | — | — | v0.6.6 | Flatpak plus source tarball only. |
| Audio stack | `pipewire` | 1.4.2-1 | 1.6.9-2~bpo13+1 | — | The wiki marks PipeWire and WirePlumber as needed for screen sharing. |
| Audio stack | `wireplumber` | 0.5.8-2 | 0.5.12-1~bpo13+1 | — | |
| Audio UI | `pavucontrol` 6.1-1; `pulsemixer` 1.5.1-1.1; `pamixer` 1.6-1+b1; `helvum` 0.5.1+20240829-2; `qpwgraph` 0.8.2-1 | as listed | — | — | |
| Audio UI | wiremix | — | — | tag v0.11.0, no GitHub release | |
| Audio UI | pwvucontrol | — | — | 0.5.3, Flatpak only | [ITP #1103904](https://bugs.debian.org/1103904). |
| OSD | `swayosd` | 0.1.0-5 | — | [v0.3.2](https://github.com/ErikReider/SwayOSD/releases/tag/v0.3.2) | Trixie's build is two minor releases behind. |
| OSD | `wob` 0.14.2-1 / -1+b1; helpers `brightnessctl` 0.5.1, `playerctl` 2.4.1 | as listed | — | — | `avizo` is not in Debian. |
| Qt/GTK on Wayland | `qt6-wayland` 6.8.2-4; `qtwayland5` 5.15.15-3; `qt6ct` 0.10-2+b1; `nwg-look` 1.0.2-1+b3 | as listed | — | — | The wiki's must-have list asks for Qt5 and Qt6 Wayland support. |
| XWayland | `xwayland` | 2:24.1.6-1 | — | — | Recommended by `hyprland`. |
| Keyring | `gnome-keyring` | 48.0-1 | — | — | |

### Terminal

| Candidate | trixie | trixie-backports | Upstream latest | Off-Debian route |
|---|---|---|---|---|
| Ghostty | — | — | tag v1.3.1 (no GitHub release) | Not in Debian ([ITP #1091469](https://bugs.debian.org/1091469)). Not in the mise registry. Details below. |
| `foot` | 1.21.0-2 | — | [1.28.0](https://codeberg.org/dnkl/foot/releases) (tarball + `.sig`) | Omarchy's current base list ships foot. |
| `kitty` | 0.41.1-2+deb13u2 (security) | — | [v0.49.2](https://github.com/kovidgoyal/kitty/releases/tag/v0.49.2) | Upstream ships `kitty-<v>-x86_64.txz` and `-arm64.txz`, each with a detached `.sig` signature. |
| `alacritty` | 0.15.1-3 | — | [v0.17.0](https://github.com/alacritty/alacritty/releases/tag/v0.17.0) | No Linux binaries upstream. |
| WezTerm | — | — | 20240203-110809 (last release) | `Debian12.deb` (amd64, with `.sha256`) and `Debian12.arm64.deb` (no `.sha256`). No release since February 2024. [RFP #993625](https://bugs.debian.org/993625). |

**Ghostty in detail.**

- **Upstream binaries.** "The Ghostty project only officially distributes prebuilt binaries for macOS". Linux relies on distro packages and community builds ([ghostty-org/website docs/install/binary.mdx @7962e91](https://github.com/ghostty-org/website/blob/7962e91e190ff226be1a4983eb9368b7ddb4dff9/docs/install/binary.mdx)). Ubuntu 26.04 has it officially. Debian doesn't.
- **Source.** Official source tarballs are at `https://release.files.ghostty.org/VERSION/ghostty-VERSION.tar.gz`, with a `.minisig` signed by key `RWQlAjJC23149WL2sEpT/l0QKy7hMIFhYdQOFy0Z7z7PbneUgvlsnYcV` ([build.mdx](https://github.com/ghostty-org/website/blob/7962e91e190ff226be1a4983eb9368b7ddb4dff9/docs/install/build.mdx)).
- **Building 1.3.x on trixie** needs Zig 0.15.2, which Debian doesn't have; mise has it (`core:zig`). It also needs `libgtk-4-dev` 4.18.6, `libadwaita-1-dev` 1.7.6 and `libgtk4-layer-shell-dev` 1.0.4, all in trixie on both arches. `minisign` is 0.12-1 in trixie, and mise also has it (`aqua:jedisct1/minisign`).
- **The community .deb.** The repo installs [mkasberg/ghostty-ubuntu](https://github.com/mkasberg/ghostty-ubuntu/releases/tag/1.3.1-0-ppa2) `ghostty_1.3.1-0.ppa2_amd64_trixie.deb` (`modules/40-desktop.sh:29-30`).
  - That release also has an `arm64_trixie.deb`.
  - It has no checksum file, only GitHub's per-asset digests.
  - The current module hardcodes amd64 and doesn't verify the download.
  - Ghostty's docs warn that community binaries "carry a much higher risk".

## AMD Radeon 780M (SER8) on trixie and the backports kernel

| Item | trixie | trixie-backports | Source |
|---|---|---|---|
| Kernel `linux-image-amd64` | 6.12.107-1 (trixie-security 6.12.111-1) | 7.2.6-1~bpo13+1 | Packages index |
| Kernel `linux-image-arm64` (the VM) | 6.12.107-1 (trixie-security 6.12.111-1) | 7.2.6-1~bpo13+1 | Packages index |
| `firmware-amd-graphics` (non-free-firmware) | 20250410-2 | 20260810-1~bpo13+1 | Packages index |
| Mesa (`libgl1-mesa-dri`, `mesa-vulkan-drivers`, `mesa-va-drivers`, `libgbm1`) | 25.0.7-2+deb13u1 | 26.1.6-1~bpo13+1 | Packages index |
| `libdrm-amdgpu1` | 2.4.124-2 | — | Packages index |
| `amd64-microcode` | 3.20250311.1 (amd64 only) | — | Packages index |

- **The GPU's blocks.** The 780M sits on the Ryzen 7 8845HS, which is Hawk Point. The kernel's APU table gives Hawk Point the same blocks as Phoenix: DCN 3.1.4, GC 11.0.1 / 11.0.4, VCN 4.0.2, SDMA 6.0.1, and MP0 13.0.4 / 13.0.11 ([apu-asic-info-table.csv](https://github.com/torvalds/linux/blob/af32da41b0327b9c6a37856ba82b6760d6c8d10e/Documentation/gpu/amdgpu/apu-asic-info-table.csv)).
- **Kernel support.** At `v6.12`, the kernel's amdgpu IP discovery has cases for GC 11.0.1 and 11.0.4, DCN 3.1.4 and VCN 4.0.2 ([amdgpu_discovery.c @v6.12](https://github.com/torvalds/linux/blob/v6.12/drivers/gpu/drm/amd/amdgpu/amdgpu_discovery.c)). So trixie's own kernel drives the 780M, and the backports kernel is extra headroom.
- **Firmware.** The trixie and backports builds of `firmware-amd-graphics` both ship every blob those blocks load: `gc_11_0_{1,4}_*`, `dcn_3_1_4_dmcub.bin`, `psp_13_0_{4,11}_*`, `sdma_6_0_1.bin` and `vcn_4_0_2.bin` ([trixie filelist](https://packages.debian.org/trixie/all/firmware-amd-graphics/filelist), [backports filelist](https://packages.debian.org/trixie-backports/all/firmware-amd-graphics/filelist)). The `non-free-firmware` component must be enabled.
- **Mesa.** `hyprland` depends directly on `libgl1-mesa-dri` and `polkitd` (Packages index). Trixie's Mesa 25.0.7 satisfies it, and backports Mesa 26.1.6 is optional.
- **What the repo pins today.** `templates/etc/apt/preferences.d/` pins `linux-image-*`, `linux-headers-*` and `firmware-amd-graphics` to backports at priority 900. Mesa isn't pinned, and `docs/porting-audit.md` STEP 5 dropped the explicit Mesa installs and the AMD environment overrides.
- **No AMD-specific Hyprland guidance.** The Hyprland wiki's install and FAQ pages carry none. Its only GPU warning is for NVIDIA ([installation.md](https://github.com/hyprwm/hyprland-wiki/blob/ede823b521d8bade91894cf1b3ff25b5ab7ee64b/content/getting-started/installation.md)).
- **Running in a VM** is "not officially supported" and needs Mesa's virgl drivers (same page, "Running In a VM"). That matters for the arm64 VM ticket.

## How Debian maintains the Hyprland packages

- **Team.** The packages belong to "Debian Hyprland Maintainers" `<team+hyprland@tracker.debian.org>`. The uploaders are Alan M Varghese, Carl Keinath, Chow Loong Jin and Alex Myczko ([debian/control on salsa](https://salsa.debian.org/hyprland-team/hyprland/-/blob/debian/latest/debian/control)).
- **Repos.** 27 repos live in the [salsa `hyprland-team` group](https://salsa.debian.org/hyprland-team). The `hyprland` repo has no backports branch: backports uploads are made outside the branches published on salsa. The 0.55.2 backport was uploaded by Carl Keinath ([bpo changelog](https://metadata.ftp-master.debian.org/changelogs/main/h/hyprland/hyprland_0.55.2+ds-1~bpo13+1_changelog)).
- **Cadence to unstable** is fast: one to six days after an upstream tag. Backports have arrived 10 to 19 days after upstream, but only for some releases. Timeline from [tracker.debian.org news](https://tracker.debian.org/pkg/hyprland) and the [upstream releases](https://github.com/hyprwm/Hyprland/releases):

| Upstream | Tagged | In unstable | In testing | In trixie-backports |
|---|---|---|---|---|
| 0.54.3 | 2026-03-27 | 2026-03-31 | 2026-04-03 | 2026-04-06 |
| 0.55.2 | 2026-05-16 | 2026-05-19 | 2026-05-23 | 2026-06-04 |
| 0.55.4 | 2026-06-11 | 2026-06-17 | 2026-06-28 | never |
| 0.56.2 | 2026-08-05 | 2026-08-06 | 2026-08-11 | not as of 2026-10-09 |

- **Why 0.56 hasn't been backported.** This is my inference from the build dependencies, not a maintainer statement. The salsa `debian/control` for 0.56.2 build-depends on:
  - `libinput-dev (>= 1.29)`: trixie has 1.28.1, with no backport.
  - `liblua5.5-dev`: only in forky and sid.
  - `wayland-protocols (>= 1.49)`: backports has 1.47.
  - `libglaze-dev (>= 7.0.0)`: backports has 8.4.0.

  The first three would need backporting first.
- **Debian patches the source down to trixie's compiler.** `gcc-port.patch` works around gnu++26 features missing from GCC 14. Its header says "Can be dropped when Debian's gcc catches up", and the backports changelog adds "fix: string_view + string requires C++26" ([patch](https://salsa.debian.org/hyprland-team/hyprland/-/blob/debian/latest/debian/patches/gcc-port.patch), [series](https://salsa.debian.org/hyprland-team/hyprland/-/blob/debian/latest/debian/patches/series)). The series also relaxes the glaze version requirement.

## Risks of running Hyprland from backports

1. **No security support.** "Is there security support for packages from backports.debian.org? A: Unfortunately not. This is done on a best effort basis by the people who track the package" ([backports FAQ](https://backports.debian.org/FAQ/)).
2. **Co-installability is untested.** "The co-installability of all available backports is not tested, and it is strongly recommended to opt-into the use of specific backported packages" ([backports Instructions](https://backports.debian.org/Instructions/)). The broken plugin packages above are a live example.
3. **Hyprland pulls a core library from backports.** hyprland 0.55.2 depends on `libxkbcommon0 (>= 1.12.3)`. Trixie has 1.7.0-2, so `libxkbcommon0` 1.13.1-1~bpo13+1 comes from backports, and almost every GUI toolkit links it. Backports also supplies the `libhypr*` and `libaquamarine*` libraries. Its other dependencies resolve from trixie, including `libre2-11` through its `libre2-11-absl20240722` Provides, `libudis86-0`, and `libtomlplusplus3t64` (Packages index).
4. **Backports can stall.** Backports may not run ahead of testing (Instructions), and a release whose new build dependencies aren't backported waits. 0.55.4 never arrived, and 0.56.x hasn't arrived after two months in testing.
5. **The hypr\* tools drift apart.** hyprpolkitagent (0.1.3 against 0.2.0) and hyprtoolkit (0.5.3 against 0.6.0) lag sid. The backports set is a snapshot of whatever the backporter rebuilt, not a matched release train.
6. **The docs move ahead of the package.** The wiki at wiki.hypr.land documents git HEAD by default and says to pick your version ([configuring/_index.md](https://github.com/hyprwm/hyprland-wiki/blob/ede823b521d8bade91894cf1b3ff25b5ab7ee64b/content/configuring/_index.md)). For backports that means <https://wiki.hypr.land/0.55.0/>. Its Configuring/Start page says "Since Hyprland 0.55, hyprlang is deprecated in favor of lua", with the config at `~/.config/hypr/hyprland.lua`. Any config the spec writes should be Lua.
7. **Upgrades follow automatically, and the upgrade path is safe.** Backports carries `NotAutomatic: yes` and `ButAutomaticUpgrades: yes`, so installed backports packages track new backports versions (backports Release, Instructions). The `~bpo` version suffix keeps the path to forky clean (FAQ). The repo's `preferences.d/backports` already pins `*` to 100.
8. **Hyprland is unofficial on Debian.** The wiki lists Debian with a `*`, which means "not officially supported" ([installation.md](https://github.com/hyprwm/hyprland-wiki/blob/ede823b521d8bade91894cf1b3ff25b5ab7ee64b/content/getting-started/installation.md)). Its Debian tab tells you to `sudo apt install -t trixie-backports hyprland`.

## The mise registry and the off-Debian route

- **The mise registry has none of the desktop tools.** At `aa9a27e` there are no entries for ghostty, wezterm, walker, elephant, swww/awww, satty, gpu-screen-recorder, wl-screenrec, impala, bluetui, wiremix, pwvucontrol, overskride, hyprshot, ashell, ironbar, eww, regreet, anyrun, wl-clip-persist, avizo, cliphist, rofi, uwsm, swayosd, hyprland, waybar, kitty, alacritty or foot. It does have `zig` (`core:zig`) and `minisign` (`aqua:jedisct1/minisign`), which a Ghostty source build would use.
- **mise's `github:` backend can still install any release asset without a registry entry.** It "checks the digest GitHub reports for the asset, or a checksum file published in the same release, and on public GitHub it checks GitHub artifact attestations when the release has them" ([mise docs: github backend](https://github.com/jdx/mise/blob/aa9a27ef01b50d24fa437deaa32ba35c5cc4cbd4/docs/dev-tools/backends/github.md)).
- **For the security baseline**, the binary-only candidates above (satty, impala, bluetui, ironbar, walker, elephant, ashell) publish no checksum file or signature of their own. The only digest is the one GitHub computes on upload. Whether that counts as "verified against a checksum the project publishes" is a decision for the map.

## Gaps

**Roles that have no Debian or backports package on either architecture.** None: every role in the ticket has at least one candidate in trixie or trixie-backports on both amd64 and arm64. The candidates with no package on either architecture are:

- **Terminal:** Ghostty and WezTerm.
- **Launcher:** walker with elephant, and anyrun.
- **Bar:** ashell, ironbar and eww.
- **Login:** ReGreet.
- **Wallpaper:** awww (formerly swww).
- **Screenshots and recording:** satty, hyprshot, gpu-screen-recorder (sid only) and wl-screenrec.
- **Clipboard:** wl-clip-persist.
- **Network, Bluetooth and audio UIs:** impala, bluetui, overskride, wiremix, pwvucontrol and hyprpwcenter.
- **OSD:** avizo.
- **Hyprland tools:** hyprsysteminfo, hyprqt6engine and app2unit.

**Upstream artifacts missing arm64.** walker, elephant and ashell are x86_64 only. cliphist upstream has no arm64, though Debian's cliphist covers both arches.

**What I couldn't establish:**

- **No apt solver run.** Installability was judged by reading `Depends` and `Provides` in the indices, not by running apt on a trixie host. I checked `hyprland`, the plugins, and the key tools' direct dependencies. A full `apt install -s -t trixie-backports` on each arch would confirm the whole set.
- **No hardware test.** Nothing here was run on a 780M, and I found no first-party note on Hyprland-specific AMD quirks such as VRR, tearing or HDR on Phoenix/Hawk Point.
- **Why 0.55.4 and 0.56.x weren't backported** is inferred from build dependencies. I found no maintainer statement or backports bug.
- **gpu-screen-recorder's upstream** is hosted off GitHub. I didn't check its release artifacts or signatures, and madison showed no binaries in sid.
- **SDDM's and gdm3's behaviour** as Hyprland greeters on trixie wasn't studied.
- **Hyprland in the arm64 VM on the Mac** (virgl or virtio-gpu in UTM or QEMU) belongs to the arm64 VM research. The wiki only says VMs are not officially supported.
- **Checksums on Codeberg.** The Codeberg releases for awww, fuzzel and foot weren't checked for checksum files beyond the `.sig` assets.
- **Whether GitHub's server-side digest meets the "verified" bar** of the security baseline is a policy question for the map, not a fact.
