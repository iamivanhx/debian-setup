# Porting audit — `beelink_debian_post_install.sh`

The legacy 1595-line `beelink_debian_post_install.sh` was the porting source for
Phases 1–2. This document walks its 25 numbered steps (STEP 0 through STEP 24)
and records the disposition of each: **ported** to a new module, **dropped**
because PRD §6 rules it out, or **carried forward** to a future phase.

After this audit the legacy script is deleted from the repo root; it survives
only in git history.

References:

- PRD: `ideas/ser8-dev-setup/PRD.md` (§5 architecture, §6 non-goals, §7 constraints).
- Plan: `.plans/ser8-dev-setup.md` (§Phase 2 closing act = delete this script).
- Memory: `project_desktop_target` (GNOME + Gruvbox supersedes the PRD §5.5 KDE
  line), `project_runtime_manager` (mise supersedes the §5.7 pnpm/uv/golang line).

## A note on "dropped from explicit list"

When this audit says a legacy package is "dropped from the explicit install
list", it means *the new modules do not install that package by name*. The
package may still arrive on the box through someone else's apt dependency
chain, but this audit makes no claim about *which* chain — Debian's
Depends/Recommends graph is large and changes between releases. The canonical
check is "boot a fresh Debian 13 install, run `./run.sh`, see what's there."
If a package the legacy script used to install turns out to be needed and
isn't, the fix is to add it to the relevant module's explicit package list,
not to argue about transitivity.

---

## Step-by-step

### STEP 0 — OS detection & hardware fingerprint
- OS gate (require Debian trixie): **ported to** `modules/00-base.sh:8-13`.
- Hardware-detection block (`detect_hardware`): **dropped** — PRD §7 fixes the
  hardware target to the SER8; smoke tests assert correctness rather than runtime
  fingerprinting.
- `REAL_USER` / `REAL_HOME` resolution: **ported to** `run.sh:11-20`
  (`SETUP_HOME` variable consumed by every module).

### STEP 1 — APT sources (main + backports) & system update
- `/etc/apt/sources.list` rewrite with `contrib non-free non-free-firmware`:
  **dropped** — Debian 13 ships with deb822-style sources by default; the
  installer's `non-free-firmware` selection (`docs/install.md`) provides the
  components.
- Backports source: **ported to** `modules/00-base.sh:18` →
  `templates/etc/apt/sources.list.d/backports.list`.
- Backports pin priority: **ported with a value change** — legacy `200`, new
  `100`. `modules/00-base.sh:19` → `templates/etc/apt/preferences.d/backports`
  pins all backports at priority 100; per-package pins at priority 900
  (e.g. `templates/etc/apt/preferences.d/kernel-backports`) opt specific
  packages in.
- `apt-get update && full-upgrade`: **ported to** `modules/00-base.sh:23-29`
  (replaced `full-upgrade` with `upgrade` — the modules don't need package
  removal during convergence).

### STEP 2 — Backported kernel
- `linux-image-amd64` and `firmware-amd-graphics` from backports: **ported to**
  `modules/10-hardware.sh:43,52-55` (`_backports_packages=(linux-image-amd64
  firmware-amd-graphics)`).
- `linux-headers-amd64`: **dropped from the install list** — no DKMS module is
  built by the new modules in v1, so headers aren't needed at install time.
- Kernel + headers pin to backports track: **ported to**
  `modules/10-hardware.sh:10` → `templates/etc/apt/preferences.d/kernel-backports`,
  which pins both `linux-image-*` and `linux-headers-*` at priority 900. The
  pin already covers headers, so an operator adding a DKMS module later need
  only add `linux-headers-amd64` to `_backports_packages` — the pin doesn't
  need widening.
- AMD firmware backports pin: **ported to** `modules/10-hardware.sh:15` →
  `templates/etc/apt/preferences.d/firmware-amd-backports`.
- `dkms`, `gcc`, `make` install for DKMS: **dropped** — no out-of-tree modules
  are built by the new modules. `build-essential` (in `00-base`'s core list)
  provides `gcc`/`make` if ever needed.
- Manual `update-initramfs -u -k …` + `update-grub`: **dropped** — dpkg postinst
  hooks handle both. Removing the manual calls also removes a known idempotency
  hazard.

### STEP 3 — Minimal GNOME desktop
- `gnome-shell`, `gdm3`, `nautilus`, `gnome-text-editor`: **ported to**
  `modules/40-desktop.sh:44-53` (in `_desktop_packages`).
- `gnome-session`, `gnome-control-center`, `polkitd`, `pkexec`, `gnome-keyring`,
  `xdg-desktop-portal{,-gnome}`, `at-spi2-core`, `gsettings-desktop-schemas`,
  `adwaita-icon-theme`, `fonts-cantarell`, `gvfs`, `xdg-utils`,
  `xdg-user-dirs-gtk`: **dropped from the explicit install list.** Per the
  note at the top of this doc, the audit does not assert whether each lands
  transitively when `40-desktop` installs `gnome-shell` + `gdm3` on Debian 13;
  if any of them turns out to be missing on a real fresh install, add it to
  `_desktop_packages`.
- `gnome-terminal`: **dropped** — replaced by **Ghostty** (`40-desktop.sh:258-274`)
  per the desktop-target decision (memory: `project_desktop_target`).
- `network-manager` + `network-manager-gnome`: **dropped from the explicit
  install list.** `gnome-shell` depends on `libnm0` (the NetworkManager client
  library), not on the `network-manager` daemon or applet, so a fresh box may
  not have NM running after `./run.sh`. Wired Ethernet on the SER8 is brought
  up by the netinst's "standard system utilities" + ifupdown/systemd-networkd
  selection, so headless operation is fine; if the GNOME Wi-Fi/wired indicator
  is wanted, add `network-manager` to `_desktop_packages` and enable the
  service. No smoke test currently asserts `systemctl is-active NetworkManager`.
- `/etc/NetworkManager/conf.d/10-managed.conf` + `/etc/network/interfaces`
  rewrite: **dropped** — since the modules don't install NM (see above), the
  rewrite has nothing to act on. If the operator later adds `network-manager`
  to `_desktop_packages` and the installer-configured wired interface is still
  owned by `ifupdown` (`/etc/network/interfaces`), an additional pass to
  reduce that file to loopback-only (or to set NM's `managed=true` in
  `[ifupdown]`) is required for NM to take the interface over.
- `gdm3` enable + `graphical.target`: **dropped from explicit code** — the
  `gdm3` package postinst already sets these on a fresh install; the
  `templates/etc/dconf/db/gdm.d/40-gruvbox` drop-in is the new module's only
  GDM-side concern.
- `xdg-user-dirs-update` for `REAL_USER`: **dropped from explicit code** —
  `xdg-user-dirs` (in `40-desktop.sh:51`) runs on first GDM login.

### STEP 4 — Essential base packages
- `git`, `curl`, `wget`, `htop`, `btop`, `fastfetch`, `build-essential`,
  `ca-certificates`, `gnupg`, `lsb-release`, `jq`, `tree`, `fzf`, `ripgrep`,
  `fd-find`, `bat`, `unzip`: **ported to** `modules/00-base.sh:46-51`.
- Additionally `eza`, `zoxide`, `plocate`, `gh`, `neovim`, `make` (split out of
  `build-essential`): **new** in `00-base` (not from legacy).
- `vim`, `nano`: **dropped** — replaced by `neovim` (the user's preference;
  `00-base.sh:51`).
- `cmake`, `pkg-config`: **dropped** — not required by v1 scope.
- Archive group (`zip`, `unzip`, `p7zip-full`, `tar`, `gzip`, `bzip2`,
  `xz-utils`, `zstd`): **partially ported** — `unzip` is in the core list
  above (used by `40-desktop` to unpack the Nerd Font + theme tarballs); the
  rest are **dropped from the explicit install list** because Debian base
  ships `tar`/`gzip`/`bzip2`/`xz-utils`/`zstd` and `zip`/`p7zip-full` aren't
  in v1 scope.
- Filesystem group (`ntfs-3g`, `exfatprogs`, `dosfstools`, `btrfs-progs`):
  **dropped** — PRD §6 "No btrfs"; the others are not in v1 scope (no external
  removable media handling).
- Network tools (`net-tools`, `iproute2`, `iw`, `rfkill`, `openssh-client`,
  `nmap`, `traceroute`, `iputils-ping`, `dnsutils`): **dropped from explicit
  list** — `iproute2`/`iputils-ping`/`openssh-client` are base; `openssh-server`
  is installed in `30-security`; the rest are not in v1 scope.
- Hardware-info group (`lshw`, `hwinfo`, `pciutils`, `usbutils`, `dmidecode`,
  `inxi`): **dropped** — not in v1 scope.
- Monitoring group (`iotop`, `iftop`, `powertop`, `nvtop`, `sysstat`):
  **dropped** — `htop`/`btop` (in core list) cover the dev box's needs.
- `python3`, `python3-pip`, `python3-venv`: **dropped from explicit list** —
  `python3` is a Debian-base interpreter pulled in by countless deps (xdg-*,
  apt itself, etc.), so the new modules don't pin it. `python3-pip` and
  `python3-venv` are intentionally not installed — project Python versions are
  managed by **mise** (PRD §5.7; memory: `project_runtime_manager`), whose
  shims at `~/.local/share/mise/shims/` precede `/usr/bin` in the user's zsh
  `PATH` (`50-shell.sh:111-124` smoke). Note: unlike `nodejs`/`npm`/`ruby`,
  apt's `python3` family is *not* in the `apt-mark hold` list at
  `00-base.sh:34` — the system Python is intentionally left to apt, and mise
  layers on top via PATH ordering rather than via a hold.
- `bash-completion`, `command-not-found`, `software-properties-common`, `tmux`,
  `screen`: **dropped** — not in v1 scope.

### STEP 5 — AMD GPU driver & firmware (Radeon 780M / RDNA 3)
- `firmware-amd-graphics`: **ported to** `10-hardware.sh:43` (backports-pinned).
- `libdrm-amdgpu1`, `xserver-xorg-video-amdgpu`, `mesa-vulkan-drivers`,
  `mesa-va-drivers`: **dropped from the explicit install list.** The Mesa
  userspace stack is not in v1 scope to pin; whatever lands transitively from
  `gnome-shell` / GTK / firefox-esr is what gets used.
- `libva-utils`, `vulkan-tools`, `radeontop`: **dropped** — these are
  operator-debugging tools, not in v1 scope. Install ad-hoc via apt if needed
  for a one-off investigation.
- `amdgpu` entry in `/etc/modules`: **dropped** — udev autoloads `amdgpu` on
  RDNA hardware; the explicit entry is redundant.
- `/etc/environment.d/80-amd-wayland.conf` (`GBM_BACKEND`,
  `__GLX_VENDOR_LIBRARY_NAME`, `LIBVA_DRIVER_NAME`, `AMD_VULKAN_ICD`,
  `ROC_ENABLE_PRE_VEGA`): **dropped** — modern Mesa autodetects all of these on
  Wayland; the manual overrides are no longer recommended for AMD.

### STEP 6 — CPU microcode & power management (Ryzen 7 8845HS / Zen 4)
- `amd64-microcode`: **ported to** `10-hardware.sh:60`.
- `cpupower`, `linux-cpupower`, `thermald`, `acpid`, `acpi`, `lm-sensors`,
  `powertop`: **dropped** — superseded by **`power-profiles-daemon`** in
  `10-hardware.sh:60,82-105`. PPD owns governor selection, EPP hints, and
  thermal policy in one daemon; the legacy `/etc/default/cpupower` schedutil
  override is replaced by the PPD profile knob (`POWER_PROFILE` env var).

### STEP 7 — Kernel parameters (GRUB)
- `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_pstate=active idle=nomwait
  nowatchdog loglevel=3 mitigations=auto"`: **dropped** — PRD doesn't specify
  GRUB cmdline tuning; `power-profiles-daemon` drives `amd_pstate` without an
  explicit cmdline flag, and `nowatchdog`/`loglevel`/`mitigations` overrides
  aren't in v1's hardening scope.
- `GRUB_TIMEOUT=5`: **dropped** — Debian 13 default (`5`) is unchanged.

### STEP 8 — NVMe I/O optimisation
- `/etc/udev/rules.d/60-nvme-ioscheduler.rules` (mq-deadline + APST):
  **ported to** `10-hardware.sh:22-26` →
  `templates/etc/udev/rules.d/60-nvme-scheduler.rules`. The legacy
  filename is also explicitly cleaned up at `10-hardware.sh:29-32`.
- `fstrim.timer` enable/start: **dropped** — enabled by default in Debian 13's
  `util-linux` package (timer ships unit-enabled).

### STEP 9 — Wi-Fi & Bluetooth firmware
- `firmware-iwlwifi`, `firmware-realtek`, `firmware-atheros`: **dropped** — the
  Debian 13 netinst with `non-free-firmware` selected installs whichever firmware
  family the installer's hardware detection picks for the running box (it does
  not blanket-install all three). The SER8 is wired-Ethernet for v1 scope per
  `docs/install.md`, so the Wi-Fi/BT firmware sets are not required.
- `wireless-tools`, `wpasupplicant`, `rfkill`: **dropped from the explicit
  install list** — not in v1 scope (the SER8 is a wired-Ethernet dev box).
  `wpasupplicant` would land transitively with `network-manager` if the
  operator ever adds that to `_desktop_packages`; `wireless-tools` is
  deprecated upstream; `rfkill` is an optional util-linux binary that the
  operator should add explicitly if it turns out to be needed.
- `bluetooth`, `bluez`, `bluez-tools` + service enable: **dropped** —
  out of v1 scope (the SER8 is a wired-Ethernet dev box; no Bluetooth peripherals
  in scope).

### STEP 10 — Audio (PipeWire + WirePlumber)
- `pipewire`, `pipewire-alsa`, `pipewire-audio`, `pipewire-jack`,
  `pipewire-pulse`, `wireplumber`, `libspa-0.2-bluetooth`, `libspa-0.2-jack`,
  `gstreamer1.0-pipewire`, `pavucontrol`, `alsa-utils`, `sof-firmware`:
  **dropped from the explicit install list.** PipeWire is the default audio
  stack in Debian 13; the GNOME stack pulls some of these in. If audio doesn't
  work on a fresh box, add the relevant packages to `_desktop_packages`.
- `snd_sof_amd_acp` in `/etc/modules`: **dropped** — udev autoloads the SOF
  AMD ACP driver on Phoenix/Hawk Point silicon.

### STEP 11 — Thermal sensors & monitoring
- `lm-sensors`, `fancontrol`, `i2c-tools`, `stress-ng`, `sensors-detect --auto`:
  **dropped** — `power-profiles-daemon` (in `10-hardware`) owns thermal policy;
  manual sensor wiring is not in v1 scope.

### STEP 12 — Memory / swap tuning
- `/etc/sysctl.d/99-ser8-tuning.conf` (swappiness 10, dirty_ratio,
  TCP BBR, file-max, inotify, nmi_watchdog, sched_autogroup): **dropped** —
  PRD doesn't specify sysctl tuning; Debian 13 defaults are sufficient for a
  64 GB dev box. Could be revisited under "Resilience" (Phase 4) if real
  workloads benchmark a need.
- `zram-tools` + `/etc/default/zramswap` (25% / zstd): **dropped** — the SER8
  ships with 64 GB DDR5; zram swap doesn't justify the moving part.

### STEP 13 — Firmware update daemon (fwupd)
- `fwupd` package install: **ported to** `10-hardware.sh:60`.
- `fwupd` service enable: **ported to** `10-hardware.sh:75-78`.
- `fwupdmgr refresh --force` at module time: **dropped** — `fwupd-refresh.timer`
  (installed by the `fwupd` package, enabled by default) handles refresh on a
  schedule.

### STEP 14 — Security hardening
- **UFW** (default-deny ingress, allow ssh, enable): **dropped** — replaced by
  **nftables** in `30-security.sh:39-58` → `templates/etc/nftables.conf` (LAN-only
  ruleset templated with `${LAN_SUBNET}`).
- **fail2ban** + `/etc/fail2ban/jail.local`: **dropped** — PRD §6 explicit
  non-goal.
- `30-security` additionally lands (new, not in legacy):
  - `templates/etc/ssh/sshd_config.d/10-ser8.conf` — sshd hardening drop-in.
  - `${SETUP_HOME}/.ssh/authorized_keys` deployed from `SSH_AUTHORIZED_KEYS`.
  - `templates/etc/apt/apt.conf.d/50unattended-upgrades` +
    `templates/etc/apt/apt.conf.d/20auto-upgrades` — security-only unattended
    upgrades.
  - `passwd -l root` — locks the root account.
  - `templates/etc/sudoers.d/ser8-no-nopasswd` — explicit no-NOPASSWD policy.

### STEP 15 — Flatpak & Flathub
- `flatpak` install + Flathub remote add: **dropped** — not in v1 scope; the
  dev box uses native apt + mise + Docker.
- `gnome-software-plugin-flatpak`: **dropped** — same reason.

### STEP 16 — Optional desktop applications
- `firefox-esr`: **ported to** `40-desktop.sh:52`.
- `flameshot`: **ported to** `40-desktop.sh:48`.
- `gnome-tweaks`: **ported to** `40-desktop.sh:46`.
- `vlc`, `gparted`, `timeshift`, `copyq`: **dropped** — not in v1 scope.
- Google Chrome `.deb`: **dropped** — Firefox-ESR is the v1 browser on the SER8.

### STEP 17 — Optional developer tools
- **VS Code** (Microsoft APT repo + `code` package): **ported to**
  `60-dev.sh:81-97` — installed via the official `.deb` (the postinst registers
  `/etc/apt/sources.list.d/vscode.sources` for future updates).
- **Node.js LTS** (NodeSource APT repo + `nodejs`): **superseded** — runtime
  managed by **mise** (`60-dev.sh:58,126-139`); `nodejs`, `npm`, and `ruby` are
  `apt-mark hold`ed in `00-base.sh:34` to prevent apt from shadowing the
  mise-managed install. PRD §5.7 / memory: `project_runtime_manager`.
- **Go** (`golang` apt package): **superseded** — managed by mise (operator
  runs `mise use --global go@1`; documented in `60-dev.sh` header comment).
- Additionally `60-dev` lands (new, not in legacy):
  - Ruby/Rails build deps (autoconf, bison, clang, libssl-dev, libreadline-dev,
    libyaml-dev, libpq-dev, libsqlite3-dev, default-libmysqlclient-dev, …) so
    `mise install ruby@3` succeeds.
  - `lazygit` (apt) + `lazydocker` (upstream binary).
  - **Socket Firewall (sfw)** wrapping pnpm via the `.zshrc` template.

### STEP 18 — Gaming optimisations (legacy block was commented out)
- Steam, Lutris, MangoHud, GameMode, Proton, i386 multiarch, file-descriptor
  limits: **dropped** — already commented out in the legacy script; the SER8 is
  a dev box, not a gaming rig.

### STEP 19 — Hardware video acceleration verification
- `mesa-va-drivers`, `gstreamer1.0-vaapi`: **dropped from the explicit install
  list.** Per the note at the top of this doc, the audit does not assert which
  of these arrive via apt dependency chains. Both are runtime hardware-decode
  support, not debug tools — if a GStreamer-based player or a browser turns
  out to need VA-API on a fresh box, add the missing package to
  `_desktop_packages`.
- `libva-utils`: **dropped** — operator-debugging tool (`vainfo`); install
  ad-hoc via apt for one-off investigation.
- `ffmpeg`, `mpv`: **dropped** — not in v1 scope.
- `vainfo` verification at module time: **dropped** — deferred to the Phase 5
  acceptance walk, which is fleshed out by issue 017
  (`.plans/ser8-dev-setup/issues/017-docs-flesh-out.md`). `docs/acceptance.md`
  is currently a stub with placeholders.

### STEP 20 — Systemd & journald tuning
- `/etc/systemd/journald.conf.d/99-ser8.conf` (`SystemMaxUse=500M`,
  `ForwardToKMsg=no`, `Compress=yes`): **dropped** — Debian 13 defaults
  (10 % of `/var`, compression on) are appropriate for the SER8's 1 TB NVMe.
- Disable `ModemManager.service`, `avahi-daemon.service`: **dropped** — neither
  package is installed by the new module set; nothing to disable.
- `/etc/systemd/system.conf.d/99-timeouts.conf` (`DefaultTimeoutStopSec=15s`,
  `DefaultTimeoutStartSec=30s`): **dropped** — PRD doesn't call for systemd
  timeout tuning.

### STEP 21 — Desktop environment extras (GNOME branch + KDE branch)
- GNOME branch: `gnome-shell-extension-manager`, `gnome-shell-extensions`,
  `gnome-tweaks`: **ported to** `40-desktop.sh:45-46`.
- `dconf-editor`, `gnome-browser-connector`: **dropped** — not in v1 scope.
- gsettings calls (`power-button-action`, `scale-monitor-framebuffer`):
  **dropped** — neither key is set by the new modules. The system dconf
  database (`templates/etc/dconf/db/local.d/40-gruvbox`, applied in
  `40-desktop.sh:224-238`) sets only the Gruvbox look-and-feel keys; the
  power-button action and Mutter experimental flag fall back to GNOME 48
  defaults. If either turns out to matter on real hardware, add them to the
  dconf template.
- KDE elif branch (`plasma-widgets-addons`, `kde-plasma-desktop`, `powerdevil`,
  `kscreen`): **dropped** — GNOME is the chosen desktop per the
  `project_desktop_target` decision (supersedes PRD §5.5 KDE line). The KDE
  branch was dead code as of the GNOME decision.

### STEP 22 — zsh + Oh My Zsh + Starship (Gruvbox Rainbow) + Nerd Font
- `zsh`, `zsh-common`: **ported to** `50-shell.sh:32` (`zsh`).
- **Oh My Zsh** + plugins (`zsh-autosuggestions`, `fast-syntax-highlighting`,
  `zsh-autocomplete`, `you-should-use`): **dropped** — PRD §6 explicit
  non-goal ("No oh-my-zsh, zinit, zplug, or any zsh framework"). Replaced by
  **framework-free zsh** with apt-only plugins (`zsh-autosuggestions`,
  `zsh-syntax-highlighting`) in `50-shell.sh:32`. A previous Oh-My-Zsh install
  in `~/.oh-my-zsh` is intentionally left in place; the new `.zshrc` simply
  stops sourcing it (header comment in `50-shell.sh:10-12`).
- JetBrainsMono Nerd Font system-wide install: **ported to**
  `40-desktop.sh:38-39,66-82` (pinned `NERD_FONT_VERSION=3.4.0`).
- Starship binary (curl install): **ported to** `50-shell.sh:46-54`
  (pinned `STARSHIP_VERSION=v1.25.1`, installed to `/usr/local/bin`).
- `chsh -s zsh REAL_USER`: **ported to** `50-shell.sh:59-63`.
- Starship Gruvbox Rainbow preset + Debian symbol injection: **superseded** —
  static `starship.toml` template in `templates/home/user/.config/starship.toml`,
  deployed by `50-shell.sh:69`. No runtime preset generation or sed-injection.
- Templated `.zshrc` (HISTSIZE, plugins, aliases, keybindings, starship init):
  **ported to** `50-shell.sh:68` →
  `templates/home/user/.zshrc` (framework-free).
- Aliases (`ls --color=auto`, `..`/`...`, `update` apt alias, `bat`/`fd` fallback):
  **carried forward** into the new `.zshrc` template where they fit the
  framework-free design; tests assert via `test_50_shell` smoke functions.

### STEP 23 — Ubuntu look & feel (Yaru base + Gruvbox-GTK theme + dock)
- `yaru-theme-gtk`, `yaru-theme-gnome-shell`, `yaru-theme-icon`,
  `yaru-theme-sound`: **dropped** — superseded by **Gruvbox-Dark-Medium** GTK
  theme + **Gruvbox-Plus-Dark** icon pack in `40-desktop.sh:121-129`
  (tarball-pinned to specific refs for reproducibility).
- `gtk2-engines-murrine`, `gtk2-engines-pixbuf`: **dropped** — GTK2 engines
  aren't needed by GNOME 48 on Wayland.
- `papirus-icon-theme` + `papirus-folders --color yaru`: **dropped** —
  replaced by Gruvbox-Plus-Dark.
- `fonts-ubuntu`, `fonts-ubuntu-console`: **dropped** — replaced by
  `fonts-inter-variable` (UI, `40-desktop.sh:50`) and **JetBrainsMono Nerd Font**
  (terminal/monospace, system-installed by `40-desktop.sh:66-82`).
- `gnome-shell-extension-dashtodock`: **ported to** `40-desktop.sh:186`
  (installed from extensions.gnome.org via the per-user EGO installer, pinned
  to whatever build matches the running GNOME Shell).
- `gnome-shell-extension-appindicator`: **ported to** `40-desktop.sh:190`.
- `gnome-shell-extension-desktop-icons-ng`: **dropped** — not part of the new
  Gruvbox-dock-centric design.
- `gnome-shell-extension-user-theme`: **ported via** the apt
  `gnome-shell-extensions` meta-package (in `40-desktop.sh:45`), which ships
  the User Theme extension as a system extension. The system dconf DB enables
  it (`templates/etc/dconf/db/local.d/40-gruvbox` `enabled-extensions` list)
  and sets `[org/gnome/shell/extensions/user-theme] name='Gruvbox-Dark-Medium'`.
- Additionally `40-desktop` installs (new, not in legacy): `space-bar@luchrioh`,
  `tactile@lundal.io`, `just-perfection-desktop@just-perfection`.
- **Gruvbox-GTK-Theme** git clone + `install.sh` (`sassc` build): **superseded**
  by pinned-ref tarball download in `40-desktop.sh:88-119,121-124`. No runtime
  sass compilation.
- Gruvbox wallpaper copy to `/usr/share/backgrounds/gruvbox/`: **superseded** by
  the templated `templates/usr/local/share/backgrounds/gruvbox-dark.svg` deployed
  via `40-desktop.sh:195`.
- `gsettings set` calls for theme, icons, cursor, fonts, dark mode, night-light,
  dash-to-dock layout, button-layout, sound theme: **superseded** — the
  Gruvbox-bearing subset of these keys is in
  `templates/etc/dconf/db/local.d/40-gruvbox` (applied in `40-desktop.sh:224-238`
  via `dconf update`).
- `num-workspaces`: **ported with a value change** — legacy `4` → new `6`, via
  `[org/gnome/desktop/wm/preferences] num-workspaces=6` in the same dconf
  template.
- `enable-hot-corners`: **dropped** — not set by the new dconf template; reverts
  to GNOME 48 default.
- `XCURSOR_SIZE=24` in `/etc/environment`: **dropped** — dconf
  `org.gnome.desktop.interface cursor-size = 24` in the same template handles
  this.
- GDM theming (`/etc/dconf/db/gdm.d/01-gruvbox-look`): **ported to**
  `templates/etc/dconf/profile/gdm` + `templates/etc/dconf/db/gdm.d/40-gruvbox`
  (deployed in the same dconf block).
- GTK4 / libadwaita symlink (`~/.config/gtk-4.0/{gtk.css,gtk-dark.css,assets}`):
  **ported to** `40-desktop.sh:198-219`.
- Yaru cursor theme: **dropped** — replaced by `bibata-cursor-theme` apt
  package (`40-desktop.sh:49`).

### STEP 24 — Final cleanup
- `apt-get autoremove -y`, `apt-get autoclean -y`, `apt-get clean`: **dropped** —
  Debian's `apt-daily-upgrade.timer` and `apt-daily.timer` handle cache cleanup;
  no need for explicit run-time cleanup in an idempotent setup script.
- Interactive reboot prompt (`ask_yes_no "Reboot now"`): **dropped** —
  PRD §6 "No interactive prompts in `run.sh`". The operator reboots when ready.

---

## Summary

All 25 steps (STEP 0 through STEP 24) walked above. Most steps split across
more than one disposition (e.g. Step 5's firmware package is ported, its
environment overrides are dropped), so a tidy per-bucket tally would be
misleading. The high-level shape:

- A small core was **ported cleanly** — OS gate (0), apt sources + upgrade (1),
  backports kernel (2), GNOME core (3), NVMe scheduler (8), zsh + starship (22).
- A larger set was **kept in spirit but re-implemented** against a PRD-sanctioned
  better mechanism: `power-profiles-daemon` instead of cpupower/thermald
  (Step 6); `fwupd-refresh.timer` instead of a manual refresh (13); `mise`
  instead of NodeSource/apt-golang (17); system **dconf db** instead of
  per-session `gsettings set` (21, 23); pinned Gruvbox-Dark-Medium + Gruvbox-Plus-
  Dark instead of Yaru + Papirus (23); nftables instead of UFW (14).
- The remainder is **out of v1 scope** per PRD §6 or PRD §7 constraints: GRUB
  cmdline tuning (7), bluetooth firmware (9), explicit PipeWire pinning (10),
  lm-sensors (11), sysctl + zram (12), Flatpak (15), gaming optimisations
  (18 — already commented-out), explicit VA-API verification (19 — carried
  forward to Phase 5 acceptance), journald + ModemManager tuning (20),
  fail2ban (14), and final-cleanup theatre (24).

Nothing in the legacy script requires opening a new follow-up issue to port.

---

## Closing note

The legacy script was the porting source for issues 001 (helpers), 006 (00-base),
007 (10-hardware), 009 (30-security), 011 (40-desktop), 012 (50-shell), and 013
(60-dev). Its helpers (`deploy_config`, `safe_install`) live on inside
`lib/common.sh`. After this audit it is deleted; only git history retains it.
