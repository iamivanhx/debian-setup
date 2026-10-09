# macOS inventory and best tools for the Hyprland dev layer

Research note for the ticket [Research: macOS inventory and best tools](https://github.com/iamivanhx/debian-setup/issues/30), on the map [Map: Hyprland dev environment refactor (SER8 replaces the Mac)](https://github.com/iamivanhx/debian-setup/issues/26). Written 2026-10-09. Terms (**dev layer**, **machine layer**) are from `GLOSSARY.md`.

**Method.** Part 1 was gathered on the Mac (Apple M3 Pro, macOS 27.0.1, arm64) with read-only commands only: `brew leaves`, `brew list --cask`, `ls /Applications`, `ls ~/.config`, `mise ls`, `mise registry`, `code --list-extensions`, `defaults read` of the input-source list, and reads of the shell, prompt, terminal, editor and git config [MAC]. Nothing was installed or changed. Git and ssh config are recorded as structure only: section names, key names, and which tool fills each role, never values. Credential stores and `gh`'s host file were not opened. The Mac is built from the public repo `iamivanhx/macos-setup` [MS], and the local checkout matched its `main` byte for byte on `config.toml`.

Part 3 availability was checked on 2026-10-09 against the map's source order: Debian trixie, then trixie-backports, then mise, then the upstream release. Sources were the Debian QA archive index [MAD], Debian's package file lists [DPF], the mise registry built into mise 2026.9.15 [MISE-REG], and each project's own releases, repo or docs. Versions are as of that date.

## Answer in brief

- **The Mac is small and declarative.** It has 21 Homebrew formulae, 7 casks, and four GUI apps (1Password, Ghostty, Chrome, VS Code), plus Safari. One mise `config.toml` declares the packages, dotfiles and macOS settings [MS]. There is no tiling WM, clipboard manager, dedicated launcher, container runtime, tmux, Neovim, or configured backup.
- **Nearly everything maps to the same tool on Linux.** zsh with its plugins, Starship, fzf, ripgrep, fd, bat, eza, zoxide, jq, delta, lazygit, shellcheck and git all come from Debian trixie [MAD]. uv, pnpm, mikefarah `yq`, tlrc and current gitleaks come from mise [MISE-REG]. VS Code, Chrome and 1Password come from their vendors' signed apt repos.
- **Debian traps.** Debian's `bat` and `fd-find` install as `batcat` and `fdfind` [DPF]. Debian's `yq` is a different program (kislyuk's jq wrapper) [DSRC-YQ]. Debian's `zed` is an OCaml library, not the editor [DSRC-ZED]. `gh` in trixie is 2.46.0 [MAD].
- **Hyprland itself is only in trixie-backports (0.55.2)**, along with hypridle, hyprlock, hyprpaper, xdg-desktop-portal-hyprland, hyprpolkitagent, hyprlauncher and uwsm [MAD][HYP-INST]. Hyprland 0.55 brought a **Lua config** (`hyprland.lua`). hyprlang is deprecated and will be dropped after 1–2 releases [HYP-LUA]. That bears directly on config layering.
- **Arm64 gaps hit the VM.** The 1Password desktop app has no arm64 apt package, only a tarball. Its CLI is in the arm64 repo [1P-REPO][1P-LINUX]. Ghostty has no official Linux binaries, and the community trixie `.deb` ships both arches [GHO][GHO-DEB]. Chrome stable is now in Google's arm64 apt repo [CHR].
- **Cmd habits are the main thing the desktop must absorb.** Cmd+C/V/X/A (terminal-aware), Cmd+Space for a launcher, Cmd+Q/W/Tab, US-International dead keys, fast key repeat, natural scrolling off, and automatic light/dark. Hyprland's `send_shortcut` / `send_key_state` dispatchers do Super-as-Cmd inside the compositor [HYP-DISP]. Omarchy's Lua bindings are a worked, terminal-aware reference [OMA-CLIP].
- **Top candidates where the Mac has nothing:** Walker or Vicinae as launcher (Vicinae is Raycast-compatible), with fuzzel or hyprlauncher as the from-Debian fallback. cliphist for clipboard history. grim, slurp and satty for screenshots. Syncthing and restic for sync and backup. tmux or zellij, atuin, yazi, btop, podman or Docker CE, and distrobox.

## 1. Inventory of this Mac

### How the Mac is built

| Piece | Role | Source |
|---|---|---|
| `macos-setup` repo, linked as `~/.config/mise` | Bootstrap: one mise `config.toml` holds `[tools]`, `[dotfiles]`, `[bootstrap.macos.*]` settings and hooks. A `Brewfile` holds Homebrew packages. `mise run upgrade` is the upgrade task | [MS] `config.toml`, `Brewfile` |
| Steps by hand | GitHub key upload, app sign-ins, VS Code Settings Sync sign-in, default browser, one logout | [MS] `steps-by-hand.md` |

### Packages and apps

| Item | Role | How it arrives on the Mac |
|---|---|---|
| zsh (system) | Shell | built in |
| zsh-autosuggestions, zsh-syntax-highlighting | Shell add-ons | brew |
| starship | Prompt | brew |
| fzf, zoxide | History search and key bindings, directory jumping | brew |
| ripgrep, fd, bat, eza | Search, find, pager, `ls` | brew |
| jq, yq (mikefarah) | JSON and YAML | brew |
| tlrc | tldr-pages client | brew |
| git, gh, git-delta, lazygit | VCS, GitHub CLI, diff pager, git TUI | brew |
| gitleaks, shellcheck | Secret scanning, shell lint | brew |
| mise | Runtime and tool manager; also the Bootstrap engine | brew |
| node (LTS) | JavaScript runtime | mise `[tools]` |
| sfw (Socket Firewall, npm) | Supply-chain wrapper for npm/pnpm installs | mise `npm:` backend |
| pnpm | Node package manager; mise's npm backend is set to use it | brew |
| uv | Python and Python tools (a uv-managed Python is installed) | brew |
| 1Password, 1Password CLI | Password manager, `op`, SSH agent, commit signing | cask |
| Ghostty | Terminal | cask |
| Visual Studio Code | Editor (`EDITOR=code --wait`, git `core.editor`) | cask |
| Google Chrome | Default browser (Safari present but not default) | cask |
| JetBrains Mono Nerd Font | Code and terminal font | cask |
| Codex | AI coding agent | cask |
| Claude Code | AI coding agent | own installer, `~/.local/bin` |
| pi | AI coding agent | own installer, `~/.local/bin` |

`/Applications` holds only 1Password, Ghostty, Google Chrome, Safari, Visual Studio Code and Utilities [MAC]. VS Code extensions: Claude Code, Catppuccin theme, and the Python set (Python, Pylance, debugpy, Python Environments) [MAC].

### Dotfiles: structure and notable choices

Each is a plain file in the repo, linked into place by mise `[dotfiles]` [MS].

- **`~/.zprofile`**: login-shell PATH only. It holds Homebrew `shellenv`, `~/.local/bin` first, pnpm's home, and mise shims for non-interactive shells.
- **`~/.zshrc`**: 50k shared, timestamped history with ignore-dups and ignore-space. Also `compinit`, `EDITOR` set to VS Code, and fzf in 16-color mode with its key bindings. Two eza aliases (`ll`, `la`; git column, directories first). Then `mise activate`, Starship, the two zsh plugins, and zoxide. An optional untracked `~/.zshrc.local` is sourced last. No framework (no oh-my-zsh) and no vi mode.
- **Starship**: Dracula palette, a `λ` prompt character (green on success, red on error), and custom styles for directory, git branch and status, command duration, hostname, username and AWS.
- **Ghostty**: Dracula theme, font size 18, slight minimum contrast. Shell-integration features `sudo`, `ssh-env`, `ssh-terminfo`. A notification when a command over 30 s finishes while unfocused. Windows restored on relaunch, mouse hidden while typing, very large scrollback, and an optional untracked local include.
- **bat**: `ansi` theme, so it follows the terminal palette.
- **git**: identity via `user.useConfigOnly` plus an included local file that holds the signing key (written from a template). Commits and tags are **SSH-signed through 1Password's signer**. `zdiff3` conflicts, `histogram` diffs, delta as pager and interactive diff filter, `rerere`, rebase `autoStash`/`autoSquash`/`updateRefs`, fetch `prune`, push `autoSetupRemote`/`followTags`, branch and tag sorting, `help.autocorrect`, `init.defaultBranch=main`. The global ignore is GitHub's macOS template.
- **ssh**: one wildcard `Host` block whose `IdentityAgent` is 1Password's agent socket. **No key files on disk.** 1Password's `agent.toml` is a templated dotfile.
- **gh**: `git_protocol` set to ssh by a hook. Sign-in is kept out of the repo.
- **VS Code**: Catppuccin Mocha/Latte with `window.autoDetectColorScheme`, JetBrains Mono NF at 18 with ligatures, and autosave and word-wrap settings. **No custom `keybindings.json`**: the default Cmd bindings are in use. Settings Sync is signed in.

### Daily-use utilities

| Job | On this Mac |
|---|---|
| Launcher | Spotlight and the Apps launcher in the Dock. A leftover Raycast extensions directory exists, but Raycast is not installed [MAC] |
| Window manager | None beyond macOS defaults |
| Clipboard | None beyond the system clipboard |
| Screenshots | Built-in `screencapture`: saved to `~/Downloads`, window shadow off [MS] |
| Password manager | 1Password app, CLI, SSH agent, git signing |
| Notes | No notes app installed beyond macOS built-ins. Which built-in is used is unknown (see Gaps) |
| Sync | VS Code Settings Sync. An iCloud Drive folder exists; whether it is in active use is unknown |
| Backup | No Time Machine destination configured [MAC] |
| Browser | Chrome (default), Safari |
| Containers / VMs | None installed |

### macOS settings the user chose

These come from `[bootstrap.macos.*]` [MS]. Dock autohide with six pinned apps. Finder path bar, all extensions shown, new windows open Home. Keyboard press-and-hold **off**, **fast key repeat** (`KeyRepeat 2`, `InitialKeyRepeat 15`), autocorrect off, smart quotes and dashes off. **Natural scrolling off.** **Automatic light/dark switching on.** Battery percentage shown. Firewall and stealth mode on, AirPlay Receiver off. Screen saver at 10 min with a 5 s lock. **Touch ID for `sudo`**. The keyboard input source is **U.S. International – PC** (dead keys) with no modifier remaps [MAC].

## 2. Each item on Debian trixie + Hyprland

Source column follows the map's order. **D** is Debian trixie, **BP** is trixie-backports, **M** is mise, **U** is upstream or a vendor apt repo. Versions are from [MAD], [MISE-REG] and the projects' releases.

| Mac item | Linux equivalent | Source | Notes |
|---|---|---|---|
| zsh + autosuggestions + syntax-highlighting | same | D | zsh 5.9, 0.7.1, 0.8.0 |
| starship | same | D 1.22.1, or M | today `50-shell.sh` pipes `starship.rs/install.sh` into `sh`, which conflicts with the baseline rule against running unreviewed fetched code |
| fzf, zoxide, eza, ripgrep, jq | same | D | fzf 0.60.3, zoxide 0.9.7, eza 0.21.0, ripgrep 14.1.1, jq 1.7.1 |
| bat, fd | same | D | **binaries are `batcat` and `fdfind`** [DPF]; need a symlink or alias, or take M |
| yq (mikefarah) | same | **M** (`aqua:mikefarah/yq`) | Debian's `yq` is kislyuk's jq wrapper, a different syntax [DSRC-YQ] |
| tlrc | tealdeer (`tldr`) | D 1.7.2 | another tldr-pages client [DPF]; tlrc itself is M |
| git, git-delta, lazygit, shellcheck | same | D | git 2.47.3, delta 0.18.2, lazygit 0.50.0, shellcheck 0.10.0 (BP 0.11.0) |
| gh | same | D 2.46.0, or M (`aqua:cli/cli`) | trixie's is old; whether that matters is a choice |
| gitleaks | same | M | D has 8.16.0, forky 8.26.0 |
| mise | same | U (signed apt repo, as `60-dev.sh` does now) | not in any Debian suite [MAD] |
| node LTS, sfw | same | M | as today |
| pnpm, uv | same | **M** (`aqua:pnpm/pnpm`, `aqua:astral-sh/uv`) | uv is only in forky; pnpm is not in Debian [MAD] |
| Claude Code, Codex, pi | same | **M** (`aqua:anthropics/claude-code`, `aqua:openai/codex`, `aqua:earendil-works/pi`) | avoids the piped installers [MISE-REG] |
| 1Password app | same | U: signed apt repo, **amd64 only**; arm64 via tarball [1P-LINUX][1P-REPO] | the SSH agent works on Linux except in Flatpak/Snap installs [1P-SSH] |
| 1Password CLI | same | U: apt repo has amd64 and arm64 [1P-REPO]; or M (`aqua:1password/cli`) | |
| SSH agent + git signing via 1Password | same | follows the app | the Linux path of `op-ssh-sign` is not given in the docs (see Gaps) |
| Ghostty | same | U: **community** `.deb` for trixie, amd64 and arm64 [GHO-DEB] | "The Ghostty project only officially distributes prebuilt binaries for macOS" [GHO] |
| VS Code + extensions + Settings Sync | same | U: Microsoft signed apt, amd64/arm64/armhf [VSC] | Settings Sync carries settings across |
| Chrome | same | U: Google signed apt; `google-chrome-stable` now in the arm64 index [CHR] | |
| Safari | **no equivalent** | n/a | Firefox or Chromium if a second engine is wanted |
| JetBrains Mono Nerd Font | same | U (Nerd Fonts release) | D `fonts-jetbrains-mono` lacks Nerd glyphs |
| Spotlight / Apps launcher | launcher (see §3) | | |
| `screencapture` | grim + slurp (+ satty) | D / U | §3 |
| Finder | Nautilus or Thunar; yazi in the terminal | D / M | |
| Dock | none, or a Waybar task list | D | Hyprland users usually launch rather than dock |
| macOS firewall, stealth | nftables | machine layer | already in `30-security.sh` |
| Touch ID for sudo | fprintd + `pam_fprintd`, **only if the SER8 has a reader** | D | otherwise **no equivalent** (see Gaps) |
| Screen lock 5 s / idle 10 min | hypridle + hyprlock | BP | |
| Auto light/dark | portal `color-scheme` (0 none, 1 dark, 2 light) [PORTAL] + hyprsunset | BP | Ghostty takes `theme = light:…,dark:…` [GHO-CFG]; VS Code auto-detects |
| iCloud Drive | **no equivalent**; Syncthing or rclone | D / U | |
| Time Machine | restic or borg (machine-layer backup is fog on the map) | D | |

### Mac keyboard habits the desktop must accommodate

1. **Cmd+C / V / X / A / Z / S / F / T / W / Q.** On Linux, apps use Ctrl and terminals use Ctrl+Shift+C/V. Three ways to keep Cmd muscle memory on Super:
   - **In the compositor (preferred fit).** Hyprland 0.55 has `send_shortcut({ mods, key, window? })` and `send_key_state(...)` dispatchers [HYP-DISP]. Omarchy binds Super+C/V/X/A this way. It checks whether the focused window is a terminal and sends Ctrl+Shift+C/V there, Ctrl+C/V elsewhere. It splits key down and up on a 50 ms timer to dodge stuck synthetic keys [OMA-CLIP]. Super+Ctrl+V opens clipboard history [OMA-CLIP]. Reference only, per the map.
   - **Below the compositor.** keyd (D 2.5.0) remaps at evdev/uinput, so it works everywhere, including a VT. Its README has a macOS-style example mapping Alt+X/C/V/A/F/R/Z to Ctrl. Its per-application mapper is experimental and lists only X, sway and GNOME, not Hyprland [KEYD].
   - **A full macOS emulation layer.** Toshy aims "to match, as closely as possible, the behavior of keyboard shortcuts in macOS" and supports Hyprland through `hyprpy`. It installs a Python venv and two systemd user services, and it is not in Debian [TOSHY]. It is heavy against the baseline.
2. **Cmd position.** On a Mac the thumb key next to the space bar is Cmd. On a PC keyboard it is Alt. XKB's `altwin:swap_lalt_lwin` ("Left Alt is swapped with Left Win") puts Super there [XKB]. Whether to use it depends on the SER8's keyboard (see Gaps).
3. **Cmd+Space → launcher, Cmd+Tab → window switch, Cmd+Q → quit, Cmd+W → close.** These become Hyprland binds. Omarchy puts its menu on Super+Space [OMA-UTIL].
4. **Layout.** U.S. International – PC maps to XKB `us` variant `intl` ("English (US, intl., with dead keys)"). The alternative `altgr-intl` puts dead keys behind AltGr [XKB]. Set them with Hyprland `kb_layout`, `kb_variant` and `kb_options` [HYP-VARS].
5. **Fast key repeat, press-and-hold off.** Hyprland `repeat_rate` (repeats/s, default 25) and `repeat_delay` (ms, default 600) [HYP-VARS]. The exact match to macOS `KeyRepeat 2` / `InitialKeyRepeat 15` is unconfirmed (see Gaps).
6. **Natural scrolling off.** This is Hyprland's default (`natural_scroll` false) [HYP-VARS].
7. **Screenshots land in `~/Downloads` without a shadow**, and the habit is a key chord, not an app. Bind grim/slurp (or satty) to keys and write to the same place.

## 3. Best tools per job on Hyprland

"Leads because" cites the project's own claims or a structural fact, not a measured comparison. No source measured quality head to head.

### Hyprland plumbing (required before anything else)

The Hyprland wiki's must-haves are: a notification daemon (dunst, mako, fnott or swaync), PipeWire with WirePlumber, xdg-desktop-portal(-hyprland), the hyprpolkitagent authentication agent, `qt5-wayland`/`qt6-wayland`, and a sans font plus a Nerd Font or FontAwesome [HYP-MUST].

| Piece | Candidates | Availability |
|---|---|---|
| Compositor | Hyprland 0.55.2 | **BP only**; forky has 0.56.2 [MAD]. Not on Bookworm [HYP-INST] |
| Session | uwsm | BP 0.26.7 |
| Lock / idle / wallpaper / picker / night light | hyprlock, hypridle, hyprpaper, hyprpicker, hyprsunset | BP |
| Portal, polkit, Qt | xdg-desktop-portal-hyprland, hyprpolkitagent, hyprland-qt-support, qt6-wayland | BP, BP, BP, D |
| Notifications | mako (D 1.10.0), swaync (D 0.11.0), dunst (D 1.12.2) | D |
| Bar | Waybar | D 0.12.0 |
| Login | greetd + tuigreet, or SDDM | D (greetd also BP) |
| Audio / BT / net UIs | pavucontrol, blueman, network-manager-applet | D |

**Config language.** Since 0.55, `~/.config/hypr/hyprland.lua` is loaded instead of `hyprland.conf` when present. "Other hypr* tools will for now continue using hyprlang" [HYP-LUA]. A config-layering design must handle Lua for Hyprland and hyprlang for hyprlock, hypridle and hyprpaper.

### Per job

| Job | Top candidates | Why they lead | Availability (D / BP / M / U) | arm64 |
|---|---|---|---|---|
| **Terminal** | **Ghostty** | already Ivan's; same config format on Linux | U community `.deb` only [GHO][GHO-DEB] | yes |
| | foot | Wayland-native and minimal | D 1.21.0 | yes |
| | kitty | GPU, mature, scriptable | D 0.41.1 | yes |
| | (WezTerm) | | U only; last release 2024-02-03 [GHREL] | |
| **Editor** | **VS Code** | already Ivan's; Settings Sync | U Microsoft apt [VSC] | yes |
| | Zed | native editor; official Linux tarballs | U tarball (the docs recommend `curl \| sh`; the baseline wants the tarball instead); no Debian package [ZED][DSRC-ZED] | yes |
| | Neovim / Helix | terminal editors | D 0.10.4 or M (neovim, helix) | yes |
| **File manager** | Nautilus | GNOME's, already used by the current repo | D 48.3 | yes |
| | Thunar | lighter | D 4.20.2 | yes |
| | yazi | terminal file manager | M (`aqua:sxyazi/yazi`); not in Debian | yes |
| **Launcher** | **Walker** | multi-purpose and highly customizable [GHREL] | U only; **release binary is x86_64 only** [GHREL] | no binary |
| | **Vicinae** | Raycast-compatible extensions; built-in clipboard history, snippets, file search, emoji, calculator [VIC] | U: arm64 AppImage, x86_64 tarball; no checksum files [GHREL] | AppImage |
| | hyprlauncher | first-party Hyprland launcher [HYP-LAUNCH] | **BP 0.1.6** | yes |
| | fuzzel | dmenu-style, Wayland-native | D 1.12.0 | yes |
| | rofi | Wayland is official only from 2.0.0 [ROFI] | D has 1.7.5 (pre-Wayland); forky 2.0.0 | |
| **Clipboard history** | **cliphist** + wl-clipboard | stores text and images; `wl-paste --watch cliphist store`, pick via fuzzel/rofi/wofi [CLIP][HYP-CLIP] | D 0.5.0, D 2.2.1 | yes |
| | (built into Vicinae or Walker) | one tool for two jobs | see Launcher | |
| **Screenshots** | **grim + slurp** | the standard capture and region pair | D | yes |
| | **satty** | annotation | U, both arches [GHREL] | yes |
| | swappy | annotation | D 1.5.1 | yes |
| | hyprshot | wrapper script | U; last release 2024-06-01 [GHREL] | |
| **Screen recording** | wf-recorder; Kooha | | D | yes |
| **Password manager** | **1Password** | already Ivan's: SSH agent, signing, CLI | U (desktop arm64 by tarball only) [1P-LINUX][1P-REPO] | partial |
| | KeePassXC | offline, in Debian | D 2.7.10 | yes |
| | pass | gpg plus git | D | yes |
| **Sync** | **Syncthing** | peer-to-peer, no cloud | D 1.29.5; U signed apt `stable-v2` with v2.1.6 [SYNC][GHREL] | yes |
| | rclone | cloud remotes | D 1.60.1 (old); absent from forky [MAD] | |
| **Backup** | **restic** | publishes `SHA256SUMS` with a `.asc` signature [GHREL] | D 0.18.0; U 0.19.1 | yes |
| | borgbackup + borgmatic | | D | yes |
| **Browser** | **Chrome** | already Ivan's | U Google apt, amd64 and arm64 [CHR] | yes |
| | Firefox | second engine | U Mozilla signed apt, amd64 and arm64 [MOZ]; D firefox-esr 140 | yes |
| | Chromium | open source | D 150 | yes |
| **Notes** | Obsidian | Markdown files on disk | U: amd64 `.deb`, arm64 AppImage/tarball [GHREL] | yes |
| | Zim / Xournal++ | in Debian | D | yes |
| **Containers** | **Docker CE** | the current repo uses it; trixie and arm64 supported; signed repo [DOCKER] | U | yes |
| | docker.io | the Debian build | D 26.1.5 (Docker's docs call distro packages unofficial) [DOCKER] | yes |
| | **Podman** + podman-compose | daemonless, rootless | D 5.4.2, D 1.3.0 | yes |
| | distrobox | other-distro shells | D 1.8.1.2 | yes |
| | lazydocker | TUI | M (`aqua:jesseduffield/lazydocker`); the repo downloads a pinned x86_64 build today | yes |
| **Git tooling** | git, gh, delta, lazygit, pre-commit, gitleaks | Ivan's current set | D (gitleaks via M) | yes |
| | difftastic | syntax-aware diff | M | yes |
| | jj (Jujutsu) | git-compatible VCS | M; forky only in Debian | yes |
| | tig, git-absorb | | D | yes |

### What a strong Linux dev setup has that this Mac lacks

| Tool | Job | Availability |
|---|---|---|
| tmux / zellij | terminal multiplexer and sessions | D 3.5a (BP 3.6b) / M |
| atuin | synced, searchable shell history | D 18.6.1 (old; forky 18.23) or M |
| direnv | per-directory env (mise also covers this) | D |
| just | task runner | D 1.40.0 |
| btop / htop | system monitor | D |
| keyd | system-wide key remapping | D 2.5.0 |
| distrobox, podman | disposable environments | D |
| osv-scanner, trivy, sops, age | dependency audit, image scan, secrets in git | M (age also D) |
| hyperfine, dust, duf, xh, glow | benchmarking, disk use, HTTP, Markdown | D |

## Gaps

- **Notes.** No notes app is installed. Whether Ivan uses Apple Notes, iCloud-based notes, or none was not established, and reading those stores was out of bounds. The Notes row is therefore a survey, not a mapping.
- **iCloud Drive use.** The folder exists, but how much is in it and what depends on it was not measured.
- **SER8 keyboard and fingerprint reader.** Whether the SER8 is used with a PC or Mac-layout keyboard decides whether `altwin:swap_lalt_lwin` is wanted. Whether a fingerprint reader is present decides whether Touch-ID-for-sudo has any equivalent. Neither was established here.
- **Key-repeat equivalence.** The conversion of macOS `KeyRepeat`/`InitialKeyRepeat` units to Hyprland's repeats/s and ms is not documented by Apple. A hands-on match is needed.
- **1Password on Linux details.** The `op-ssh-sign` path on Linux is not in 1Password's signing docs (they say the app writes it via "Edit Automatically") [1P-SSH]. Whether the arm64 tarball install supports the SSH agent and browser integration the same way as the apt install is not stated.
- **Ghostty supply chain.** The only prebuilt trixie `.deb` is community-built and publishes no checksum or signature file. GitHub's per-asset SHA-256 digest exists but only proves transport, not the publisher [GHO-DEB]. Building from source is the alternative and was not costed.
- **Walker on arm64.** No arm64 release binary. Building it, or using Vicinae or hyprlauncher in the arm64 VM, is untested. Walker also needs Elephant, a separate backend service that must be running, with its providers installed [WALKER]. That second install was not studied.
- **Vicinae integrity.** No checksum files in its releases; whether its AppImage carries an embedded signature was not checked.
- **Lua config maturity.** How many hypr* tools and third-party snippets have moved to Lua, and whether 0.55.2 in backports will track 0.56 and later, is not known. The Debian backports cadence for Hyprland was not studied.
- **`send_shortcut` reliability.** Omarchy's comment cites a Hyprland discussion about stuck synthetic keys [OMA-CLIP]. The bug's current status was not followed.
- **Mac-side AI agent configs** (`~/.claude`, `~/.codex`, `~/.pi`, `~/.copilot`) were listed by name only. Their portability is a separate question.
- **Quality comparisons.** No primary source measured launchers, terminals or clipboard tools head to head. "Leads" above rests on fit, project claims and availability.

## Sources

All queried or read on 2026-10-09.

- **[MAC]** Read-only commands on this Mac (listed under Method). Outputs are summarized, not reproduced.
- **[MS]** `iamivanhx/macos-setup` at [`f87dcc8`](https://github.com/iamivanhx/macos-setup/tree/f87dcc816f3d5cb97dd78885d0380d12cb35fece): [`config.toml`](https://github.com/iamivanhx/macos-setup/blob/f87dcc816f3d5cb97dd78885d0380d12cb35fece/config.toml), [`Brewfile`](https://github.com/iamivanhx/macos-setup/blob/f87dcc816f3d5cb97dd78885d0380d12cb35fece/Brewfile), [`steps-by-hand.md`](https://github.com/iamivanhx/macos-setup/blob/f87dcc816f3d5cb97dd78885d0380d12cb35fece/steps-by-hand.md), `dotfiles/`.
- **[MAD]** Debian QA archive index (madison), suites trixie, trixie-backports, forky: `https://qa.debian.org/madison.php?package=<names>&table=debian&s=trixie,trixie-backports,forky`.
- **[DPF]** Debian package file lists: [bat](https://packages.debian.org/trixie/amd64/bat/filelist), [fd-find](https://packages.debian.org/trixie/amd64/fd-find/filelist), [tealdeer](https://packages.debian.org/trixie/amd64/tealdeer/filelist).
- **[DSRC-YQ]** [Debian `yq` control file](https://sources.debian.org/data/main/y/yq/3.4.3-2/debian/control) (Homepage: kislyuk/yq).
- **[DSRC-ZED]** [Debian `zed` control file](https://sources.debian.org/data/main/z/zed/3.2.3-1/debian/control) (OCaml text-edition engine).
- **[MISE-REG]** `mise registry` from mise 2026.9.15; upstream registry: [jdx/mise `registry/`](https://github.com/jdx/mise/tree/main/registry). Backend verification: [mise aqua backend](https://mise.jdx.dev/dev-tools/backends/aqua.html).
- **[HYP-INST]** [Hyprland wiki: Installation](https://wiki.hypr.land/Getting-Started/Installation/) ("available as of Debian 14 (Forky) and in the Debian 13 (Trixie) backports").
- **[HYP-LUA]** [Lua-ification of Hyprland configs](https://hypr.land/news/26_lua/), 2026-04-26.
- **[HYP-MUST]** [Hyprland wiki: Must have](https://wiki.hypr.land/Useful-Utilities/Must-have/).
- **[HYP-LAUNCH]** [Hyprland wiki: App launchers](https://wiki.hypr.land/Useful-Utilities/App-Launchers/).
- **[HYP-CLIP]** [Hyprland wiki: Clipboard managers](https://wiki.hypr.land/Useful-Utilities/Clipboard-Managers/).
- **[HYP-DISP]** [Hyprland 0.55 wiki: Dispatchers](https://wiki.hypr.land/0.55.0/Configuring/Basics/Dispatchers/).
- **[HYP-VARS]** [Hyprland 0.55 wiki: Variables](https://wiki.hypr.land/0.55.0/Configuring/Basics/Variables/).
- **[OMA-CLIP]** [Omarchy `default/hypr/bindings/clipboard.lua` at `988f44e`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/default/hypr/bindings/clipboard.lua) (reference only).
- **[OMA-UTIL]** [Omarchy `default/hypr/bindings/utilities.lua` at `988f44e`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/default/hypr/bindings/utilities.lua).
- **[GHO]** [Ghostty: Prebuilt binaries](https://ghostty.org/docs/install/binary). **[GHO-CFG]** [Ghostty config reference](https://ghostty.org/docs/config/reference). **[GHO-DEB]** [mkasberg/ghostty-ubuntu 1.3.1-0-ppa2](https://github.com/mkasberg/ghostty-ubuntu/releases/tag/1.3.1-0-ppa2) (trixie amd64 and arm64 `.deb`).
- **[1P-LINUX]** [Install 1Password on Linux](https://support.1password.com/install-linux/). **[1P-REPO]** 1Password apt `Release` and `Packages` indexes under `https://downloads.1password.com/linux/debian/{amd64,arm64}/` (amd64: `1password`, `1password-cli`; arm64: `1password-cli`). **[1P-SSH]** [1Password SSH agent](https://www.1password.dev/ssh/agent/), [Sign Git commits](https://www.1password.dev/ssh/git-commit-signing).
- **[VSC]** [VS Code on Linux](https://code.visualstudio.com/docs/setup/linux).
- **[ZED]** [Zed on Linux](https://zed.dev/docs/linux).
- **[CHR]** [Google Chrome apt `Release`](https://dl.google.com/linux/chrome/deb/dists/stable/Release) (Architectures: amd64 arm64) and its `binary-arm64/Packages` (lists `google-chrome-stable`).
- **[MOZ]** [Mozilla apt `Release`](https://packages.mozilla.org/apt/dists/mozilla/Release) (Architectures: all amd64 arm64 i386).
- **[DOCKER]** [Install Docker Engine on Debian](https://docs.docker.com/engine/install/debian/).
- **[SYNC]** [Syncthing apt repository](https://apt.syncthing.net/) and its `Release` (components include `stable-v2`; amd64, arm64).
- **[GHREL]** GitHub Releases API, latest release of: [abenz1267/walker](https://github.com/abenz1267/walker/releases) v2.17.2, [vicinaehq/vicinae](https://github.com/vicinaehq/vicinae/releases) v0.29.1, [gabm/satty](https://github.com/gabm/satty/releases) v0.22.0, [Gustash/hyprshot](https://github.com/Gustash/hyprshot/releases) 1.3.0, [obsidianmd/obsidian-releases](https://github.com/obsidianmd/obsidian-releases/releases) v1.14.4, [syncthing/syncthing](https://github.com/syncthing/syncthing/releases) v2.1.6, [restic/restic](https://github.com/restic/restic/releases) v0.19.1, [wezterm/wezterm](https://github.com/wezterm/wezterm/releases) 20240203, [zed-industries/zed](https://github.com/zed-industries/zed/releases) v1.23.2.
- **[ROFI]** [rofi 2.0.0 release notes](https://github.com/davatorium/rofi/releases/tag/2.0.0) ("Wayland is now an officially supported backend").
- **[WALKER]** [Walker README](https://github.com/abenz1267/walker) (depends on Elephant).
- **[VIC]** [Vicinae README](https://github.com/vicinaehq/vicinae).
- **[CLIP]** [cliphist README](https://github.com/sentriz/cliphist).
- **[KEYD]** [keyd README](https://github.com/rvaiya/keyd).
- **[TOSHY]** [Toshy README](https://github.com/RedBearAK/toshy).
- **[XKB]** [xkeyboard-config `rules/base.xml`](https://gitlab.freedesktop.org/xkeyboard-config/xkeyboard-config/-/blob/master/rules/base.xml).
- **[PORTAL]** [xdg-desktop-portal Settings interface](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.Settings.html).
