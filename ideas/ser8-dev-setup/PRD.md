# Product Requirements Document: SER8 Dev + Test-Staging Setup

## 1. Problem Statement

The user owns a Beelink SER8 mini-PC that needs to become both a **secondary dev workstation** (Plasma 6, full daily toolchain) and a **LAN-only test-staging host** for multiple parallel Docker-based projects they are building. The machine must be reproducible from a single bash automation in a git repo, so that a full reinstall + rerun + data restore returns the user to exactly the state they were in before — because "reinstall and re-run the setup script" is the explicit recovery plan in place of any snapshot/rollback machinery.

A prior pass through this exercise produced an Ansible-based design that the user rejected after grilling revealed it was importing assumptions from a failed `macos-setup` Ansible experience (idempotency theater, slow re-run latency, opaque state). The previous artifacts were deleted. This PRD starts from a first-principles brief captured in `prd-input.md` and commits to a **modular bash** automation that evolves the existing 1595-line `beelink_debian_post_install.sh` rather than replacing it.

The shape of the problem that makes it non-trivial:

1. **Zero client-side configuration.** Every device on the home LAN — laptops, phones, tablets — must be able to reach services running on the SER8 without anyone editing `/etc/hosts`, touching the router, or installing a VPN client. mDNS (Avahi) is the only discovery mechanism that satisfies this.
2. **Multi-project parallelism.** Several Docker projects will run at the same time, each needing its own LAN hostname, each needing to survive a reinstall of the OS disk if possible, each needing to be added with minimal ceremony.
3. **Hand-built idempotency with no framework safety net.** Bash gives no guarantees — every destructive action must be either guarded by an explicit precondition check or justified in place. The existing script has ~3 guards for ~35 destructive commands, which is exactly the gap this rewrite must close.

## 2. Target User

A single developer (the user).

- Works daily in Node.js/TypeScript, Python, and Go.
- Uses VS Code as primary editor.
- Prefers sprawl-reducing modern tooling: pnpm over npm/nvm, uv over pip/pyenv/poetry.
- Cares about supply-chain hygiene (Socket.dev).
- Owns a primary dev machine elsewhere; the SER8 is secondary.
- Has working knowledge of Linux and bash. Has built Ansible projects before (specifically `macos-setup/`) and was unhappy with the result. Will push back on frameworks that obscure state.
- Not familiar with exotic partition schemes (btrfs, LVM, RAID). Install-time steps must be click-by-click, which is why ext4+LUKS was chosen — it's what the Debian netinst GUI does natively.

**Audience of one.** This project is not going to be shared, distributed, or turned into a reference template. Every decision that adds ceremony "for the benefit of a hypothetical second user" is the wrong decision.

## 3. Objective

Reliably turn a freshly installed Debian 13 SER8 into the user's working dual-purpose machine in **one afternoon**, using **one bash entrypoint**, with **one off-site backup destination**, and a recovery story that is literally "reinstall and re-run this thing."

Concretely the objective has four load-bearing properties that either hold or do not:

1. **Single source of truth.** Every config file on the box that the user cares about is generated from a template checked into the repo. Zero orphaned manual edits.
2. **Re-runnable.** `./run.sh` on a converged machine takes zero destructive actions on a second run and reports zero changes. `--dry-run` predicts this correctly.
3. **Recoverable.** A full NVMe1 wipe + Debian reinstall + `./run.sh` + `restic restore` yields a machine the user cannot distinguish from the pre-wipe state for daily work. **Docker volumes on NVMe2 survive the reinstall** — that's the bet justifying the two-disk split.
4. **Multi-project.** Dropping a `docker-compose.yml` into `/srv/data/lab/compose/<project>/` + declaring a Traefik host label + adding one line to an Avahi aliases file makes the project reachable at `http://<project>.local` from every device on the LAN with no client, router, or DNS configuration anywhere else.

## 4. Proposed Solution

A **modular bash automation** run locally on the SER8 after a one-time manual Debian 13 netinst walkthrough.

### High-level shape

- **`run.sh`** at the repo root is the single entrypoint. It sources a shared `lib/` and iterates over numbered `modules/` files in order. It supports:
  - `./run.sh` — run all modules in order, stop on first failure.
  - `./run.sh <module>` — run a single module (e.g. `./run.sh 70-lab`).
  - `./run.sh --dry-run [module]` — log what would happen without executing. Hand-rolled, not framework-provided.
  - `./run.sh smoke [module]` — run the smoke-test functions embedded in each module (one per module, named `smoke_<module>`).
- **`lib/common.sh`** carries forward the existing script's working helpers: `deploy_config()` (atomic config write with timestamped backup, from the existing script line 68), `safe_install()` (apt-install-if-absent, line 82), logging helpers (`info`, `warn`, `error`, `success`, `step`).
- **`lib/guards.sh`** is a new helper library of reusable idempotency guards (`guard::package_installed`, `guard::service_enabled`, `guard::file_has_line`, etc — full interface in §10). Every destructive action in a module is either wrapped in a guard or preceded by a comment explaining why re-execution is safe.
- **`modules/00-base.sh` … `80-backup.sh`** — nine numbered modules, each independently runnable, each ending in a smoke-test function that verifies its own deliverables.
- **`templates/`** mirrors the on-disk paths of every config file the automation writes (`templates/etc/nftables.conf`, `templates/home/<user>/.zshrc`, etc.). Variable substitution is `envsubst`, not a templating language.
- **`~/.config/ser8-setup/secrets.env`** is the plaintext secrets file, outside the repo, sourced by `run.sh` at the top.

### Recovery path

1. Boot Debian 13 netinst USB.
2. Follow `docs/install.md` click-by-click (LUKS + ext4 on NVMe1, don't touch NVMe2 — the automation handles it).
3. Unlock NVMe2's LUKS with the existing passphrase when prompted by the automation (the keyfile is on NVMe1 and doesn't exist yet).
4. `git clone` the repo, create `~/.config/ser8-setup/secrets.env` from the password manager, run `./run.sh`.
5. `restic restore` `/home/<user>` from Backblaze B2.
6. Start containers: `cd /srv/data/lab/compose/<project> && docker compose up -d` per project, or `./run.sh lab-up-all`.

Expected time: one afternoon.

### Adding a new project

1. `mkdir /srv/data/lab/compose/<project>/`
2. Write `docker-compose.yml` with Traefik labels declaring the Host rule.
3. Append `<project>.local` to `/etc/avahi/aliases` (the avahi-aliases flat file).
4. `docker compose up -d` and `systemctl reload avahi-aliases`.

No central Traefik config edit. No router change. No client-side DNS edit. Visible from every LAN device immediately.

## 5. Scope

### 5.1 Hardware

- Beelink SER8: Ryzen 7 8845HS (Zen 4), Radeon 780M (RDNA 3), 64 GB RAM, 2×1 TB NVMe.

### 5.2 Base OS

- Debian 13 (Trixie), amd64.
- `trixie-backports` enabled; kernel + AMD firmware pinned to backports; Mesa stock Trixie.
- Manual Debian 13 netinst via USB. No preseed, no custom ISO.

### 5.3 Storage layout

- **NVMe1 (OS + home):** EFI system partition (1 GB) + LUKS container → single ext4 partition mounted at `/`. `/home` lives on the same partition as plain directories.
- **NVMe2 (data):** LUKS container → single ext4 partition mounted at `/srv/data`. LUKS auto-unlocked at boot via keyfile stored at `/etc/luks-keys/srv-data.key` on NVMe1 (referenced from `/etc/crypttab`).
- Docker's data directory is relocated to `/srv/data/docker` via `/etc/docker/daemon.json` `"data-root"` — the Docker-official mechanism — not via symlink or bind-mount.
- Directory conventions:
  - `/srv/data/docker/` — Docker's data root.
  - `/srv/data/lab/compose/<project>/` — drop-in Compose files per project.
  - `/srv/data/projects/` — git working copies of user projects.

### 5.4 Encryption

- **LUKS passphrase at boot** on NVMe1, typed manually at the console.
- NVMe2 auto-unlocked from NVMe1 via keyfile.
- No TPM2.
- Backups are client-side encrypted by restic; Backblaze B2 never sees plaintext.

### 5.5 Desktop

- **KDE Plasma 6 minimal** package set. Explicit allow-list; no `kde-full`/`kde-standard`/`kde-plasma-desktop` meta-packages.
  - v1 allow-list (finalized in plan): `plasma-desktop`, `sddm`, `konsole`, `dolphin`, `kate`, `ark`, `gwenview`, `okular`, `plasma-nm`, `plasma-pa`, `kscreen`, `kwalletmanager`, `xdg-desktop-portal-kde`, `breeze-gtk-theme`, `qt6-wayland`, `fonts-noto`, `fonts-noto-color-emoji`, `fonts-jetbrains-mono`.
- **Stock Breeze Dark.** No theming layer (no Gruvbox, Yaru, Catppuccin).
- **JetBrainsMono Nerd Font** installed from upstream tarball to `/usr/local/share/fonts/JetBrainsMonoNerdFont/` with an `fc-cache` follow-up.
- **Terminal:** Konsole.
- **Display manager:** SDDM.
- **Wayland** is the default session.
- **Flatpak + Flathub remote** enabled, but **no Flatpaks installed by default**. Plasma Discover surfaces both apt and Flatpak sources for future user-installed GUI apps.

### 5.6 Shell

- **zsh** as the login shell, **framework-free** (no oh-my-zsh, no zinit, no zplug).
- Apt-only plugins: `zsh-autosuggestions`, `zsh-syntax-highlighting`.
- **starship** prompt installed via the official install script, with a hand-written `starship.toml` templated from the repo.
- `~/.zshrc` is a checked-in template.

### 5.7 Dev environment

- **Node.js:** pnpm, pnpm-managed Node versions (`pnpm env use --global lts`). No apt `nodejs`/`npm` (asserted absent, `apt-mark hold` as belt-and-suspenders).
- **Python:** uv. No pip/pyenv/poetry at the host level.
- **Go:** apt `golang-go` from `trixie-backports`.
- **Editor:** VS Code via the Microsoft apt repo.
- Supply-chain scanning (Socket.dev) is a user-level configuration, not a machine concern.

### 5.8 Test-staging platform

- **Docker CE + Docker Compose plugin** from docker.com's apt repo.
- **Traefik v3** running as a container under `/srv/data/lab/compose/traefik/docker-compose.yml`, using the **docker provider with a shared external network** (`traefik-proxy`). `exposedByDefault=false`. Entrypoints `web` (:80) and `websecure` (:443). Host-header routing only.
- **No HTTPS in v1.** `websecure` exists as a placeholder so a later HTTPS story doesn't require re-architecting. Revisit when a project actually needs it.
- **Avahi + avahi-aliases** from a vendored copy of the `avahi-aliases` community tool, reading a flat `/etc/avahi/aliases` file that lists one hostname per line (e.g. `whoami.local`, `projectb.local`). Runs as a systemd service that republishes on boot and reloads on config change.
- **Directory convention:** `/srv/data/lab/compose/<project>/` contains each project's `docker-compose.yml`. Projects declare routing via Traefik labels and declare their alias via a convention documented in `docs/projects.md`.
- **Reference whoami project** at `templates/lab/whoami/docker-compose.yml` as a copy-paste starter and as an end-to-end smoke test.

### 5.9 Backup

- **restic → Backblaze B2** (native B2 backend, no rclone shim).
- **Include paths** (confirmed with user):
  - `/home/<user>/`
  - `/srv/data/projects/`
  - `/srv/data/lab/compose/`
  - `/srv/data/docker/volumes/` (with caveats — see §12 Risk Mitigations for the mid-write consistency story).
- **Exclude paths:** caches (`~/.cache`, `~/.local/share/Trash`), language build artifacts (`node_modules`, `.venv`, `target`, `build`, `dist`, `.next`, `.turbo`), Docker's internal bookkeeping (`/srv/data/docker/` minus `volumes/`), anything under a `.backupignore` file.
- **Cadence:** nightly via `restic-backup.timer` systemd unit at 03:00. Manual trigger via `./run.sh backup now`.
- **Retention:** 7 daily / 4 weekly / 6 monthly, enforced by a separate `restic-forget.timer`. Revisit after one month of observed B2 usage.
- **Secrets:** `~/.config/ser8-setup/secrets.env` holds `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY`. Sourced at runtime by `run.sh`.

### 5.10 Security

- **Firewall: nftables**, templated. Default policy: drop all inbound on WAN-side interfaces. Allow loopback, established/related, and the LAN subnet (parameterized — default `192.168.1.0/24`) for SSH (22), HTTP (80), HTTPS (443). No other ports open by default.
- **SSH:** `sshd_config` templated. Key-only, no root, no password, bound to `0.0.0.0` (nftables enforces the LAN-only policy at the packet level).
- **unattended-upgrades:** security-only. Kernel upgrades (from backports) stay manual.
- **sudo:** password-prompted (no NOPASSWD).
- **No fail2ban.** SSH isn't exposed to the public internet.
- **No root password.** Root account disabled as a login target.

### 5.11 Secrets

- `~/.config/ser8-setup/secrets.env` — plaintext, mode 0600, outside the repo, outside any backup, recreated from a password manager on a fresh install as step 4 of `docs/install.md`.
- Expected keys: `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY`, optional `GITHUB_TOKEN`, optional `ANTHROPIC_API_KEY`.
- `run.sh` sources the file at the top. Missing-file: fail loudly with `docs/install.md` link. Missing-key: fail loudly naming the specific module that needs it.

### 5.12 Automation tool

- **Modular bash**, evolved from `beelink_debian_post_install.sh`. See §10 for the full decomposition.

### 5.13 Repo layout (target)

```
debian-setup/
├── README.md
├── docs/
│   ├── install.md          # click-by-click Debian netinst cheat sheet
│   ├── recovery.md         # reinstall + rerun + restic restore procedure
│   ├── projects.md         # how to add a new Docker project
│   └── acceptance.md       # manual acceptance walk checklist
├── lib/
│   ├── common.sh           # deploy_config, safe_install, logging, step
│   └── guards.sh           # guard::* idempotency guards
├── modules/
│   ├── 00-base.sh
│   ├── 10-hardware.sh
│   ├── 20-storage.sh
│   ├── 30-security.sh
│   ├── 40-desktop.sh
│   ├── 50-shell.sh
│   ├── 60-dev.sh
│   ├── 70-lab.sh
│   └── 80-backup.sh
├── templates/
│   ├── etc/…                # every /etc/ file the automation writes
│   ├── home/user/…          # dotfile templates
│   ├── srv/data/lab/…       # reference compose files including whoami
│   └── systemd/…            # timers/services
├── run.sh                   # entrypoint
└── beelink_debian_post_install.sh   # kept as legacy reference until the 60-dev + 50-shell + 40-desktop modules have landed all its working content; then deleted
```

Legacy scripts `xfce-setup.sh`, `hyprland-setup.sh`, `debian-post-install.sh`, `beelink_ubuntu_post_install.sh` — the user has confirmed these are to be **deleted** as part of the initial Phase 0 cleanup. They are unrelated experiments and git history preserves them if ever needed.

## 6. Non-goals

These are not in v1 and should not be reopened without an explicit PRD amendment:

- **No Ansible.** Explicit user rejection after `macos-setup` experience.
- **No pyinfra / SaltStack / Chef / Puppet / Nix / NixOS.** Framework overhead not justified by this project's size.
- **No btrfs, no subvolumes, no snapper, no btrfs-send.** ext4+LUKS throughout.
- **No Tailscale or any VPN/overlay network.** LAN-only.
- **No public exposure of any kind.** No port forwarding, no DDNS, no Cloudflare Tunnel, no reverse tunnel.
- **No preset self-hosted apps** (Vaultwarden, Immich, Nextcloud, Home Assistant, Jellyfin). The lab is for the user's own WIP projects only.
- **No k3s / Kubernetes.** Docker + Compose only.
- **No HTTPS in the lab in v1.** Placeholder websecure entrypoint only; revisit on real need.
- **No preseed, no custom ISO.** One-time manual install is acceptable.
- **No TPM2 auto-unlock.**
- **No fail2ban.**
- **No RAID (mdadm / RAID1).**
- **No LVM.**
- **No opinionated theming.** Stock Plasma Breeze Dark.
- **No oh-my-zsh, zinit, zplug, or any zsh framework.**
- **No GNOME, XFCE, or Hyprland for this project.** The legacy scripts covering these are deleted.
- **No chezmoi or dotfile manager.** Dotfiles are bash-templated.
- **No devcontainers / distrobox.** Host-level language runtimes.
- **No fleet / multi-machine / host profiles.** One SER8, one config.
- **No interactive prompts in `run.sh`.** Every decision is either a variable, a secret, or a failure.
- **No Dropbox desktop client.** The primary dev machine has it; the SER8 does not.
- **No smoke-test harness as a standalone script.** Smoke functions live inside each module.

## 7. Constraints

- **Hardware:** Beelink SER8 (Ryzen 7 8845HS / Radeon 780M / 64 GB RAM / 2×1 TB NVMe). Requires kernel 6.6+ for full support; `trixie-backports` kernel satisfies this with margin.
- **No client-side configuration.** No `/etc/hosts` edits, no manual DNS entries, no VPN clients, no certificate imports. mDNS is the sole LAN discovery mechanism.
- **No router configuration.** No port forwarding, no DHCP option hacks, no router-side DNS, no static leases required.
- **LAN-only reachability.** Services must be reachable from every LAN client (laptop, phone, tablet, additional desktops) and unreachable from anywhere outside the house.
- **Source of truth is a git repo.** No inline heredoc'd configs that aren't also templates. No "remember what you typed" state.
- **Reinstall-and-rerun is the only recovery path.** The automation must be idempotent enough to converge a fresh Debian install without any between-module manual touch-ups.
- **Backblaze B2 is the sole backup destination.** Native restic backend.
- **No DSL, no new templating language.** Bash + `envsubst` + shell parameter expansion only.
- **Existing `beelink_debian_post_install.sh` is the starting point.** Its working helpers (`deploy_config`, `safe_install`) and its hardware-tuning/desktop/shell/dev content are ported module-by-module. Nothing is rewritten for rewriting's sake; nothing is carried forward blindly.

## 8. User Stories

### Core flows

1. As a developer, I want to run `./run.sh` on a freshly installed Debian 13 SER8 and get a fully converged machine, so that I don't have to remember dozens of post-install steps.
2. As a developer, I want `./run.sh --dry-run` on a converged machine to report zero planned actions, so that I can trust the idempotency of the automation before running it.
3. As a developer, I want `./run.sh <module>` to execute a single module against a running machine in under 30 seconds when nothing needs to change, so that my edit-test loop is tight.
4. As a developer, I want every config file on the box to be traceable to a template in the repo, so that drift is impossible by construction.

### Install / recovery

5. As a developer reinstalling the SER8, I want a click-by-click `docs/install.md` that walks me through partitioning (LUKS+ext4 on NVMe1, leave NVMe2 for automation), so that I don't have to think about partitioning under pressure.
6. As a developer who just wiped NVMe1, I want `./run.sh` + `restic restore /home/<user>` + re-unlocking NVMe2 to produce a machine indistinguishable from the one I wiped for daily work, so that my recovery plan is actually exercised.
7. As a developer, I want Docker volumes on NVMe2 to survive an NVMe1 wipe (because `data-root` points at NVMe2), so that my running projects persist across an OS reinstall.
8. As a developer, I want the `docs/recovery.md` procedure to be explicit enough that I could follow it at 2 AM after losing a disk, so that the recovery story isn't "re-figure it out."

### Dev workstation

9. As a developer, I want to boot to SDDM, log in, and land in a usable Plasma 6 session with Konsole, VS Code, and the full dev toolchain in PATH, so that the machine is immediately productive.
10. As a developer, I want `node`, `pnpm`, `python`, `uv`, `go`, `git`, `code`, `docker` to all succeed on the first post-install shell, so that I don't have to chase PATH or install steps.
11. As a developer, I want zsh as my login shell with `starship` prompt and my templated `~/.zshrc`, so that my terminal feels familiar without any oh-my-zsh machinery.
12. As a developer, I want `~/.cache/zsh/history` to persist across sessions, so that shell history isn't lost on crash.
13. As a developer, I want accidental `apt install nodejs` to fail or be held, so that apt's Node can never shadow pnpm's Node.

### Test-staging platform

14. As a developer, I want to drop `docker-compose.yml` into `/srv/data/lab/compose/<project>/` + add one line to `/etc/avahi/aliases` + run `docker compose up -d`, and have `http://<project>.local` resolve from any LAN client, so that adding a project is a two-step operation.
15. As a developer, I want every LAN device (laptop, phone, additional desktops) to reach project URLs with zero per-client configuration (no `/etc/hosts`, no router change, no DNS change), so that adding devices to my home network is friction-free.
16. As a developer, I want `traefik` to auto-discover any container with `traefik.enable=true` on the `traefik-proxy` network, so that routing is label-driven and no central config edits are required.
17. As a developer, I want multiple projects to run in parallel without port collisions, so that I can test several things at once.
18. As a developer, I want `docs/projects.md` to contain a reference `docker-compose.yml` with the Traefik labels I need, so that the first project is copy-paste.
19. As a developer, I want the reference `whoami` project to round-trip end-to-end (container starts, Traefik routes, Avahi resolves, HTTP 200) as a post-install smoke test, so that I know the lab pipeline works before I deploy my own code.
20. As a developer, I want Docker's data root under `/srv/data/docker/` so that NVMe1 doesn't fill up with image layers.

### Backup and data

21. As a developer, I want nightly restic snapshots to Backblaze B2 covering `/home`, `/srv/data/projects`, `/srv/data/lab/compose`, `/srv/data/docker/volumes`, so that I can recover my working state from off-site.
22. As a developer, I want `./run.sh backup now` to trigger a manual backup run before I do anything risky, so that my safety net is operator-triggerable.
23. As a developer, I want `restic snapshots` to work from the command line after install, so that the backup state is inspectable without leaving the shell.
24. As a developer, I want retention enforced by a separate `restic-forget.timer` so that prune cycles can't interrupt active backups.
25. As a developer, I want to recover `~/testfile` from the latest B2 snapshot in minutes via a documented procedure, so that restore works in practice and not just in theory.

### Security

26. As a developer, I want SSH reachable only from my LAN subnet, so that exposing the SER8 is physically impossible without an explicit firewall change.
27. As a developer, I want `nftables` loaded at boot with the templated ruleset, so that security isn't a runtime configuration I forget to apply.
28. As a developer, I want `sudo` to always prompt for a password, so that muscle memory doesn't bite me.
29. As a developer, I want unattended-upgrades applying security patches nightly without touching the backports kernel, so that the baseline stays patched without surprise kernel reboots.

### Operator discipline / drift

30. As a developer, I want `./run.sh --dry-run` to surface any file on disk that differs from its repo template, so that drift is detectable with one command.
31. As a developer, I want every module's smoke-test function (`smoke_<module>`) to verify its own deliverables, so that post-run verification is co-located with the module code.
32. As a developer, I want `./run.sh smoke` to run every module's smoke test in one shot, so that "is the box healthy" is a single command.
33. As a developer, I want `./run.sh smoke 70-lab` to run only one module's smoke test, so that I can verify a single area I just touched.

### Error cases

34. As a developer, if `secrets.env` is missing, I want `run.sh` to fail at the top with a message pointing me at `docs/install.md`, so that I don't waste time on errors deep in a module.
35. As a developer, if I'm running on a non-Trixie OS, I want the `00-base.sh` module to fail with the detected distro, so that I don't wreck the wrong machine.
36. As a developer, if my ed25519 SSH key isn't in `ssh_authorized_keys`, I want the `30-security.sh` module to fail before touching sshd, so that I can't lock myself out.
37. As a developer, if NVMe2 isn't detected by `20-storage.sh`, I want to fail with the correct device-path hint, so that I don't accidentally format the wrong disk.
38. As a developer, if a subsequent `apt install` pulls `nodejs`/`npm` despite the hold, I want my next `./run.sh` to fail loudly, so that I can purge before it breaks my pnpm environment.

### Admin / internal

39. As a developer, I want to delete the legacy scripts (`xfce-setup.sh`, `hyprland-setup.sh`, `debian-post-install.sh`, `beelink_ubuntu_post_install.sh`) from the repo root in Phase 0, so that the repo top level is dedicated to the new project.
40. As a developer, I want the existing `beelink_debian_post_install.sh` retained as legacy reference until all of its working content has been ported into the new modules, then deleted, so that I'm not juggling two sources of truth.

## 9. Acceptance Criteria

### First-run convergence

- **Given** a fresh Debian 13 Trixie netinst with SSH key loaded and `secrets.env` populated, **when** the user runs `./run.sh`, **then** the script completes with exit 0 and every module's smoke test passes.
- **Given** a converged SER8, **when** the user runs `./run.sh` a second time, **then** zero destructive actions are taken and `./run.sh --dry-run` reports zero planned actions.
- **Given** a converged SER8, **when** the user runs `./run.sh 70-lab` in isolation, **then** the module completes in under 30 seconds for the no-op case.

### Recovery drill

- **Given** a converged SER8 with data on NVMe2, **when** NVMe1 is wiped and Debian is reinstalled + `./run.sh` + `restic restore /home/<user>` is executed, **then** the Docker volumes on NVMe2 are intact AND previously-running projects under `/srv/data/lab/compose/*` can be brought back up with `docker compose up -d` AND `/home/<user>` is restored to the last B2 snapshot state. **This drill MUST be exercised at least once before v1 is declared done.**

### Multi-project LAN visibility

- **Given** a new project with a `docker-compose.yml` declaring the Traefik host label `whoami.local` and a matching entry in `/etc/avahi/aliases`, **when** the operator runs `docker compose up -d` and `systemctl reload avahi-aliases`, **then** from any LAN client a `curl http://whoami.local` returns 200 with whoami's body, without any prior configuration on that client.
- **Given** three projects running in parallel, **when** each has its Traefik label and Avahi alias, **then** all three resolve to distinct hostnames on the LAN simultaneously with no port collisions.

### Security posture

- **Given** a converged SER8, **when** `nft list ruleset` is run, **then** the ruleset matches the templated version exactly (verified via `./run.sh --dry-run 30-security`).
- **Given** a converged SER8, **when** a host outside the LAN subnet attempts to connect to port 22, **then** the connection is dropped (verified by sshing from a second host on a different subnet and observing timeout).
- **Given** a converged SER8, **when** `ss -tlnp` is run, **then** sshd is listening and no unexpected listeners are present.

### Backup round-trip

- **Given** a converged SER8 with a populated `~/testdir/`, **when** `./run.sh backup now` is executed and then `rm -rf ~/testdir` and then a restic restore is run, **then** `~/testdir` is recovered to its prior contents.
- **Given** `restic-backup.timer` is active, **when** the next 03:00 tick fires, **then** a new snapshot appears in `restic snapshots` output.

### Drift detection

- **Given** a converged SER8, **when** the operator manually edits `/etc/nftables.conf`, **then** the next `./run.sh --dry-run 30-security` surfaces the diff.

### Daily productivity

- **Given** a converged SER8, **when** the operator logs into Plasma, **then** zsh is the default shell, Konsole opens, `node --version` (via pnpm) succeeds, `uv --version` succeeds, `go version` succeeds, `code --version` succeeds.

## 10. Implementation Decisions

### 10.1 Module decomposition (nine modules)

The 9-module split is chosen for two reasons: it maps cleanly to the existing `beelink_debian_post_install.sh`'s 25 numbered steps (so the porting work is obvious), and every module corresponds to a single concern whose smoke test is self-contained. Modules are numbered so alphabetical order === execution order.

| Module | Concern | Key deliverables | Idempotency pattern |
|---|---|---|---|
| `00-base.sh` | Apt sources, backports pinning, core packages | `/etc/apt/sources.list.d/backports.list`, `/etc/apt/preferences.d/*`, `apt-mark hold nodejs npm`, core CLI packages (`git`, `build-essential`, `make`, `jq`, `curl`, `wget`, `htop`, `ripgrep`, `fd-find`, `bat`, `tree`, `unzip`), locale, timezone | `guard::package_installed`, `guard::file_has_line` |
| `10-hardware.sh` | Backports kernel, AMD firmware, microcode, NVMe scheduler, power management | `linux-image-<backports>`, `firmware-amd-graphics`, `amd64-microcode`, `fwupd`, NVMe udev rule, `power-profiles-daemon` | `guard::package_installed`, `guard::file_exists` for udev rule |
| `20-storage.sh` | NVMe2 LUKS + ext4 + `/srv/data` + keyfile + Docker data-root | LUKS container on NVMe2, keyfile at `/etc/luks-keys/srv-data.key`, `/etc/crypttab` entry, `/etc/fstab` entry, `/etc/docker/daemon.json` with `data-root` | `guard::file_exists` on keyfile, `guard::file_has_line` on fstab/crypttab |
| `30-security.sh` | nftables, SSH, unattended-upgrades, sudo | Templated `/etc/nftables.conf`, templated `/etc/ssh/sshd_config`, `/etc/apt/apt.conf.d/50unattended-upgrades`, `/etc/sudoers.d/ser8` | `deploy_config` with diff-aware behavior |
| `40-desktop.sh` | Plasma 6 minimal, SDDM, JetBrainsMono, Flatpak | Allow-listed Plasma packages, SDDM service enabled, Nerd Font tarball fetched, Flathub remote added | `guard::package_installed`, `guard::service_enabled`, `guard::dir_exists` on fonts |
| `50-shell.sh` | zsh, starship, ~/.zshrc template | zsh install, `chsh`, apt plugins, starship install, templated dotfiles | `guard::user_shell_is`, `guard::command_exists` on starship |
| `60-dev.sh` | pnpm, uv, Go, VS Code | pnpm install-and-`env use`, uv install, `golang-go`, `code` from MS apt | `guard::command_exists`, `guard::apt_repo_present` |
| `70-lab.sh` | Docker CE, Compose, Traefik container, Avahi + aliases, reference whoami | docker.com apt repo, Docker CE, user added to `docker` group, `traefik-proxy` external network, Traefik compose up, avahi-daemon enabled, avahi-aliases systemd unit reading `/etc/avahi/aliases` | `guard::service_active`, `guard::docker_network_exists`, `guard::container_running` |
| `80-backup.sh` | restic, B2 backend, systemd timers, retention | restic install, `restic init` on B2 (one-shot, guarded), templated `restic-backup.service`+`.timer`, `restic-forget.service`+`.timer` | `guard::file_exists` on restic repo marker, `guard::unit_enabled` |

### 10.2 Deep module analysis

Three modules are meaningfully deep (narrow interface, significant internal complexity):

- **`20-storage.sh`** — the only module that touches raw disks. Its interface to other modules is a single invariant: "`/srv/data` is mounted and writable." Internals include LUKS container creation (one-shot, guarded by `cryptsetup isLuks`), keyfile generation with correct perms, `crypttab` template, `fstab` template, Docker `daemon.json` template, and a startup ordering fix so `docker.service` doesn't race `srv-data.mount`. All of that complexity is hidden behind `/srv/data` being there.
- **`70-lab.sh`** — the highest-value module. Its interface to users (projects) is "drop a compose file + add an alias line." Internals include Traefik config, the `traefik-proxy` external network, avahi-daemon, avahi-aliases systemd unit that reads `/etc/avahi/aliases` and spawns `avahi-publish-cname` per line (with re-publishing on reload), the reference whoami stack, and the smoke test that curls each alias. The deep-module payoff is that adding a project is trivially simple.
- **`80-backup.sh`** — restic init is a one-shot (must not re-init on every run or it burns the repo). Its interface is `./run.sh backup now` and a systemd timer. Internals include the include/exclude file generation, the one-shot init guard, the B2 credential sourcing, and the forget/prune timer. Deep because "backups work and are cheap to recover" hides a lot of plumbing.

The remaining six modules are shallower and mostly map declarative state to the machine — `00-base`, `10-hardware`, `30-security`, `40-desktop`, `50-shell`, `60-dev` are essentially long ordered lists of guard+install+template+enable steps. That's fine; not every module needs to be deep, and trying to manufacture depth where it doesn't exist is how modular systems become magical.

### 10.3 `lib/guards.sh` interface

The guard library is the specific mitigation for Risk #1 (idempotency discipline drift). It's small, opinionated, and intended to be the *only* way modules check state.

```
guard::package_installed <pkg>       # exit 0 if dpkg -s says installed
guard::package_held <pkg>            # exit 0 if apt-mark showhold lists it
guard::apt_repo_present <keyword>    # exit 0 if a sources.list entry matches
guard::service_enabled <unit>        # exit 0 if systemctl is-enabled
guard::service_active <unit>         # exit 0 if systemctl is-active
guard::unit_file_exists <unit>       # exit 0 if /etc/systemd/system/<unit> exists
guard::file_exists <path>            # exit 0 if [ -f ]
guard::dir_exists <path>             # exit 0 if [ -d ]
guard::symlink_is <link> <target>    # exit 0 if readlink matches
guard::file_has_line <path> <regex>  # exit 0 if grep -Eq matches
guard::file_matches_template <path> <template>  # exit 0 if cmp -s
guard::user_in_group <user> <group>  # exit 0 if id -Gn lists group
guard::user_shell_is <user> <shell>  # exit 0 if getent passwd field 7 matches
guard::command_exists <cmd>          # exit 0 if command -v
guard::docker_network_exists <name>  # exit 0 if docker network inspect
guard::container_running <name>      # exit 0 if docker inspect .State.Running
guard::port_listening <proto> <port> # exit 0 if ss -Hln matches
```

Convention: every destructive action in a module is either wrapped in a `guard::*` check (guard returns 0 → skip the action) OR preceded by an inline comment `# SAFE_REPLAY: <reason>` that explains why repeating is fine. No other pattern is allowed. `shellcheck` + a simple `grep` pre-commit hook enforces the presence of one or the other on every `apt install`, `cp`, `ln`, `systemctl enable`, `usermod`, `cryptsetup`, `mkfs`, `mount`, `chsh`.

### 10.4 `lib/common.sh` carried-over helpers

From `beelink_debian_post_install.sh`, keep:

- `deploy_config <target>` (line 68 in the existing script) — timestamped backup then content replacement. Augment to support `--diff` mode for `--dry-run` integration.
- `safe_install <pkg...>` (line 82) — install only missing packages. Superseded in modules by `guard::package_installed` loops but retained for backwards-compatibility while porting.
- `info`/`warn`/`error`/`success`/`step` logging helpers (lines 48–55) — carried forward unchanged.

Drop:

- `ask_yes_no()` (line 57) — `run.sh` is non-interactive, no prompts allowed.

### 10.5 `run.sh` entrypoint

- Sources `lib/common.sh` and `lib/guards.sh`.
- Sources `~/.config/ser8-setup/secrets.env` (fails loudly if absent).
- Parses CLI: `./run.sh`, `./run.sh <module>`, `./run.sh --dry-run [module]`, `./run.sh smoke [module]`, `./run.sh backup now`.
- Iterates `modules/*.sh` in sorted order for the default case.
- Each module sourced in its own subshell so `set -e` failures don't kill the parent.
- Exit non-zero on the first module failure; smoke runs are independent and collect results.

### 10.6 Traefik + Avahi integration

Resolved from research (Traefik docs + avahi-aliases community tool):

- **Traefik provider:** docker, with `exposedByDefault=false` and an explicit shared external network `traefik-proxy`. Traefik's own compose file creates the network; project compose files `networks:` section references it as `external: true`. Projects opt in with `traefik.enable=true` labels.
- **Traefik config source:** static config in environment variables in the Traefik compose file (simpler than a file mount for a single-instance setup). Dynamic config comes from Docker labels; no file provider, no dynamic config directory.
- **Avahi aliases:** vendored copy of `avahi-aliases` (the `piku/avahi-aliases` flavor or equivalent) installed to `/usr/local/sbin/` + a systemd service that reads `/etc/avahi/aliases` (one hostname per line) and spawns `avahi-publish-cname` instances. Service restarts on config change via `systemd.path` watching `/etc/avahi/aliases`.
- **Adding a project:** (1) drop compose file; (2) echo hostname into `/etc/avahi/aliases`; (3) `docker compose up -d`; (4) `systemctl reload avahi-aliases`. The `lab-up <project>` convenience target in `run.sh` automates steps 3–4.

### 10.7 Docker data-root

Resolved from Docker docs: use `/etc/docker/daemon.json`'s `"data-root"` key, not symlink, not bind-mount. The `20-storage.sh` module writes `daemon.json` from a template, then the `70-lab.sh` module installs Docker which picks up the config on first start. Ordering matters: `20-storage` must land before Docker is installed, or first Docker install creates `/var/lib/docker` before the config takes effect. The module ordering (20 before 70) ensures this.

### 10.8 Secrets flow

`~/.config/ser8-setup/secrets.env` is a simple `KEY=VALUE` shell file, mode 0600, `source`d by `run.sh` at the top. Modules reference variables directly. If a module needs a secret and the variable is empty, the module fails with the specific key name. No decryption, no wrapping, no keychain integration. Simplicity beats ceremony at this scale.

## 11. Testing Decisions

### 11.1 What's tested

- **Syntax/lint:** `shellcheck` on every `.sh` under `lib/`, `modules/`, `run.sh`. Errors blocking, warnings reviewed. `shfmt -d` for formatting. Both runnable as `./run.sh lint` (aliased to `shellcheck lib/*.sh modules/*.sh run.sh && shfmt -d lib modules run.sh`).
- **Idempotency:** `./run.sh --dry-run` on a converged box must report zero planned actions. This is the primary regression gate.
- **Smoke tests:** each module defines `smoke_<name>()` at the bottom. `./run.sh smoke` runs all; `./run.sh smoke <name>` runs one. Smoke tests check externally visible state (package installed, service active, port listening, file matches template, hostname resolves, container running, snapshot exists) — not implementation details.
- **End-to-end acceptance walk:** `docs/acceptance.md` contains a manual checklist that walks every user story in §8. Done once before declaring v1, repeated after any major change. Not automated.

### 11.2 What makes a good smoke test here

A smoke test is a single command whose exit code answers "did this module deliver what it promised." Good examples:

- `smoke_30_security`: `nft list ruleset | grep -q 'iifname "lo" accept' && systemctl is-active ssh && ss -Hltn | awk '{print $4}' | grep -qx '0.0.0.0:22'`
- `smoke_70_lab`: `docker network inspect traefik-proxy >/dev/null && docker inspect traefik >/dev/null && curl -sf -H 'Host: whoami.local' http://127.0.0.1 && getent hosts whoami.local | grep -q 192.168`
- `smoke_80_backup`: `systemctl is-active restic-backup.timer && restic snapshots --latest 1 --json | jq -e 'length > 0'`

Bad smoke tests (to avoid): anything that checks "did the script say ok" (that's tautological), anything that checks file mtime, anything that checks a temporary state that can flip between runs.

### 11.3 Prior art

The existing `beelink_debian_post_install.sh` has no tests — this is greenfield testing work on top of a script that worked by inspection. The `docs/acceptance.md` manual checklist is borrowed from the pattern the (deleted) Ansible PRD described.

## 12. Risk Mitigations

### R1 — Idempotency discipline drift

**Risk:** The existing script has ~3 guards for ~35 destructive commands. Without a framework enforcing idempotency, the rewritten modules could drift back to the same state. Discipline alone is not a mitigation.

**Mitigation:**
- `lib/guards.sh` provides a fixed vocabulary of guard predicates (see §10.3). Every module consumes these; no module writes its own one-off guard logic.
- Repo convention: every destructive call must be wrapped in a `guard::*` check OR preceded by a `# SAFE_REPLAY: <reason>` comment. Both forms are machine-detectable.
- Pre-commit hook: a `grep` pass over diffs for known destructive verbs (`apt install`, `cryptsetup luksFormat`, `mkfs`, `mount`, `ln -s`, `cp`, `systemctl enable`, `usermod`, `chsh`) that aren't adjacent to a `guard::*` or `SAFE_REPLAY`. Fails the commit if found.
- `./run.sh --dry-run` on a converged machine is the runtime check: if it reports any planned action, a guard is missing. Run after every module edit.

### R2 — avahi-aliases fragility

**Risk:** Aliases must re-publish on reboot AND on Traefik reload AND on adding a new project. Missing any of these → dead URL → painful debugging.

**Mitigation:**
- `avahi-aliases` runs as a systemd service with `Restart=always` and `After=avahi-daemon.service`, ensuring it starts after Avahi on boot.
- A `systemd.path` unit watches `/etc/avahi/aliases` and triggers a service reload on change, so `echo whoami.local >> /etc/avahi/aliases` is sufficient to publish (no manual reload step).
- The `70-lab.sh` smoke test resolves every name in `/etc/avahi/aliases` via `getent hosts` from the SER8 itself. If any fails, the smoke test fails loudly.
- A simple `./run.sh lab-add <project>` convenience target appends the alias, reloads the service, and re-runs the smoke test.

### R3 — Multi-project isolation on one Docker host

**Risk:** Port collisions, Docker network collisions, dev database file collisions, memory/CPU contention between parallel projects.

**Mitigation:**
- Traefik owns all external HTTP routing on 80/443. Project compose files do NOT publish ports; all access goes through Traefik via `traefik-proxy` network. Documented in `docs/projects.md`.
- Each project's compose file uses a project-scoped Docker network (Compose creates one by default named `<dir>_default`). Cross-project traffic forbidden unless explicitly wired.
- Dev data lives under `/srv/data/lab/compose/<project>/data/` or inside named volumes — not in shared paths.
- `docs/projects.md` includes a "known footguns" checklist covering these.
- Resource contention is the user's operational responsibility; no automated resource limits in v1 (can be added per-project via Compose `deploy.resources` if it bites).

### R4 — Reinstall-and-rerun is load-bearing

**Risk:** If the automation has latent non-idempotent bugs, the reinstall recovery path fails exactly when the user needs it most (after a disaster).

**Mitigation:**
- **Mandatory disaster drill before v1 is declared done:** wipe NVMe1, reinstall Debian, run `./run.sh`, restore `/home` from B2, restart all containers, walk `docs/acceptance.md`. If anything fails, fix it and repeat the drill.
- The drill is an explicit acceptance criterion (§9 Recovery drill).
- `docs/recovery.md` documents the exact step sequence so the operator doesn't have to reconstruct it under pressure.

### R5 — Dev-database data loss between backups

**Risk:** Nightly restic means up to 24 hours of dev-database state can be lost to a crash. If dev databases accumulate state the user cares about, this is a silent data loss risk.

**Mitigation:**
- Documented in `docs/recovery.md` as a "data loss window" explicitly named.
- `./run.sh backup now` is available for manual pre-risk backups.
- Projects with precious dev database state are expected to use their own per-project backup (e.g. `pg_dump` cron in the project's compose) rather than relying on volume snapshots. Out of scope for the core automation.
- `/srv/data/docker/volumes/` is in the backup scope (per user confirmation) but backups happen at whatever point-in-time the timer fires; no pause/fsfreeze in v1.

### R6 — Docker volumes on NVMe2 must survive an NVMe1 reinstall

**Risk:** The whole justification for the two-disk split is that a reinstall of NVMe1 leaves Docker volumes on NVMe2 intact. If the `data-root` + keyfile approach has subtle failure modes, this bet breaks silently.

**Mitigation:**
- `20-storage.sh` uses Docker's official `data-root` mechanism (not symlinks, not bind-mounts) per Docker documentation.
- Module order: `20-storage.sh` runs before `70-lab.sh`, so `daemon.json` is in place before Docker is installed. A freshly installed Docker picks up the config on first start.
- **Disaster drill (R4) explicitly verifies this property:** wipe NVMe1, preserve NVMe2, reinstall, run automation, verify that pre-reinstall containers can be started from `/srv/data/lab/compose/*` and that their volumes contain the pre-reinstall data. This isn't theoretical; it's acceptance-gated.
- On-boot ordering: `srv-data.mount` must come before `docker.service`. Handled by a drop-in `/etc/systemd/system/docker.service.d/waits-for-srv-data.conf` templated by `20-storage.sh`.

### R7 — Backports kernel pin breaking after a future release

**Risk:** If the backports kernel is unavailable or broken after a future Debian release, the system should still boot.

**Mitigation:**
- Retain at least one prior kernel (`unattended-upgrades` is configured with `Unattended-Upgrade::Remove-Unused-Kernel-Packages "false";`).
- GRUB fallback to the previous kernel is verified once during the disaster drill.
- Kernel upgrades are security-only excluded (not touched by unattended-upgrades); kernel upgrades happen manually so the operator is awake when they run.

### R8 — Accidental `nodejs`/`npm` apt install shadowing pnpm

**Risk:** Any apt package pulling in `nodejs` transitively shadows pnpm-managed Node in PATH.

**Mitigation:**
- `00-base.sh` runs `apt-mark hold nodejs npm` early, before any other module installs anything.
- `60-dev.sh` asserts both packages are absent at start and fails with a purge instruction if present.
- The `smoke_60_dev` smoke test checks `which node` resolves under pnpm's managed path (`~/.local/share/pnpm`).

## 13. Open Questions

Only questions that remain genuinely deferred to later phases:

1. **Exact retention policy tuning.** Default is 7 daily / 4 weekly / 6 monthly. Revisit after one month of observed B2 usage when real data volume is known.
2. **HTTPS in the lab.** v1 is HTTP-only. Revisit when a specific project requires HTTPS behavior (WebAuthn, service workers, strict origin). Likely answer at that time: mkcert + a local CA trusted per client, or self-signed Traefik per-host certs.
3. **Per-project dev-database backup cadence.** v1 relies on nightly restic. If a project's dev-database state turns out to need finer granularity, the answer is a per-project `pg_dump` (or equivalent) cron inside that project's compose — not a change to the core automation. Revisit when it hurts.
4. **`/etc/avahi/aliases` ownership when a project is removed.** The plan phase must decide whether removing a project's directory also removes its alias, or whether that's a manual operator step. Leaning toward "manual" for v1 because auto-removal is a new failure surface.

All other open questions from `prd-input.md` are resolved above.

## 14. Success Metrics

Measurable post-launch indicators:

1. **Install-to-running time** on a fresh reinstall: target ≤ 3 hours (measured: Debian netinst start → first successful `./run.sh smoke`).
2. **Re-run latency** on a converged box: target ≤ 15 seconds wall-clock for `./run.sh` (no-op pass).
3. **Single-module re-run** on a converged box: target ≤ 5 seconds for `./run.sh 70-lab` (no-op).
4. **Number of manual touch-ups** required between `./run.sh` finishing and the machine being usable: target **zero**. Any touch-up is a bug in the module that required it.
5. **Recovery drill time** on a fresh NVMe1 reinstall with NVMe2 preserved: target ≤ 4 hours for full restoration to pre-disaster state.
6. **Project onboarding time** for a new Docker project: target ≤ 5 minutes (from `mkdir` to `http://<name>.local` resolving from a LAN device).
7. **Backup recovery time** for a single file from B2: target ≤ 2 minutes.
8. **Drift detection latency** from a manual config edit to `./run.sh --dry-run` surfacing it: target ≤ `./run.sh --dry-run` runtime (i.e. immediately).

## 15. References

- **Source brief:** `ideas/ser8-dev-setup/prd-input.md` — the first-principles ideation output that produced this PRD.
- **Existing automation (legacy):** `beelink_debian_post_install.sh` at the repo root — 1595 lines, ~60% coverage of this PRD's scope, source of the `deploy_config` and `safe_install` helpers.
- **Failed framework evidence:** `/home/ivanhx/Documents/macos-setup/` — the Ansible project whose idempotency theater convinced the user to rule out frameworks for this project.
- **Deleted prior PRD:** previously at `ideas/debian-dev-lab/PRD.v1-ansible.md` and `.plans/debian-dev-lab.v1-ansible.md` — deleted by user request on 2026-04-11 after grilling revealed too many wrong assumptions.
- **Traefik v3 docs:** used to resolve Open Question #3 (docker provider + external network pattern).
- **avahi-aliases community tool:** used to resolve Open Question #4 (flat-file alias mechanism).
- **Docker daemon configuration:** used to resolve Open Question #7 (`data-root` canonical mechanism).
