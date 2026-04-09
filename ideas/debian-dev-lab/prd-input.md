# PRD Input: Debian 13 Dev + Lab Automation for Beelink SER8

## Context

Standalone greenfield project. Goal: a reproducible, idempotent Ansible-based automation that turns a fresh Beelink SER8 into a dual-purpose machine — **secondary dev workstation** and **testing/staging platform** for products the user is building before they hit production.

A prior monolithic bash script (`beelink_debian_post_install.sh`) exists in a separate repo but is explicitly being discarded as a clean-slate reboot. Nothing is salvaged from it.

## Problem Statement

The user wants to set up a new Linux machine that must be:

1. **Usable immediately** — "no troubleshooting" is a hard constraint. Modern hardware must Just Work.
2. **Reproducible** — if the machine is reinstalled (or a second one is added), the exact same state can be reached without memory or guesswork.
3. **Idempotent** — re-running the automation must converge to the desired state without breaking anything.
4. **Minimal** — no opinionated app bundles, no theming layers, no framework bloat. Only what is actually used.
5. **Dual-role** — simultaneously a pleasant dev workstation AND a testing/staging platform for containerized products the user is building.

The existing script fails on 1, 2, and 4: it's a 70 KB monolithic bash file, not idempotent, and bundles opinionated terminal/desktop theming (zsh + oh-my-zsh + starship + Gruvbox + Yaru + Dash-to-Dock) the user does not want.

## Target User

**Primary user:** a developer who works in Node.js/TypeScript, Python, and Go daily, uses VS Code as their primary editor, cares about supply-chain security (Socket.dev), and prefers modern minimal-sprawl tooling (pnpm over npm/nvm, uv over pip/pyenv/poetry). This is their **secondary** machine — a primary dev machine exists elsewhere — so stability over bleeding-edge, but still modern enough to run current toolchains.

The user has working knowledge of Linux and Ansible but is **not familiar with exotic partition schemes** (btrfs subvolumes, LUKS-on-LVM, RAID layouts), so install-time steps must be documented as a literal click-by-click cheat sheet.

## Proposed Solution

An **Ansible playbook run locally** against the freshly installed machine, after a one-time **manual Debian 13 netinst** walk-through. The playbook is structured into roles per concern, each idempotent and independently re-runnable:

- `base` — apt sources, backports pinning, core packages, timezone, locale
- `hardware` — Ryzen 7 8845HS / Radeon 780M tuning (amdgpu, firmware, microcode, NVMe scheduler, power management)
- `storage` — btrfs subvolume mounts, NVMe2 mount, snapper config, nightly `btrfs send` systemd timer
- `desktop` — minimal KDE Plasma 6, Konsole, JetBrainsMono Nerd Font, Breeze Dark defaults (no theming layer)
- `shell` — zsh (framework-free), starship, apt plugins, `~/.zshrc` Jinja2 template
- `dev` — VS Code (Microsoft apt repo), pnpm, uv, Go, git, build tools
- `lab` — Docker CE + Compose, Traefik, Tailscale, `/srv/data/lab/` scratch convention
- `backup` — restic + rclone, Dropbox desktop client, systemd timers
- `security` — nftables deny-all-inbound baseline with `tailscale0` open, SSH hardening, unattended-upgrades (security-only)

All configuration files live as **Jinja2 templates in the repo** — never heredoc'd into bash. Dotfiles are deployed by Ansible templates in v1; a chezmoi split is deferred until the template approach proves unwieldy.

## Core Value Proposition

One command (`ansible-playbook site.yml`) converges the machine to a known, documented, idempotent state — anywhere in its lifecycle. No mystery configs, no terminal bloat, no "what did I click in the installer two years ago" amnesia. A bad update is a `snapper rollback` away. A dead disk is a restic restore away. A fresh SER8 is an afternoon away from being fully operational.

## Scope

### Hardware
- Beelink SER8: Ryzen 7 8845HS, Radeon 780M, 64 GB RAM, 2×1 TB NVMe.

### Base OS
- Debian 13 (Trixie), amd64, with `trixie-backports` enabled.
- Kernel and AMD firmware tracked from `trixie-backports` (pinned).
- Manual install via official Debian 13 netinst USB, with a documented click-by-click partitioning cheat sheet.

### Storage layout
- **Split-role, two independent LUKS-encrypted btrfs disks** (2 TB usable total).
- **NVMe1 (OS):** EFI (1 GB) + LUKS → btrfs pool with subvolumes:
  - `@` → `/`
  - `@home` → `/home`
  - `@var` → `/var`
  - `@containers` → `/var/lib/docker`
  - `@snapshots` → `/.snapshots`
- **NVMe2 (data + backups):** LUKS → btrfs pool with subvolumes:
  - `@data` → `/srv/data`
  - `@backups` → `/srv/backups`
- **Snapper** on NVMe1: pre/post apt, hourly, daily.

### Encryption
- **LUKS passphrase at boot**, typed manually. No TPM2 auto-unlock in v1.

### Desktop
- **KDE Plasma 6, minimal** — only the packages needed for a pleasant session. No opinionated theming layer. Breeze Dark default.
- **Terminal:** Konsole.
- **Font:** JetBrainsMono Nerd Font system-wide.

### Shell
- **zsh** (framework-free), hand-written `~/.zshrc` as a Jinja2 template.
- apt packages only: `zsh-autosuggestions`, `zsh-syntax-highlighting`.
- **starship** prompt with a small, clean config.

### Dev environment
- **Languages:** Node.js/TypeScript, Python, Go.
- **Node:** **pnpm** (also manages Node versions via `pnpm env use`). No npm/nvm.
- **Python:** **uv** (manages Python versions AND packages). No pip/pyenv/poetry directly.
- **Go:** native toolchain (install path finalized in plan, likely official tarball).
- **Supply-chain scanning:** Socket.dev integrated with pnpm.
- **Editor:** VS Code via Microsoft apt repo.

### Home lab / testing platform
- **Primitives only; no preset apps.**
- **Docker CE + Docker Compose** via docker.com apt repo.
- **Traefik** as reverse proxy with Docker label-based auto-discovery.
- **Tailscale** for remote access to test deployments.
- **Scratch convention:** `/srv/data/lab/{compose,volumes,secrets}/<service>/`.

### Backup strategy (three layers)
- **Layer A — local same-disk:** snapper on NVMe1 (pre/post apt, hourly, daily).
- **Layer B — local cross-disk:** nightly `btrfs send` of `@` and `@home` from NVMe1 → `@backups` on NVMe2 via systemd timer.
- **Layer C — off-site:** nightly **restic → Dropbox via rclone backend**, client-side encrypted. Covers `/home/<user>` + `/etc`, excluding caches, `node_modules`, `.venv`, `target/`, `build/`, `dist/`, `/srv/data/lab`, `/var/lib/docker`. Retention: 7 daily / 4 weekly / 6 monthly.
- **Dropbox desktop sync client** also installed for live Dropbox folder access (separate from the restic backup layer).

### Security
- **Firewall: nftables** with a deny-all-inbound baseline; allow loopback, established/related, and `tailscale0` freely. Config lives in `/etc/nftables.conf` as a Jinja2 template.
- **SSH: tailnet-only** (bound to `tailscale0`), key-only, root disabled, password auth disabled.
- **unattended-upgrades: security-only**. Kernel (backports) and regular upgrades stay manual.
- **sudo** with password prompt (no NOPASSWD).

### Automation
- **Ansible**, localhost, role-based (role list above). Re-runnable, idempotent, config-as-code.

## Non-goals

- **No Hyprland / tiling WM in v1.** Explored and parked. Conflicts with the "no troubleshooting" constraint. A secondary Hyprland session could be added as a future experiment without disturbing the Plasma primary.
- **No GNOME.** Old script used it; we're on Plasma 6.
- **No opinionated theming** (no Gruvbox, Catppuccin, Dracula, Yaru, Dash-to-Dock). Stock Plasma Breeze Dark.
- **No oh-my-zsh** or any zsh plugin manager. Framework-free.
- **No preset self-hosted apps** (Nextcloud, Immich, Vaultwarden, Home Assistant, Jellyfin). Lab ships primitives only.
- **No k3s / Kubernetes in v1.** Optional role deferred.
- **No preseed automation in v1.** Manual install is fine for a single rarely-reinstalled machine.
- **No TPM2 auto-unlock in v1.** Passphrase only.
- **No fail2ban.** Tailscale is the perimeter; SSH isn't publicly exposed.
- **No RAID1 mirror.** Split-role disks + Dropbox off-site is the chosen redundancy model.
- **No mdadm, no LVM.** Pure btrfs on LUKS.
- **No chezmoi for dotfiles in v1.** Ansible templates first.
- **No host-level language runtime clutter.** Only pnpm, uv, Go. No distrobox/devcontainers in v1.
- **No cloud config management** (Salt/Chef/Puppet). One machine, Ansible localhost only.
- **No VM hypervisor** (Proxmox, libvirt). Bare metal, Docker for isolation.
- **No bundled "desktop extras"** (LibreOffice, GIMP, VLC, Firefox, etc.) installed by default. User-selected apps go in via Flatpak or explicit apt picks in a dedicated list.

## Constraints

- **Hardware:** Beelink SER8 (Ryzen 7 8845HS Zen 4, Radeon 780M RDNA 3, 64 GB RAM, 2×1 TB NVMe). Requires kernel 6.6+ for full support; using Debian 13 backports (6.12+) satisfies this with margin.
- **No troubleshooting** — modern hardware must work on first boot. If a chosen layer introduces fragility, it must be optional or deferred.
- **Minimal package footprint** — user explicitly rejects bundled extras.
- **Source of truth must be a git repo** — no inline heredoc'd configs, no "remember what you typed" state.
- **User not familiar with exotic partition schemes** — install-time steps must be documented click-by-click, and the layout must be achievable through the Debian installer's GUI without shell gymnastics.
- **Dropbox is the off-site destination** — the backup tool must support Dropbox (restic + rclone Dropbox backend satisfies this).
- **Client-side encryption for off-site backups is mandatory** — Dropbox must never see plaintext.
- **Tailscale is the remote-access perimeter** — no public SSH, no public service exposure.

## Success Criteria

1. **Install-to-running time:** fresh SER8 → working dual-role machine in one afternoon (manual installer + playbook run).
2. **Idempotency:** `ansible-playbook site.yml` on a converged machine reports **zero changes** on a second run.
3. **Rollback works:** trigger a simulated bad apt upgrade → `snapper rollback` restores the prior state and the machine boots cleanly.
4. **Test-service round-trip:** drop a Compose file into `/srv/data/lab/compose/<name>/`, bring it up, confirm it's routable through Traefik at a predictable hostname and reachable from the user's laptop over Tailscale without hand-editing any proxy config.
5. **Backup round-trip:** wipe `~/testdir`, restore it from the latest restic snapshot in Dropbox within minutes. Wipe `~/testdir`, restore it from the local NVMe2 btrfs-send backup within seconds.
6. **Disaster recovery simulation:** wipe NVMe1 entirely, reinstall Debian + run playbook + restore `/home` from restic → a working machine with the user's prior state recovered.
7. **Repo hygiene:** every config file on the box that the user cares about is traceable to a template in the Ansible repo. No orphaned manual edits.

## Key Risks

1. **Dropbox Linux client + encrypted btrfs filesystem compatibility.** Dropbox's Linux client has historically restricted supported filesystems. As of 2026 it generally works on btrfs, but must be verified in a smoke test before committing. Fallback: drop the desktop client, keep restic-only for off-site.
2. **Snapper + backports kernel interaction.** Automatic snapshots must fire before apt kernel upgrades so a bad kernel is rollback-safe. Needs verification.
3. **Manual partitioning is a one-time human error surface.** Mitigation: literal screenshots + numbered steps in the plan's cheat sheet. Fresh install should be rehearsed once in a VM before the real SER8 install.
4. **Scope creep in the lab role.** The "platform, not apps" discipline will be tempting to break. Mitigation: explicit non-goal; new services go into a separate follow-up issue, never into v1.
5. **Configs drifting out of Ansible.** User manually editing files on the box instead of updating templates. Mitigation: prominent README rule "edit the playbook, not the box"; periodic `--check` runs to detect drift.
6. **Backports kernel pin breaking.** If the backports kernel is unavailable or broken after a future release, the system should still boot on the last known good kernel. Mitigation: keep at least one prior kernel installed, verify GRUB fallback works.
7. **pnpm-managed Node versions vs system Node.** If any system package pulls in `nodejs` from apt, it'll shadow pnpm's managed Node in PATH. Mitigation: avoid the apt nodejs package entirely; verify no Ansible role pulls it transitively.
8. **Tailscale outage** locks the user out of SSH remote management. Mitigation: document the local-console recovery procedure; the Plasma session is always available directly on the machine.

## Open Questions

1. **Which self-hosted apps (if any) land in a future milestone** — Vaultwarden, Immich, Nextcloud, Home Assistant, Jellyfin, etc. Each has its own data model and backup implications. Deferred until the user has concrete needs rather than speculative ones.
2. **k3s role** — whether to add a toggleable Kubernetes-in-a-box role for testing k8s-based product deployments. Deferred; the current `lab` role runs Compose only.
3. **Preseed automation / unattended install** — promoting the manual install step to a preseed.cfg as a later milestone. Cost/benefit only pays off if the user reinstalls frequently or adds a second machine.
4. **TPM2 auto-unlock** via `systemd-cryptenroll` — deferred until the base system is proven and the user decides whether the home-lab "must reboot unattended" case actually matters in practice.
5. **Dropbox account tier / quota / target folder** — needed to size the restic retention policy realistically. Currently specified as "7d/4w/6m" retention by default but may need tuning to fit available Dropbox space.
6. **Dotfiles repo split** (chezmoi or similar) — deferred until the Ansible-template-based dotfiles approach demonstrably becomes unwieldy.
7. **Dev containers / distrobox** for per-project isolation — deferred; v1 installs language tools on the host only.
8. **Go install path** — native apt package vs. official tarball vs. `mise` as a standalone exception. Needs to be finalized in the implementation plan (default assumption: official tarball managed by Ansible, kept current by a variable).
9. **Specific apt package pick list** for the `desktop` role — which apps constitute "minimal Plasma" exactly. Needs a concrete allow-list in the plan (e.g., `plasma-desktop`, `sddm`, `dolphin`, `konsole`, `kate`, `plasma-nm`, `plasma-pa`, and deliberately NOT `kde-full` / `kde-standard` / `kde-plasma-desktop` meta-packages which pull in too much).
10. **Flatpak + Flathub** — whether to set up Flatpak for user-installed GUI apps (likely yes for minimal apt footprint), and whether any Flatpaks ship by default (likely no).
11. **GPU firmware and Mesa version** — whether stock Trixie Mesa is fine for the 780M or if Mesa from backports is needed for gaming/video acceleration workloads (likely stock Trixie Mesa is fine for dev workloads, revisit if issues).
12. **Power management profile** — whether to target performance, balanced, or power-save by default on a desktop mini-PC (likely balanced via `power-profiles-daemon`).
