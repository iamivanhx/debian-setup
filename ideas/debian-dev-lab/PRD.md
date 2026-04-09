# Product Requirements Document: Debian 13 Dev + Lab Automation for Beelink SER8

## 1. Problem Statement

The user has a new Beelink SER8 mini-PC that needs to become a dual-purpose **secondary development workstation** and **testing/staging platform** for containerized products they're building before production deployment. Every prior attempt to set this up (most recently, a 70 KB monolithic bash script) produced a machine that was hard to reproduce, non-idempotent, bloated with opinionated theming, and impossible to re-run without breaking things.

What the user actually needs is: **one command that converges a fresh SER8 to a known, documented, crisp, minimal state** — predictable on first install, safe to re-run any time, rollback-safe on bad updates, and disaster-recoverable via encrypted off-site backups. The system must boot to a pleasant Plasma 6 desktop, have a modern Node/Python/Go dev environment, and expose a clean platform for running ephemeral test deployments over Tailscale — all without the user ever hand-editing a config file outside the repo.

## 2. Target User

**Single primary user:** a developer who:

- Works daily in **Node.js/TypeScript**, **Python**, and **Go**.
- Uses **VS Code** as primary editor.
- Prefers **modern, minimal-sprawl tooling**: pnpm over npm/nvm, uv over pip/pyenv/poetry. One tool per concern.
- Cares about **supply-chain security** and uses Socket.dev with pnpm.
- Treats this as a **secondary** machine — a primary dev box exists elsewhere — so stability trumps bleeding-edge.
- Is the **operator** of the machine as well as its user: no separate sysadmin. Everything must be self-maintainable by one person.
- Has **working knowledge of Linux and Ansible** but is **not familiar with exotic partition schemes** (btrfs subvolumes, LUKS layouts, RAID variants). Install-time steps must be documented click-by-click.
- Has a **zero-tolerance policy for troubleshooting** on day-one hardware support. Modern hardware must Just Work on first boot.

## 3. Objective

**An afternoon after unboxing the SER8, the user has a fully configured, rollback-safe, backed-up, dual-role Linux machine that they never have to fight.**

Concretely, success means:

- First install → working state in one afternoon (manual installer pass + one playbook run).
- Re-running the playbook on a converged machine reports **zero changes**.
- Any bad update is one `snapper rollback` away from a working state.
- Any accidental data loss is one `restic restore` away from recovery.
- Adding a new test service to the lab platform is "drop a Compose file in a directory, and it's routable over Tailscale."

## 4. Proposed Solution

A **two-phase install** that cleanly separates what the Debian installer has to do from what automation can do:

1. **Phase 1 — Manual base install.** The user boots the official Debian 13 netinst USB, follows a literal click-by-click cheat sheet (screenshots + numbered steps) to lay out two LUKS-encrypted btrfs disks with subvolumes, and completes the installer. No custom ISO, no preseed, no automation. ~15 minutes of clicking, done once per machine lifetime.

2. **Phase 2 — Ansible post-install.** The user clones the playbook repo onto the fresh machine and runs `ansible-playbook -K site.yml`. A structured set of **nine role-based deep modules** (documented in §10) converges the machine to its full state: backports kernel, hardware tuning, storage subvolumes and snapper, security baseline, minimal Plasma 6, zsh + starship, dev environment, lab primitives, and three-layer backup strategy.

Every configuration file on the box that the user cares about is generated from a **Jinja2 template checked into the repo**. Nothing is heredoc'd into bash, nothing lives only on disk. "Edit the playbook, not the box" is the operational rule.

## 5. Scope

### 5.1 Hardware target
Beelink SER8: AMD Ryzen 7 8845HS (Zen 4 / Phoenix), Radeon 780M (RDNA 3 / GFX1103), 64 GB RAM, 2 × 1 TB NVMe.

### 5.2 Base OS
- **Debian 13 (Trixie)** amd64 with `trixie-backports` enabled and pinned at low priority (explicit `-t trixie-backports` required to pull from it, except for packages explicitly re-pinned high).
- **Kernel and AMD firmware** tracked from `trixie-backports`, pinned high so updates flow.
- **Mesa**: stock Trixie (not backports) — sufficient for dev workloads, avoids compositor regressions.
- **Microcode and amdgpu firmware** from `firmware-amd-graphics` and `amd64-microcode`, via backports where newer versions help the 8845HS.

### 5.3 Install strategy
- Manual Debian 13 netinst USB.
- Manual partitioning in the installer's "Manual" mode, following a click-by-click cheat sheet in the repo's `docs/install.md`.
- Ansible takes over everything after first boot.

### 5.4 Storage
Two independent LUKS-encrypted btrfs disks (split-role, **2 TB usable total**):

**NVMe1 — OS:**
- EFI system partition (1 GB, vfat)
- LUKS container → btrfs pool with subvolumes:
  - `@` → `/`
  - `@home` → `/home`
  - `@var` → `/var`
  - `@containers` → `/var/lib/docker`
  - `@snapshots` → `/.snapshots`

**NVMe2 — data + backups:**
- LUKS container → btrfs pool with subvolumes:
  - `@data` → `/srv/data`
  - `@backups` → `/srv/backups`

**Snapper on NVMe1:**
- Configs for `root` (@) and `home` (@home).
- Timeline snapshots: hourly, keep 10h / 10d / 0w / 0m.
- Pre/post snapshots: on every apt operation, keep 20.
- `.snapshots` mount at `/.snapshots`.

### 5.5 Encryption
- LUKS passphrase typed at boot, on both disks.
- NVMe2 unlocked at boot via `/etc/crypttab` entry using a keyfile stored on the (already-unlocked) NVMe1 root — so the user only types the NVMe1 passphrase once.
- No TPM2 auto-unlock in v1.

### 5.6 Desktop
Minimal KDE Plasma 6, hand-picked package list:

```
plasma-desktop, plasma-workspace, plasma-discover,
sddm, sddm-theme-breeze,
konsole, dolphin, kate, ark, gwenview, okular,
plasma-nm, plasma-pa, kscreen, bluedevil, powerdevil,
kwalletmanager, kde-cli-tools, xdg-desktop-portal-kde,
breeze-gtk-theme, qt6-wayland, plasma-firewall,
fonts-noto, fonts-noto-color-emoji, fonts-jetbrains-mono
```

Plus **JetBrainsMono Nerd Font** patched variant installed to `/usr/local/share/fonts/JetBrainsMonoNerdFont/` from the upstream tarball.

**Flatpak + Flathub remote** enabled via Ansible, but **no Flatpaks installed by default**. Plasma Discover surfaces both apt and Flatpak sources.

**Breeze Dark** as default theme. No custom theming layer.

### 5.7 Shell
- **zsh** as the user's default shell (`chsh`).
- Hand-written `~/.zshrc` as a Jinja2 template. No frameworks, no plugin managers.
- apt packages only: `zsh-autosuggestions`, `zsh-syntax-highlighting`, sourced directly in the rc file.
- **starship** prompt via the official install script run by Ansible, with a small hand-written `~/.config/starship.toml`.

### 5.8 Dev environment
- **VS Code** via Microsoft's apt repo (gpg key + `/etc/apt/sources.list.d/vscode.list`).
- **pnpm** via official install script. pnpm is configured to manage Node.js itself via `pnpm env use --global lts`. **apt `nodejs` and `npm` are blacklisted** (explicit `apt-mark hold` + a `base` role assertion that fails loudly if they appear).
- **Python via uv** — installed via the official `uv` install script. `uv` handles both Python versions and package envs. No system `python3-pip`, `python3-venv`, `pyenv`, `poetry`.
- **Go** via `apt install -t trixie-backports golang-go` — closer to upstream than Trixie stable, still managed via apt.
- **git**, **build-essential**, **make**, **jq**, **curl**, **wget**, **htop**, **ripgrep**, **fd-find**, **bat**, **tree**, **unzip** as core CLI tools.

### 5.9 Home lab / testing platform
**Primitives only; no preset apps.**

- **Docker CE + docker-compose-plugin** via docker.com's apt repo.
- **Traefik** (v3) running as a Docker container, auto-discovering services via Docker labels. Fixed entrypoints `web` (:80) and `websecure` (:443). Internal-only TLS via Tailscale's `tsnet` or a local-only CA in v1 (decided in §10).
- **Tailscale** via tailscale.com's apt repo, authenticated once manually or via an auth key file referenced from Ansible.
- **Scratch convention:** `/srv/data/lab/` on NVMe2, with subdirs `compose/`, `volumes/`, `secrets/`. Each test service gets its own `compose/<service>/` folder containing a `docker-compose.yml` and a README, following a single-file-per-service convention.

### 5.10 Backup strategy — three layers

**Layer A — local same-disk (snapper):**
- Pre/post apt snapshots on `@` and `@home`, keep 20.
- Timeline hourly on `@home`, keep 10 hourly / 10 daily.

**Layer B — local cross-disk (btrfs send):**
- A systemd timer fires nightly at 02:00.
- Creates a read-only snapshot of `@` and `@home` on NVMe1.
- `btrfs send --parent` incrementally streams them to `@backups` on NVMe2.
- Retention: keep last 14 daily incrementals, pruned by a companion timer.

**Layer C — off-site (restic → Dropbox):**
- **restic** + **rclone** (with a `dropbox:` remote configured from `~/.config/rclone/rclone.conf`, templated by Ansible with an encrypted secret pulled from a vaulted variable).
- Repository path: `dropbox:restic-beelink-ser8/`.
- **Client-side encrypted** by restic — Dropbox never sees plaintext.
- Nightly systemd timer at 03:00 backs up:
  - `/home/<user>` — including `.ssh`, `.gnupg`, `.config`, dev project sources
  - `/etc` — any manual drift the user wants captured
- Excludes: `~/.cache`, `node_modules`, `__pycache__`, `.venv`, `target/`, `build/`, `dist/`, `/var/cache`, `/var/tmp`, `/tmp`, `/srv/data/lab`, `/var/lib/docker`, `/srv/backups`
- Retention policy (enforced by `restic forget --prune`): **keep last 7 daily, 4 weekly, 6 monthly.**

**Dropbox desktop sync client** installed as a separate concern, for live Dropbox folder access at `~/Dropbox`. Flagged as a **smoke-test item** — see §12.

### 5.11 Security baseline
- **Firewall:** nftables via `/etc/nftables.conf` (Jinja2 template). Deny all inbound by default. Allow loopback, established/related, and all traffic on `tailscale0`. `plasma-firewall` is present as a GUI but the file is the source of truth.
- **SSH:** `sshd_config` template. `ListenAddress` bound to the Tailscale IP (fetched via an Ansible fact from `tailscale ip -4`). `PasswordAuthentication no`, `PermitRootLogin no`, `PubkeyAuthentication yes`. Authorized keys deployed via a variable list.
- **No fail2ban.** Tailscale is the perimeter.
- **unattended-upgrades:** configured to apply only `Debian-Security` and `Debian trixie-security` origins. Kernel and regular upgrades remain manual.
- **APT::Periodic** enabled: `Update-Package-Lists "1"`, `Download-Upgradeable-Packages "1"`, `AutocleanInterval "7"`, `Unattended-Upgrade "1"`.
- **sudo:** password-prompted, no NOPASSWD. User in `sudo` group.

### 5.12 Automation tool
Ansible, localhost, role-based, **9 roles** (see §10). Re-runnable, idempotent, all configs as Jinja2 templates.

### 5.13 Repo layout (for the playbook)
```
linux-setup/
├─ ideas/debian-dev-lab/       # PRD + input (this document)
├─ docs/
│  └─ install.md               # click-by-click manual installer cheat sheet
├─ ansible/
│  ├─ site.yml
│  ├─ inventory/localhost.yml
│  ├─ group_vars/all.yml       # tunable variables
│  ├─ host_vars/beelink.yml    # machine-specific (SSH keys, hostname, etc.)
│  └─ roles/
│     ├─ base/
│     ├─ hardware/
│     ├─ storage/
│     ├─ security/
│     ├─ desktop/
│     ├─ shell/
│     ├─ dev/
│     ├─ lab/
│     └─ backup/
└─ README.md
```

## 6. Non-goals

All non-goals from the PRD Input carry forward unchanged and are restated here for traceability:

- **No Hyprland / tiling WM in v1.** Parked. Conflicts with "no troubleshooting".
- **No GNOME.** Plasma 6 only.
- **No opinionated theming** — no Gruvbox, Catppuccin, Dracula, Yaru. Stock Breeze Dark.
- **No oh-my-zsh or zsh plugin manager.** Framework-free.
- **No preset self-hosted apps** (Nextcloud, Immich, Vaultwarden, Home Assistant, Jellyfin). Lab ships primitives only.
- **No k3s / Kubernetes in v1.**
- **No preseed / custom ISO in v1.** Manual install is fine for a single machine.
- **No TPM2 auto-unlock in v1.** Passphrase only.
- **No fail2ban.**
- **No RAID1 mirror.** Split-role + Dropbox is the redundancy model.
- **No mdadm, no LVM.** Pure btrfs on LUKS.
- **No chezmoi for dotfiles in v1.** Ansible templates.
- **No distrobox / devcontainers in v1.** Host tools only.
- **No cloud config management** (Salt/Chef/Puppet).
- **No VM hypervisor** (Proxmox, libvirt).
- **No bundled desktop extras** (LibreOffice, GIMP, VLC, Firefox, Thunderbird) installed by default. Flatpak is the path.
- **No apt `nodejs` / `npm`.** Explicitly blacklisted to protect pnpm-managed Node in PATH.

## 7. Constraints

- **Hardware:** Beelink SER8 (Ryzen 7 8845HS, Radeon 780M, 64 GB RAM, 2×1 TB NVMe). Kernel 6.6+ required for full 8845HS support; Debian 13 backports (6.12+) satisfies this with margin.
- **No troubleshooting** — hardware must work first boot. Any fragile layer must be optional or deferred.
- **Minimal footprint** — no bundled extras.
- **Config is in the repo or it doesn't exist** — no inline heredocs, no manual on-box edits as the canonical state.
- **User is not familiar with exotic partition schemes** — install-time steps must be GUI-achievable and click-by-click documented.
- **Dropbox is the off-site destination** (~2–3 TB Plus tier available). restic + rclone Dropbox backend satisfies this.
- **Client-side encryption for off-site backups is mandatory** — Dropbox must never see plaintext.
- **Tailscale is the remote-access perimeter** — no public SSH, no public service exposure.
- **Single-user, single-machine** — Ansible runs against localhost, no inventory beyond that.

## 8. User Stories

### 8.1 Core flows

1. As a **developer**, I want to run `ansible-playbook -K site.yml` on a freshly installed Debian 13 box and get a fully configured machine, so that I don't have to remember dozens of manual post-install steps.
2. As a **developer**, I want the playbook to be safe to re-run at any time, so that I can bump a variable (e.g., Go version) and reconverge without fear of breaking state.
3. As a **developer**, I want `ansible-playbook --check --diff site.yml` on a converged machine to report zero changes, so that idempotency is observable.
4. As a **developer**, I want all tunable knobs (hostname, SSH keys, timezone, Go version, restic retention, etc.) to live in `group_vars/all.yml` or `host_vars/beelink.yml`, so that customizing the playbook for a different box is a one-file edit.
5. As a **developer**, I want to open a fresh terminal after installation and have `node`, `python`, `go`, `git`, `uv`, `pnpm`, `docker`, `code` all available in PATH with modern versions, so that I can start working immediately.
6. As a **developer**, I want the dev environment to use pnpm for Node (not npm), uv for Python (not pip/pyenv), and my preferred editor (VS Code) wired up, so that day-one feels like my normal workflow.
7. As a **developer**, I want to drop a `docker-compose.yml` into `/srv/data/lab/compose/<service>/` and have the service automatically routable through Traefik at a predictable hostname, so that testing a new product deployment takes zero platform configuration.
8. As a **developer**, I want every test service reachable from my laptop and phone over Tailscale without port-forwarding or public DNS, so that I can validate deployments from anywhere without exposing the box to the internet.

### 8.2 Setup / onboarding

9. As a **first-time installer**, I want a literal click-by-click cheat sheet (with screenshots if possible) for the Debian installer's manual partitioning step, so that I don't misconfigure LUKS or btrfs subvolumes.
10. As a **first-time installer**, I want the cheat sheet to cover both NVMes in one unambiguous sequence (EFI on NVMe1, LUKS on both, btrfs with named subvolumes), so that I don't have to interpret partitioning advice mid-install.
11. As a **first-time installer**, I want a README section that tells me exactly which git command to run to clone the playbook and which command to run to execute it, so that the post-install handoff is obvious.
12. As a **first-time installer**, I want the playbook to prompt me (via `-K` / vars_prompt) for the things it genuinely cannot know (sudo password, Tailscale auth key path, rclone Dropbox token), so that secrets aren't hard-coded.
13. As an **operator**, I want to be able to rehearse the full install in a VM before touching the real SER8, so that I can catch cheat-sheet mistakes without burning the real machine.

### 8.3 Day-to-day operations

14. As an **operator**, I want pre/post apt snapshots taken automatically, so that any bad apt upgrade is a `snapper rollback` away from a working state.
15. As an **operator**, I want nightly snapshots of `/` and `/home` streamed to NVMe2 via `btrfs send`, so that an NVMe1 failure doesn't lose my last 24 hours of work.
16. As an **operator**, I want nightly restic backups pushed to Dropbox with client-side encryption, so that a house-fire scenario still recovers my work.
17. As an **operator**, I want the three backup layers to run independently — one layer failing must not break the others, and each must log visibly to `journalctl -u <timer>`.
18. As a **developer**, I want to accidentally `rm -rf ~/important-project` and recover it from the local NVMe2 backup within seconds or from restic within minutes, so that data loss is impossible in practice.
19. As an **operator**, I want `snapper rollback` to be a single documented command and to leave the machine bootable, so that rollback isn't itself a risky operation.
20. As an **operator**, I want to update my authorized SSH keys by editing a variable list in `host_vars/beelink.yml` and re-running the playbook, so that key rotation is version-controlled.

### 8.4 Error and edge cases

21. As an **operator**, I want the playbook to fail loudly (not silently skip) if the box is not Debian 13 Trixie, so that I can't accidentally run it on the wrong OS.
22. As an **operator**, I want the playbook to fail loudly if apt `nodejs` or `npm` are present, so that pnpm-managed Node isn't silently shadowed in PATH.
23. As an **operator**, I want the nftables ruleset to be applied atomically on re-run, so that a mid-playbook interruption doesn't leave me firewalled out from Tailscale.
24. As an **operator**, I want the Dropbox desktop client to be marked optional, so that if it doesn't play nicely with encrypted btrfs I can disable it with a single variable flip without losing the restic backup layer.
25. As an **operator**, I want the SSH `ListenAddress` to fall back gracefully if Tailscale is not yet installed/up on the first playbook run, so that I don't lock myself out mid-install. (Concretely: SSH listens on `127.0.0.1` until Tailscale is confirmed up.)
26. As an **operator**, I want the backports kernel to always have the *previous* kernel installed alongside it, so that GRUB offers a fallback if the new kernel panics.
27. As an **operator**, I want a documented "Tailscale is down, how do I SSH in from the LAN temporarily" recovery procedure, so that a Tailscale outage doesn't mean I have to unplug a monitor and keyboard.

### 8.5 Maintenance and evolution

28. As an **operator**, I want bumping `go_version` in vars and re-running the playbook to upgrade Go cleanly, so that toolchain version management is code.
29. As an **operator**, I want adding a new apt package to the `dev` role's extras list to be a one-line variable edit, so that installing a new CLI tool doesn't require touching the role itself.
30. As an **operator**, I want to confirm that every on-box config file that matters is traceable to a template in the repo, so that drift is detectable.
31. As an **operator**, I want `ansible-playbook --check --diff` to surface any drift as a diff, so that drift detection is a single command.

## 9. Acceptance Criteria

### For Story 1 & 2 — playbook runs and re-runs cleanly
- **Given** a fresh Debian 13 install and a cloned playbook repo, **when** the user runs `ansible-playbook -K site.yml`, **then** the playbook completes with zero failures.
- **Given** a converged machine, **when** the playbook is re-run, **then** all tasks report `ok` or `changed=0` except for idempotent diagnostic tasks explicitly marked `changed_when: false`.

### For Story 3 — idempotency observable
- `ansible-playbook --check --diff site.yml` on a converged machine exits 0 with zero `changed` tasks.

### For Story 5 & 6 — dev environment functional
- `node --version`, `pnpm --version`, `python --version`, `uv --version`, `go version`, `git --version`, `docker --version`, `code --version` all succeed in a fresh shell after first login.
- `which node` resolves to a path under pnpm's env (`~/.local/share/pnpm/...`), not `/usr/bin/node`.
- `which python` resolves to uv's managed Python, not `/usr/bin/python3`.

### For Story 7 & 8 — lab platform round-trip
- **Given** a valid `docker-compose.yml` with Traefik labels dropped in `/srv/data/lab/compose/whoami/`, **when** the user runs `docker compose up -d` from that directory, **then** `curl http://whoami.lab.<tailscale-domain>` from another Tailscale-connected device returns the whoami response.
- **Given** the SER8 is offline from its LAN but reachable via Tailscale, **when** a test service is running in the lab compose scaffold, **then** it is still reachable from the user's Tailscale-connected laptop.

### For Story 9 & 10 — install cheat sheet
- `docs/install.md` exists in the repo, enumerates every installer screen, and unambiguously specifies partition sizes, LUKS labels, btrfs subvolume names, and mount points.
- A clean-room test: a user following only `docs/install.md` (without this PRD) can complete the installer and arrive at a bootable Debian 13 base system.

### For Story 14 — snapper rollback
- **Given** `snapper` is configured on `@`, **when** the user runs `apt upgrade`, **then** pre and post snapshots appear in `snapper list -c root`.
- **Given** a pre-upgrade snapshot exists, **when** the user runs the documented rollback procedure, **then** the machine boots from the rolled-back state on next reboot.

### For Story 15 — btrfs send local backup
- **Given** the nightly `btrfs-send` timer has run at least once, **when** the user inspects `/srv/backups/`, **then** read-only snapshots of `@` and `@home` are present with timestamped names.
- **Given** a file was present at 02:00, **when** it is deleted from `/home` after 02:00, **then** it can be retrieved from the latest `/srv/backups/home-<timestamp>/` snapshot.

### For Story 16 — restic off-site
- **Given** rclone Dropbox auth is valid, **when** the nightly restic timer fires, **then** `restic -r rclone:dropbox:restic-beelink-ser8/ snapshots` lists a new snapshot dated today.
- restic repository has been initialized with a known passphrase stored in the vaulted Ansible variable.
- `restic -r rclone:dropbox:... restore latest --target /tmp/restore --include /home/<user>/.zshrc` recovers the file successfully.

### For Story 18 — file recovery
- **Given** `~/testfile` was present and nightly backups have run, **when** the user deletes `~/testfile` and runs the documented restore procedure against the local btrfs backup, **then** the file is recovered within 30 seconds.
- Same, against restic to Dropbox, within 5 minutes.

### For Story 21 — OS gate
- Running the playbook on a non-Trixie target fails at the pre-flight stage with a clear error message naming the detected distro.

### For Story 22 — Node PATH gate
- **Given** `apt install nodejs` has been run manually, **when** the playbook runs, **then** it fails with a clear error telling the user to `apt purge nodejs npm` and re-run.

### For Story 25 — SSH lockout avoidance
- On the first playbook run against a machine without Tailscale, the SSH `ListenAddress` defaults to `127.0.0.1` only. After the Tailscale role confirms `tailscaled` is up and `tailscale ip -4` returns an address, the SSH role rebinds to that address. A mid-run failure before the Tailscale role must never leave SSH unreachable on the Tailscale interface *and* the LAN interface — if Tailscale isn't up, SSH stays loopback-only.

### For Story 26 — kernel fallback
- After a kernel upgrade, `ls /boot/vmlinuz-*` shows at least two kernels, and `grub-mkconfig` generates a submenu offering both.

### For Story 30 — drift traceability
- A script or documented procedure lists every config file referenced by the playbook alongside its source template, producing a pass/fail drift report.

## 10. Implementation Decisions

### 10.1 Architecture

The system is a **single Ansible playbook** (`site.yml`) that includes nine roles in dependency order. Each role is a **deep module**: narrow variable interface, hides substantial complexity, independently re-runnable, idempotent.

Roles and their dependency ordering:

| # | Role | Depends on | Encapsulates |
|---|---|---|---|
| 1 | `base` | — | APT sources incl. backports + pinning, locale/timezone, core CLI packages, OS gate (fails on non-Trixie), apt-hold on `nodejs`/`npm` |
| 2 | `hardware` | `base` | amdgpu firmware (backports), microcode, NVMe scheduler, power-profiles-daemon, fwupd, backports kernel pin |
| 3 | `storage` | `base` | NVMe2 LUKS+btrfs+subvol creation, fstab entries for all subvols, snapper configs for root+home, nightly `btrfs send` systemd timer + prune timer |
| 4 | `security` | `base`, `storage` | nftables ruleset template, SSH hardening with staged `ListenAddress` (loopback-then-tailnet), unattended-upgrades security-only |
| 5 | `desktop` | `base`, `hardware` | Minimal Plasma 6 package list (§5.6), SDDM, fonts (Noto, JetBrainsMono, JetBrainsMono Nerd Font tarball), Flatpak + Flathub remote, Breeze Dark default |
| 6 | `shell` | `base` | zsh + starship + apt plugins + `~/.zshrc` and `starship.toml` templates + `chsh` |
| 7 | `dev` | `base` | VS Code apt repo + install, pnpm install + `pnpm env use --global lts`, uv install, Go from backports, git/build-essential/CLI tools, fails if apt `nodejs`/`npm` present |
| 8 | `lab` | `base`, `storage`, `security` | Docker CE + Compose plugin apt repo, Traefik Compose file and systemd drop-in, Tailscale apt repo + install, `/srv/data/lab/{compose,volumes,secrets}/` scaffold with README |
| 9 | `backup` | `base`, `storage`, `lab` (for Docker exclusion) | restic install, rclone install + templated `rclone.conf` with vaulted Dropbox token, Dropbox desktop client (behind a `install_dropbox_client` var), nightly restic systemd timer, retention policy via `restic forget --prune` |

### 10.2 Deep-module analysis

**`storage`** is the deepest module. It hides:
- LUKS container creation and `/etc/crypttab` entry for NVMe2 (with a keyfile on NVMe1 so the user types one passphrase, not two).
- btrfs multi-subvolume creation on NVMe2 matching the NVMe1 layout convention.
- Whole-disk fstab population (the installer's auto-generated fstab is replaced by a template).
- Snapper configs with tuned retention.
- The nightly btrfs-send timer and a companion prune timer — both as templated systemd units.

Its interface is small: `nvme2_device`, a handful of retention vars, and done. Everything else is internal.

**`backup`** is the second-deepest. It hides:
- restic repository initialization (with a vaulted passphrase).
- rclone `dropbox:` remote configuration with an Ansible-vaulted token.
- A nightly backup systemd timer and service unit.
- Retention enforcement via a separate `restic forget --prune` invocation.
- Optional Dropbox desktop client install behind a feature flag.

Its interface: `dropbox_remote_path`, `restic_retention_keep_*`, `backup_include_paths`, `backup_exclude_paths`, `install_dropbox_client`.

**`security`** is deep because it hides the non-obvious SSH `ListenAddress` staging logic — a piece of real cleverness the user shouldn't have to think about. Its interface is `ssh_authorized_keys`, `nftables_allow_lan_ssh` (default false).

**`hardware`** hides a dozen small tuning concerns (microcode, firmware, NVMe scheduler, fwupd enablement, power profile) behind a single variable `power_profile` (default `balanced`).

**`dev`** is shallower but holds non-trivial invariants: it must verify `apt nodejs` is absent and fail loudly if not. It also must ensure pnpm-managed Node is on PATH *before* VS Code launches for the first time, so VS Code's integrated terminal picks it up.

### 10.3 Interfaces between modules

Roles communicate only via **Ansible variables**, never via shared state files. `group_vars/all.yml` holds defaults; `host_vars/beelink.yml` holds machine-specific overrides; vaulted secrets live in `group_vars/all/vault.yml`.

Role dependencies are declared in each role's `meta/main.yml`. Ansible resolves the order.

No role writes to another role's files. No role reads another role's templates. If two roles need to share a template (e.g., the nftables config needing the Tailscale interface name), the shared value is defined as a fact or a group variable.

### 10.4 Secrets handling

`ansible-vault` encrypts:
- Dropbox rclone token
- restic repository passphrase
- Tailscale auth key (if pre-authed rather than manual `tailscale up`)

The vault password itself is not in the repo. First-run UX: `ansible-playbook --ask-vault-pass -K site.yml`. Alternative: a `~/.vault_pass` file referenced by `ansible.cfg`, outside the repo.

### 10.5 Trade-offs made

- **No molecule / no CI tests.** The test matrix for a single personal machine doesn't justify the CI overhead. Instead: `--check --diff` plus manual smoke tests (see §11) plus a pre-SER8 VM rehearsal.
- **No role versioning / ansible-galaxy.** Roles live in-tree. Simpler to reason about, no version drift, no dependency hell.
- **No dynamic inventory.** One machine, static inventory file, localhost connection.
- **Single-file `site.yml`** instead of many play files. Easier to see the role order at a glance.
- **Config source of truth is templates, not on-box files.** The loss is: no one-off sysadmin edits. The gain is: total reproducibility.

## 11. Testing Decisions

### 11.1 What gets tested, how

- **Idempotency:** `ansible-playbook --check --diff site.yml` on a converged machine must report zero `changed`. Run manually after every meaningful playbook edit.
- **Syntax:** `ansible-playbook --syntax-check site.yml` as a pre-commit gate (or at minimum a CI step if a CI runner is added later).
- **Linting:** `ansible-lint` on all roles with default rules. Warnings reviewed; errors blocking.
- **Pre-flight gates:** the `base` role has assertions that fail the playbook loudly on (a) non-Trixie distro, (b) apt `nodejs` or `npm` present, (c) missing critical vars (`ssh_authorized_keys`, `nvme2_device`). These are tests that run on every playbook invocation.
- **Smoke tests:** a `scripts/smoke-test.sh` script in the repo runs a battery of checks after first install:
  - `node --version`, `pnpm --version`, `uv --version`, `python --version`, `go version`, `docker --version`
  - `systemctl is-active snapper-timeline.timer snapper-cleanup.timer btrfs-send.timer restic-backup.timer`
  - `snapper list -c root` returns at least one snapshot
  - `restic -r "$REPO" snapshots` lists at least one snapshot
  - `tailscale status` shows the node online
  - `nft list ruleset` includes the expected chains
  - `ss -tlnp` shows sshd bound only to loopback or the Tailscale IP, never to LAN
- **VM rehearsal:** before touching the real SER8, the user rehearses the full install in a QEMU/KVM VM sized to mimic 2×1 TB disks and completes the same install.md cheat sheet. This catches partitioning bugs on throwaway hardware.

### 11.2 What does NOT get tested
- Per-role unit tests via molecule. Overkill for a one-machine project.
- Integration tests against a matrix of hosts. One host.
- Continuous integration against a real VM. Cost/benefit doesn't land for a personal project.

### 11.3 What makes a good test here
Tests observe **externally visible state**: "is this timer active?", "does this command produce output?", "does this port listen here?" — not Ansible module internals or specific task ordering. The smoke test script is the closest thing to an integration test and is intentionally shell-based (not a framework) so it's readable and runnable on any machine without deps.

## 12. Risk Mitigations

**Risk 1 — Dropbox Linux client + encrypted btrfs compatibility.**
*Mitigation:* Dropbox desktop client install is behind a feature flag `install_dropbox_client` (default `true` but documented as a smoke-test item). A **Phase 2a smoke test** runs the Dropbox client for 24 hours on encrypted btrfs before declaring v1 stable. If it fails, flip the flag to `false` in `host_vars/beelink.yml`, lose live folder sync, keep restic-only off-site backup. The restic backup is unaffected either way — it uses rclone directly, not the Dropbox client.

**Risk 2 — Snapper + backports kernel interaction.**
*Mitigation:* The `storage` role configures snapper to take snapshots on every apt transaction via `/etc/apt/apt.conf.d/80snapper`. An acceptance check (§9, Story 14) verifies snapshots exist after an apt operation. Additionally, the `hardware` role ensures the previous kernel is kept (`apt::keep-old-kernels`) and verifies GRUB shows both entries. Manual rollback procedure documented in `docs/rollback.md`.

**Risk 3 — Manual partitioning human error.**
*Mitigation:* (a) `docs/install.md` is a literal click-by-click cheat sheet — not prose, not "do X or Y", but a single unambiguous sequence with screenshots. (b) The user rehearses the full install in a VM before touching the SER8 (Story 13). (c) The `storage` Ansible role asserts that the expected subvolumes exist on first run and fails loudly with "your install.md layout doesn't match — re-check partition scheme" if anything is wrong.

**Risk 4 — Scope creep in the lab role.**
*Mitigation:* Explicit non-goals in §6 list every self-hosted app by name. Any new service request is a separate issue, not a v1 change. The `lab` role installs **zero** application containers — only Traefik, Tailscale, Docker, and the directory scaffold.

**Risk 5 — Configs drifting out of Ansible.**
*Mitigation:* (a) The README prominently states "edit the playbook, not the box" as the single operational rule. (b) Story 30/31 provides a drift-detection command: `ansible-playbook --check --diff site.yml`. (c) A doc section lists every config file under playbook control, for periodic human review.

**Risk 6 — Backports kernel pin breaking (unavailable or broken).**
*Mitigation:* `hardware` role keeps the previous kernel around. `grub-mkconfig` is re-run after kernel installs. GRUB fallback path documented. If backports is temporarily unreachable, APT falls through to the previous kernel (pinned, still installed) and the machine remains bootable.

**Risk 7 — pnpm-managed Node vs system Node shadowing.**
*Mitigation:* The `base` role asserts apt `nodejs` and `npm` are absent, and applies `apt-mark hold` to both. The `dev` role adds `~/.local/share/pnpm` to PATH early in the user's `~/.zshrc` template, before any system PATH entries that might contain a stray Node binary. A smoke-test assertion checks `which node` points into pnpm's env.

**Risk 8 — Tailscale outage locking the operator out of SSH.**
*Mitigation:* (a) The SSH role defaults `nftables_allow_lan_ssh` to `false` but the variable exists as a documented emergency toggle. (b) Local-console recovery documented in `docs/recovery.md`: boot normally (LUKS passphrase), log in at the Plasma greeter, open a terminal, flip the variable, re-run the playbook locally. (c) Reminder: `sudo systemctl restart tailscaled` and `sudo tailscale up` from local console solves most transient Tailscale issues without needing the playbook at all.

## 13. Open Questions

All questions here are **genuinely deferred** — decisions that cannot be made now without information the user does not yet have. Most questions from the PRD Input were resolved during grilling (§3).

1. **Which self-hosted apps (if any) become preset in v2.** Can only be resolved when the user has a concrete need (e.g., "I want Vaultwarden"). Until then, the `lab/compose/<service>/` convention covers ad-hoc additions without a role change.
2. **k3s as a toggleable role.** Only relevant when a product under test actually requires Kubernetes. No current trigger.
3. **Preseed automation.** Worth the investment only if the user adds a second machine or reinstalls the SER8 more than once every few years. Neither is true today.
4. **TPM2 auto-unlock via `systemd-cryptenroll`.** Only relevant if the user decides the home-lab role needs unattended reboots. Not currently a requirement.
5. **chezmoi split for dotfiles.** Only worth adopting if the Ansible template approach demonstrably becomes unwieldy. Revisit after 6 months of use.
6. **distrobox / devcontainers.** Only worth adopting if the user hits toolchain-conflict pain that host-level tooling can't resolve. Not yet a problem.
7. **Restic retention tuning based on observed growth.** Default 7 daily / 4 weekly / 6 monthly assumes ~5-20 GB of backed-up data and fits comfortably in a Dropbox Plus plan. Needs observation over the first month to confirm.

## 14. Success Metrics

Measurable post-launch checks:

1. **Time-to-working-box:** ≤ 4 hours from booting the install USB to a green smoke test. Measured once, manually.
2. **Idempotency:** `ansible-playbook --check --diff site.yml` reports 0 changed tasks on a converged machine. Verified weekly.
3. **Rollback works:** manual test — force a "bad upgrade" and roll it back via snapper successfully. Verified once at v1 acceptance, then quarterly.
4. **Backup round-trip (local):** delete a test file, restore from `/srv/backups` btrfs-send snapshot within 30 seconds. Verified at v1 acceptance, then monthly.
5. **Backup round-trip (off-site):** delete a test file, restore from restic Dropbox repo within 5 minutes. Verified at v1 acceptance, then monthly.
6. **Disaster recovery:** wipe NVMe1 in a VM clone, reinstall, re-run playbook, restore `/home` from restic → working state. Verified once per year.
7. **Test-service round-trip:** drop a whoami Compose file into the lab scaffold, reach it from a Tailscale-connected device. Verified at v1 acceptance.
8. **Drift detection:** zero on-box config files diverge from their playbook templates. Verified monthly via `--check --diff`.
9. **Dropbox client stability on encrypted btrfs** (Risk 1 smoke test): Dropbox client runs 24 hours without errors or sync loops. Verified once during v1 acceptance. If it fails, `install_dropbox_client` flipped to `false` permanently.

## 15. References

- **PRD Input:** [`ideas/debian-dev-lab/prd-input.md`](./prd-input.md)
- **Prior art (discarded):** `beelink_debian_post_install.sh` in the separate `debian-setup` repo — salvage nothing, reference only as a list of things NOT to do.
- **Hardware docs:** AMD Ryzen 7 8845HS datasheet, Beelink SER8 specs.
- **Tool docs to verify during implementation via `context7`:**
  - Debian 13 Trixie release notes, backports policy
  - KDE Plasma 6 minimal install guidance
  - btrfs subvolume + snapper integration patterns
  - restic + rclone Dropbox backend
  - Traefik v3 Docker provider
  - Tailscale Debian install + Ansible module
  - pnpm `env use` workflow, Socket.dev pnpm plugin
  - uv self-management
