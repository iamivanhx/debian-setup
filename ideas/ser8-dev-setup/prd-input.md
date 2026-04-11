# PRD Input: SER8 Dev + Test-Staging Setup

## Context

Standalone project. Goal: a reproducible, idempotent **modular bash** setup that turns a fresh Beelink SER8 into the user's **secondary dev workstation** and **LAN-only test-staging platform** for multiple parallel Docker-based projects they're building.

This is a restart. A prior pass through the idea-to-issues pipeline produced a PRD and plan that committed to Ansible, three-layer backup (snapper + btrfs-send + restic→Dropbox), btrfs subvolumes, and a tailnet-based remote-access story. The user rejected that direction as "too many wrong assumptions" and the previous artifacts were deleted. This brief is rebuilt from scratch against the user's actual workflow.

Existing bash scripts (`beelink_debian_post_install.sh` 1595 lines, `debian-post-install.sh` 1177 lines, plus XFCE/Hyprland setup scripts) live in the same repo. `beelink_debian_post_install.sh` already covers ~60% of this brief's scope (hardware tuning, desktop, shell, dev tools). It is an **asset** — the new automation is an evolution of it, not a replacement.

## Problem Statement

The user wants a second Linux machine (the SER8) that does two things well, on one box, with one reproducible setup:

1. **Secondary dev workstation.** A real KDE Plasma 6 desktop. Full daily dev toolchain (zsh, VS Code, pnpm, uv, Go). Used directly at the machine and over SSH from elsewhere on the LAN.
2. **Test-staging platform for the user's own in-development projects.** Multiple projects running in parallel as Docker containers. Each project gets a clean hostname on the LAN. Behavior should be "production-like" enough to catch real deployment issues before hitting actual production — but without committing to a specific production target (since the user hasn't settled on one yet).

The hard constraint that shapes everything: **the setup must not require modifying any client machine or the router**. Every computer at home must be able to reach any service running on the SER8 with zero per-client configuration.

The secondary constraint: the project must be **reproducible from a single source of truth in a git repo**. If the machine is reinstalled (the designated recovery path), re-running the automation converges it back to the same state.

## Target User

A developer who works in Node.js/TypeScript, Python, and Go daily, uses VS Code as their primary editor, prefers modern minimal-sprawl tooling (pnpm over npm/nvm, uv over pip/pyenv/poetry), and cares about supply-chain hygiene. This machine is their **secondary** — a primary dev machine exists elsewhere — so stability is prioritized over bleeding-edge.

The user has working knowledge of Linux and bash scripting, has built Ansible projects before (specifically `macos-setup/`) and was unhappy with the result, and is not interested in adopting another framework that obscures state.

**Audience of one.** This project is not going to be shared publicly, handed to colleagues, or used as a reference template for strangers.

## Proposed Solution

A **modular bash automation** run locally on the freshly installed SER8, after a one-time manual Debian 13 netinst walkthrough.

### Repo layout (target)

```
debian-setup/
├── README.md
├── docs/
│   ├── install.md          # click-by-click Debian netinst cheat sheet
│   ├── recovery.md         # reinstall + rerun + restic restore
│   └── projects.md         # how to add a new Docker project
├── lib/
│   ├── common.sh           # deploy_config, safe_install, logging helpers
│   └── guards.sh           # reusable idempotency guard functions
├── modules/
│   ├── 00-base.sh          # apt sources + backports pinning + core packages
│   ├── 10-hardware.sh      # backports kernel, AMD firmware, microcode, NVMe
│   ├── 20-storage.sh       # NVMe2 LUKS + ext4 + /srv/data mount + keyfile
│   ├── 30-security.sh      # nftables, SSH key-only, unattended-upgrades, sudo
│   ├── 40-desktop.sh       # Plasma 6 minimal + SDDM + JetBrainsMono
│   ├── 50-shell.sh         # zsh + starship + ~/.zshrc template
│   ├── 60-dev.sh           # pnpm, uv, Go, VS Code (MS apt)
│   ├── 70-lab.sh           # Docker CE + Compose + Traefik + Avahi + aliases
│   └── 80-backup.sh        # restic + B2 + systemd timers
├── templates/
│   ├── etc/nftables.conf
│   ├── etc/ssh/sshd_config
│   ├── etc/crypttab.d/srv-data
│   ├── etc/avahi/...
│   ├── home/<user>/.zshrc
│   ├── home/<user>/.config/starship.toml
│   └── srv/data/lab/compose/traefik/docker-compose.yml
├── run.sh                  # entrypoint: sources lib/, runs modules/ in order
└── beelink_debian_post_install.sh  # legacy reference, kept until migration complete
```

### How it runs

- `./run.sh` — runs every module in order, stopping on the first failure. Re-runnable: every destructive step must be guarded by an idempotency check ("is this already done?").
- `./run.sh module 20-storage` — runs a single module in isolation. Used during development.
- `./run.sh --dry-run` — logs what would happen without executing. Hand-rolled, not framework-provided.
- Secrets (Backblaze B2 credentials, restic passphrase) live at `~/.config/ser8-setup/secrets.env` — plaintext, outside the repo, sourced at runtime. Not versioned, not committed, re-created by hand from a password manager after a fresh install.

### Idempotency discipline

Every module follows a fixed pattern: check-then-act. The existing beelink script has ~3 guards vs. ~35 destructive commands — that ratio is the specific thing this rewrite fixes. A helper library (`lib/guards.sh`) provides reusable checks: `is_installed`, `is_enabled`, `file_has_line`, `dir_exists`, `dpkg_holds`. Every destructive call is wrapped in a guard or justified with a top-of-block comment explaining why re-running is safe without one.

## Core Value Proposition

**"Reinstall the SER8 in an afternoon, re-run the setup script, restore my data from Backblaze, and I'm back exactly where I was."**

One bash entrypoint converges the machine. No YAML, no Python framework, no orchestration tool the user has to think about. The existing script's 1595 lines of hard-won hardware/desktop/shell knowledge are preserved and evolved, not discarded. Idempotency is built by hand but bounded in scope — there's no framework pretending to guarantee it while silently lying.

## Scope

### Hardware
- Beelink SER8: Ryzen 7 8845HS (Zen 4), Radeon 780M (RDNA 3), 64 GB RAM, 2×1 TB NVMe.

### Base OS
- Debian 13 (Trixie), amd64.
- `trixie-backports` enabled; kernel and AMD firmware pinned from backports; Mesa stock Trixie.
- Manual netinst via USB. No preseed, no custom ISO.

### Storage layout
- **NVMe1 (OS + home):** EFI (1 GB) + LUKS → ext4 single partition mounted at `/`. `/home` lives on the same partition, no subvolumes.
- **NVMe2 (data):** LUKS → ext4 single partition mounted at `/srv/data`. Auto-unlocked via keyfile stored at `/etc/luks-keys/srv-data.key` on NVMe1, referenced from `/etc/crypttab`.
- `/var/lib/docker` bind-mounted (or symlinked) to `/srv/data/docker` so Docker volumes live on NVMe2 and survive an NVMe1 reinstall.
- No btrfs. No subvolumes. No snapper. No `btrfs send`.

### Encryption
- **LUKS passphrase at boot** on NVMe1, typed manually at the console.
- NVMe2 auto-unlocked from NVMe1 via keyfile. No TPM2.

### Desktop
- **KDE Plasma 6, minimal packages only.** No `kde-full` / `kde-standard` / `kde-plasma-desktop` meta-packages. A concrete allow-list (plasma-desktop, sddm, konsole, dolphin, kate, plasma-nm, plasma-pa, kscreen, kwalletmanager, xdg-desktop-portal-kde, fonts-noto, fonts-noto-color-emoji) is finalized in the plan.
- **Stock Breeze Dark.** No theming layer (no Gruvbox, Yaru, Catppuccin, etc).
- **JetBrainsMono Nerd Font** system-wide via tarball to `/usr/local/share/fonts/`.
- **Terminal:** Konsole.

### Shell
- **zsh** as the login shell, **framework-free** (no oh-my-zsh, no zinit, no zplug).
- Apt-only plugins: `zsh-autosuggestions`, `zsh-syntax-highlighting`.
- **starship** prompt installed via the official install script, with a hand-written `~/.config/starship.toml` templated from the repo.
- `~/.zshrc` is a checked-in template.

### Dev environment
- **Languages:** Node.js/TypeScript, Python, Go.
- **Node:** pnpm, pnpm-managed Node versions (`pnpm env use --global lts`). No npm, no nvm, no apt `nodejs`/`npm` packages (explicitly asserted absent).
- **Python:** uv. No pip/pyenv/poetry directly.
- **Go:** apt `golang-go` from `trixie-backports`.
- **Editor:** VS Code via Microsoft apt repo.
- Supply-chain scanning: Socket.dev integrated with pnpm at the user level, not the machine level.

### Test-staging platform (the "lab")
- **Docker CE + Docker Compose plugin** from the docker.com apt repo.
- **Traefik v3** as a container, auto-discovering services via Docker labels. Routing strictly by Host header. Two entrypoints: `web` (:80) and `websecure` (:443). HTTPS is out of scope for v1 (revisit when a real need appears).
- **Avahi + avahi-aliases** publishes per-project `.local` hostnames. When a new project is added, a small helper (or a templated config file) registers the alias so clients reach `http://whoami.local`, `http://projectb.local`, etc., with zero per-client configuration.
- **Directory convention:** `/srv/data/lab/compose/<project>/` is the drop-in location for a project's `docker-compose.yml`. A project = one subdirectory.
- A **reference whoami project** lives in the repo under `templates/lab/whoami/` as a copy-paste starter and as a smoke test for the Traefik+Avahi round-trip.

### Backup
- **restic → Backblaze B2** (native backend, no rclone shim).
- Scope: `/home/<user>/` (dotfiles, notes), `/srv/data/projects/` (project working copies and dev databases if any live outside Docker), and a configurable list of Docker volume mount points.
- Excluded: caches, `node_modules`, `.venv`, `target/`, `build/`, `dist/`, `/var/lib/docker` metadata.
- Nightly systemd timer at 03:00, plus a manual `run.sh backup now` target.
- Retention: 7 daily / 4 weekly / 6 monthly (revisit after one month of observed B2 usage).
- Client-side encryption via restic's built-in crypto. B2 never sees plaintext.

### Network & access
- **LAN-only.** No Tailscale, no Cloudflare Tunnel, no public ingress.
- SSH bound to the LAN interface(s), key-only, root disabled, password auth disabled.
- Services reached via `http://<name>.local` from any LAN client via mDNS.

### Security baseline
- **Firewall: nftables**, templated. Deny-all WAN inbound, allow LAN subnet (e.g. `192.168.1.0/24`) for SSH and Traefik entrypoints, allow loopback + established/related.
- **unattended-upgrades:** security-only. Backports kernel upgrades stay manual.
- **sudo:** password-prompted (no NOPASSWD).
- **No fail2ban.** LAN-only means SSH isn't publicly exposed.

### Secrets
- `~/.config/ser8-setup/secrets.env` — plaintext file outside the repo, sourced at runtime.
- Expected variables: `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY`.
- On a fresh install, the user recreates this file from a password manager as part of the install.md procedure.

### Automation tool
- **Modular bash**, evolved from `beelink_debian_post_install.sh`. See §Proposed Solution for structure.

## Non-goals

- **No Ansible.** Previously tried on `macos-setup/`, user was unhappy (idempotency theater, slow re-run latency, state opacity).
- **No Python orchestration tool (pyinfra, SaltStack, Chef, Puppet).** Simpler scope makes the framework win too small.
- **No Nix / NixOS.** Too large a mental shift for this project; may revisit later as a separate experiment.
- **No btrfs, no subvolumes, no snapper, no btrfs-send.** Ext4 on LUKS throughout.
- **No Tailscale in v1.** LAN-only.
- **No public exposure of any kind.** No port forwarding, no reverse tunnel, no Cloudflare, no DDNS.
- **No preset self-hosted apps** (Vaultwarden, Immich, Nextcloud, Home Assistant, Jellyfin). The test-staging platform hosts the user's own projects only.
- **No k3s / Kubernetes.** Docker + Compose only.
- **No preseed automation, no custom ISO.** Manual install is fine for a one-shot.
- **No TPM2 auto-unlock.** Passphrase at boot for NVMe1, keyfile from NVMe1 for NVMe2.
- **No fail2ban.**
- **No RAID (no mdadm, no RAID1 mirror).**
- **No LVM.**
- **No opinionated theming.** Stock Plasma Breeze Dark.
- **No oh-my-zsh, no zsh framework of any kind.**
- **No GNOME, no XFCE, no Hyprland for this project.** (The existing xfce-setup.sh and hyprland-setup.sh scripts stay in the repo as unrelated prior experiments.)
- **No chezmoi / dotfile manager in v1.** `~/.zshrc` and `starship.toml` are bash-templated from the repo.
- **No devcontainers / distrobox.** Host-level language runtimes.
- **No multi-machine / fleet support.** One SER8, one configuration, no host profiles.
- **No HITL prompts in `run.sh`.** Every decision is either configured via a variable at the top of the script or lives in `secrets.env`. `run.sh` is non-interactive.

## Constraints

- **Hardware:** Beelink SER8 (Ryzen 7 8845HS / Radeon 780M / 64 GB / 2×1 TB NVMe). Requires kernel 6.6+ for full support; backports kernel satisfies this with margin.
- **No client-side configuration allowed.** Zero `/etc/hosts` edits, zero router DNS changes, zero manual VPN clients. mDNS (Avahi) is the only LAN discovery mechanism available.
- **No router configuration allowed.** The project must not depend on port forwarding, custom DHCP options, router-side DNS entries, or anything else that requires touching the home router.
- **LAN-only access.** Services and SSH must be reachable from any computer at home, and unreachable from the public internet.
- **Source of truth is a git repo.** No inline heredocs that aren't also templates. No "remember what you typed" state.
- **Reinstall-and-rerun is the recovery story.** The automation must be idempotent enough to converge a fresh Debian install into full working state without manual touch-ups between modules.
- **Backblaze B2 is the backup destination.** Single off-site target, native restic backend.
- **User already has an age of experience with bash.** No new DSL, no new templating language beyond `envsubst` or shell parameter expansion.
- **Existing `beelink_debian_post_install.sh` is the starting point.** Its structure, helpers (`deploy_config`, `safe_install`), and hardware-tuning steps should be reused and extended, not discarded and rewritten from scratch.

## Success Criteria

1. **Install-to-running time:** fresh SER8 → working dual-purpose machine in one afternoon (manual netinst + a `./run.sh` pass + data restore from B2).
2. **Idempotency:** `./run.sh` on a converged machine reports zero destructive actions taken on a second run. A `--dry-run` pass on a converged machine produces zero planned actions.
3. **Reproducibility gate:** a clean Debian 13 install + `./run.sh` + restoring `/home` from restic yields a machine the user cannot distinguish from the pre-reinstall state for daily work.
4. **Multi-project round-trip:** deploying any of the user's Docker-based projects via a drop-in `/srv/data/lab/compose/<name>/docker-compose.yml` makes the project reachable from every LAN client at `http://<name>.local` with no per-client configuration, no router changes, and no manual DNS edits.
5. **Backup round-trip:** delete `~/testdir`, restore it from the latest restic snapshot in Backblaze B2 within minutes.
6. **Disaster recovery drill:** wipe NVMe1 entirely, reinstall Debian + run `./run.sh` + restore `/home` from B2. The NVMe2-resident Docker volumes remain intact across the reinstall (verified by a running project that survives).
7. **Repo hygiene:** every config file on the box the user cares about is traceable to a template in the repo. No orphaned manual edits.
8. **Fast feedback loop:** `./run.sh module <name>` runs a single module against the live box in under 30 seconds for no-op cases.

## Key Risks

1. **Idempotency discipline drift.** The existing beelink script has ~3 guards for ~35 destructive commands — evidence that "build idempotency by hand" is a discipline problem. Without a framework enforcing it, the new script could drift back to the same state over time.
   *Mitigation:* a shared `lib/guards.sh` helper library, a repo-wide convention that every destructive call is either guarded or annotated with a justification comment, and a CI-style `shellcheck` + `shfmt` pass as a pre-commit hook.

2. **avahi-aliases fragility.** Aliases must be republished on every reboot AND every Traefik reload (when a new project is added). A stale or unpublished alias means a dead URL.
   *Mitigation:* the Avahi alias file is templated by the automation, republished via a systemd unit on boot, and re-applied via a `reload` target. Needs a smoke test in the `70-lab.sh` module that actually resolves each published name from the SER8 itself.

3. **Multi-project isolation on a single Docker host.** Port collisions, Docker network name collisions, dev-database file collisions, memory/CPU contention between parallel projects. Traefik solves routing but not isolation.
   *Mitigation:* enforce a per-project directory convention under `/srv/data/lab/compose/<project>/` with isolated Compose networks, document resource limit patterns, and surface a known-failure-mode checklist in `docs/projects.md`. The user owns the discipline of not oversubscribing the box.

4. **Reinstall-and-rerun is load-bearing.** If the automation has latent non-idempotent bugs, the reinstall recovery path fails when actually exercised for the first time.
   *Mitigation:* a disaster-recovery drill in the plan phase — wipe NVMe1, reinstall, run `./run.sh`, verify success. Do this at least once before declaring v1 done.

5. **Dev-database data loss between backups.** Nightly restic backups mean up to 24 hours of dev-database state can be lost to a crash. Acceptable for iteration work, not acceptable if dev databases accumulate state the user actually cares about.
   *Mitigation:* document the loss window in `docs/recovery.md`; offer a `./run.sh backup now` manual trigger before risky operations; if a project's dev-database state turns out to be precious, lift that project's database into a named volume with more aggressive backup cadence (out of scope for v1).

6. **Docker volumes on NVMe2 must survive an NVMe1 reinstall.** This is the bet justifying the two-disk split. If Docker's assumptions about `/var/lib/docker` conflict with a symlink or bind-mount approach, the bet fails silently.
   *Mitigation:* the storage module must be tested in a "wipe NVMe1, preserve NVMe2, reinstall Debian, run automation, restart containers" drill. Not theoretical.

7. **Backports kernel pin breaking after a future Debian release.** If the backports kernel package becomes unavailable or a release upgrade invalidates the pin, the system should still boot.
   *Mitigation:* keep at least one prior kernel installed, verify GRUB fallback works, document the manual recovery step in `docs/recovery.md`.

8. **Accidental apt install of `nodejs`/`npm`.** Any Debian package pulling in `nodejs` transitively will shadow pnpm-managed Node in PATH.
   *Mitigation:* `apt-mark hold nodejs npm`, assert absent in the `60-dev.sh` module, fail loudly with a purge instruction if detected.

## Open Questions

1. **Exact set of directories to back up.** We agreed on "dotfiles + project repos + dev databases + Docker volumes + notes" conceptually, but absolute paths need to be pinned in the plan phase. Likely: `/home/<user>/`, `/srv/data/projects/`, a named list of Docker volumes under `/srv/data/docker/volumes/`.

2. **Retention policy for restic on B2.** Default assumption: 7 daily / 4 weekly / 6 monthly. May need tuning once real data volume is known and B2 bill is observed for one month.

3. **Traefik configuration layout.** Single root Compose file with Traefik + its own labels, or Traefik lives in its own directory with a dedicated config + static file provider for non-Docker routes? Finalized in plan phase.

4. **Avahi alias publishing mechanism.** `avahi-publish-cname` loops, the `avahi-aliases` user-contributed script, or writing `.service` files directly to `/etc/avahi/services/`? All three work; need to pick the most reliable one and lock it.

5. **Dev database backup cadence.** Nightly is the v1 default, but if a project's dev database turns out to need finer granularity, we need a per-project opt-in mechanism. Out of scope for v1 — revisit when it hurts.

6. **When to add HTTPS to the lab.** v1 is HTTP-only over the LAN. Revisit if a project under test requires HTTPS behavior (WebAuthn, service workers, strict-origin features). Options when the time comes: mkcert + local CA trusted on each client, or a self-signed Traefik cert per hostname.

7. **Whether `/var/lib/docker` moves via symlink or bind-mount.** Docker is picky about both approaches in different ways. The storage module needs to pick one, test it, and document the trade-off in a comment.

8. **Smoke-test harness shape.** The previous PRD had a `scripts/smoke-test.sh`; should this brief carry forward the same pattern or fold smoke tests into each module's bottom? Finalized in plan phase.

9. **Whether `xfce-setup.sh` and `hyprland-setup.sh` stay in this repo or move out.** They are unrelated to this project and might confuse a future reader. Either document them as legacy reference or move to a sibling repo. Cosmetic; deferred.

10. **Dropbox desktop client.** The previous PRD included an optional Dropbox desktop sync client (separate from the backup layer). Is Dropbox still a daily tool the user wants installed on this box? If yes, it becomes a single-line apt install in the `60-dev.sh` module with a variable toggle. If no, drop entirely. Not answered yet.
