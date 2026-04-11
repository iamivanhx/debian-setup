# SER8 Dev + Test-Staging Setup — Implementation Plan

Target machine: Beelink SER8 (Ryzen 7 8845HS, Radeon 780M, 64 GB RAM, 2×1 TB NVMe).
Source PRD: [`ideas/ser8-dev-setup/PRD.md`](../ideas/ser8-dev-setup/PRD.md).

This plan breaks the PRD into four vertical slices. Each phase ends in a machine state the user can actually use (or, for Phase 0, a repo state the user can actually run).

---

## Technical decisions

All decisions below are locked by the PRD. Any change requires an explicit PRD amendment.

### Architecture and tool

- **Automation:** modular bash evolving the existing `beelink_debian_post_install.sh`. `run.sh` entrypoint sources `lib/common.sh` + `lib/guards.sh` + secrets, iterates nine numbered modules (`modules/00-base.sh` … `80-backup.sh`). Subcommands: `./run.sh`, `./run.sh <module>`, `./run.sh --dry-run [module]`, `./run.sh smoke [module]`, `./run.sh backup now`.
- **Idempotency enforcement:** `lib/guards.sh` provides a fixed `guard::*` vocabulary (see PRD §10.3). Every destructive action is either wrapped in a guard or preceded by a `# SAFE_REPLAY:` comment. A pre-commit grep hook enforces this convention mechanically.
- **Templating:** `envsubst` and shell parameter expansion. No Jinja2, no Go templates, no DSL.
- **Secrets:** `~/.config/ser8-setup/secrets.env`, plaintext, outside the repo, sourced at `run.sh` top. Missing file or missing required key fails loudly with a pointer to `docs/install.md`.

### Base system

- **OS:** Debian 13 Trixie amd64, `trixie-backports` enabled. Kernel + AMD firmware pinned high from backports; Mesa stock Trixie.
- **Install:** manual Debian netinst + click-by-click `docs/install.md`. LUKS + ext4 on NVMe1; NVMe2 left untouched (automation handles it post-install). No preseed, no custom ISO.
- **Hardware tuning:** backports kernel, AMD firmware, `amd64-microcode`, NVMe udev scheduler rule, `power-profiles-daemon` with `balanced` default, `fwupd`.

### Storage

- **NVMe1:** EFI (1 GB) + LUKS → ext4 single partition (`/` + `/home`).
- **NVMe2:** LUKS → ext4 single partition mounted at `/srv/data`. Auto-unlocked via keyfile at `/etc/luks-keys/srv-data.key` (referenced from `/etc/crypttab`).
- **Docker data root:** relocated to `/srv/data/docker` via `/etc/docker/daemon.json` `"data-root"` — the Docker-official mechanism. **Not** via symlink, **not** via bind-mount.
- **Ordering drop-in:** `/etc/systemd/system/docker.service.d/waits-for-srv-data.conf` enforces `srv-data.mount` before `docker.service` on every boot.
- **Directory conventions:** `/srv/data/lab/compose/<project>/` for drop-in Compose files; `/srv/data/projects/` for git working copies; `/srv/data/docker/` for Docker's data.

### Security

- **Firewall:** nftables templated. Deny WAN inbound; allow loopback + established/related + LAN subnet (variable, default `192.168.1.0/24`) for ports 22, 80, 443. No other inbound.
- **SSH:** key-only, no root, no password. `sshd_config` templated. Bound to `0.0.0.0` (nftables enforces LAN-only at the packet level).
- **unattended-upgrades:** security-only. Kernel upgrades stay manual. `Remove-Unused-Kernel-Packages "false"` so GRUB fallback stays populated.
- **sudo:** password-prompted, no NOPASSWD.
- **No fail2ban, no root password, no public exposure.**

### Desktop + shell + dev stack

- **Desktop:** KDE Plasma 6 minimal, explicit allow-list per PRD §5.5. SDDM. JetBrainsMono Nerd Font from upstream tarball to `/usr/local/share/fonts/`. Flatpak + Flathub remote enabled; no Flatpaks pre-installed. Breeze Dark stock.
- **Shell:** zsh framework-free (apt `zsh-autosuggestions` + `zsh-syntax-highlighting` only, no oh-my-zsh). starship via official install script. `~/.zshrc` + `~/.config/starship.toml` templated from the repo.
- **Dev:** VS Code via the Microsoft apt repo. pnpm via official install script + `pnpm env use --global lts` run as the primary user. uv via official script. Go from `trixie-backports`. Apt `nodejs`/`npm` held early in `00-base.sh` and asserted absent in `60-dev.sh`.

### Lab / test-staging

- **Container runtime:** Docker CE + Compose plugin from docker.com's apt repo.
- **Reverse proxy:** Traefik v3 running as a container under `/srv/data/lab/compose/traefik/docker-compose.yml`. **Docker provider** with shared external network `traefik-proxy`, `exposedByDefault=false`, entrypoints `web` (:80) + `websecure` (:443). Host-header routing only. **No HTTPS in v1** — websecure is a placeholder for a future HTTPS decision.
- **Discovery:** Avahi + vendored `avahi-aliases` community tool reading `/etc/avahi/aliases` (one hostname per line). systemd service with `Restart=always`, `After=avahi-daemon.service`, plus a `systemd.path` unit watching the alias file and reloading on change.
- **Project drop-in:** per-project directory under `/srv/data/lab/compose/<project>/`. Project declares Traefik labels + adds its alias to `/etc/avahi/aliases`. `./run.sh lab-up <project>` convenience target automates restart + alias reload.
- **Reference smoke project:** `whoami` stack at `templates/lab/whoami/docker-compose.yml`, used both as copy-paste starter and as an end-to-end smoke target.

### Backup

- **Tool + target:** restic → Backblaze B2 via native B2 backend. No rclone shim.
- **Scope:** `/home/<user>/`, `/srv/data/projects/`, `/srv/data/lab/compose/`, `/srv/data/docker/volumes/`.
- **Exclude:** caches, `node_modules`, `.venv`, `target`, `build`, `dist`, `.next`, `.turbo`, Docker metadata outside `volumes/`, anything under a `.backupignore`.
- **Cadence:** nightly at 03:00 via `restic-backup.timer`. Manual trigger via `./run.sh backup now`.
- **Retention:** 7 daily / 4 weekly / 6 monthly, enforced by separate `restic-forget.timer`. Revisit after one month.
- **Known caveat:** Docker volume backups happen at whatever point-in-time the timer fires; no pause/fsfreeze in v1. Projects with precious dev-database state are expected to use their own per-project dump hooks (out of scope for core automation).

### Testing

- **Smoke tests** are per-module functions (`smoke_<modulename>`) at the bottom of each module file. `./run.sh smoke` runs all; `./run.sh smoke <module>` runs one. Smoke tests check externally visible state (package installed, service active, port listening, template matches on disk, hostname resolves, container running, snapshot exists).
- **Linting:** `shellcheck` + `shfmt -d` via `./run.sh lint`. Pre-commit hook for the guard convention.
- **Idempotency gate:** `./run.sh --dry-run` on a converged machine must report zero planned actions. Run after every module edit.
- **Acceptance walk:** `docs/acceptance.md` — manual checklist walking every PRD §8 user story, walked once before v1 is declared done.
- **Disaster drill:** mandatory NVMe1 wipe + reinstall + rerun + restore drill, scheduled as the final Phase 3 gate.

### Decisions resolved during planning (PRD left open)

- **Phase breakdown:** four phases — Phase 0 pre-flight, Phase 1 foundation, Phase 2 workstation, Phase 3 lab + backup + disaster drill. Confirmed with user.
- **Legacy script fate:** `xfce-setup.sh`, `hyprland-setup.sh`, `debian-post-install.sh`, `beelink_ubuntu_post_install.sh` are **deleted in Phase 0** (not archived). `beelink_debian_post_install.sh` is **retained as reference** through Phase 2 and deleted after all its working content has been ported, as the final act of Phase 2.
- **Avahi alias lifecycle on project removal:** removing a project's directory does **not** auto-remove its alias. The operator removes the alias manually. Auto-removal adds a failure surface we don't want in v1.
- **`avahi-aliases` distribution:** vendored into the repo under `lib/avahi-aliases/` and installed by `70-lab.sh` to `/usr/local/sbin/`. Not relying on a packaged version or an upstream fetch at install time.

---

## Vertical slice overview

1. **Phase 0: Pre-flight — repo scaffold, install cheat sheet, legacy cleanup.**
   Purpose: produce a runnable repo (`run.sh` with empty modules, `lib/` with helpers, `docs/install.md`) and clean the legacy scripts out of the top level, before any real module work.
2. **Phase 1: Foundation — base + hardware + storage + security.**
   Purpose: one `./run.sh` pass converts a fresh Debian 13 box into a hardened, LAN-reachable, `/srv/data`-mounted base system. No desktop, no dev tools, no lab yet.
3. **Phase 2: Workstation — desktop + shell + dev.**
   Purpose: same `./run.sh`, second pass, delivers Plasma 6 + zsh + starship + pnpm/uv/Go/VS Code. The SER8 becomes usable as a dev box. At the end of this phase, the legacy `beelink_debian_post_install.sh` is deleted.
4. **Phase 3: Lab + Backup + Disaster Drill — 70-lab + 80-backup + NVMe1 wipe drill.**
   Purpose: Docker + Traefik + Avahi + reference whoami round-trip on the LAN; nightly restic → B2 with retention; then the mandatory disaster drill (wipe NVMe1, reinstall, rerun, restore, verify Docker volumes on NVMe2 survived) as the acceptance gate for v1.

---

## Phase 0: Pre-flight

- **Summary:** Build the repo scaffold, write the install cheat sheet, delete the legacy scripts. No module logic yet.
- **What this phase delivers:**
  - `README.md` — top-level "edit the automation, not the box" rule, clone/run instructions, phase status.
  - `run.sh` — entrypoint that sources `lib/common.sh` + `lib/guards.sh` + `~/.config/ser8-setup/secrets.env` (fails loudly if absent), parses CLI (`./run.sh`, `./run.sh <module>`, `./run.sh --dry-run`, `./run.sh smoke`, `./run.sh backup now`, `./run.sh lint`, `./run.sh lab-up <project>`), iterates `modules/*.sh` in sorted order.
  - `lib/common.sh` — `deploy_config`, `safe_install`, `info`/`warn`/`error`/`success`/`step` helpers ported from the existing script (lines 48–82).
  - `lib/guards.sh` — the full `guard::*` vocabulary from PRD §10.3, each guard a small bash function with a documented contract (return 0 = state is satisfied, return 1 = state is not satisfied). No state is mutated by guards.
  - `modules/00-base.sh` … `modules/80-backup.sh` — **empty stubs**: each file contains only `step "<module name>"`, a `smoke_<name>() { :; }` no-op, and a top-of-file comment pointing at the PRD section that will fill it in later. This lets `./run.sh` exit 0 from day one and the `smoke` subcommand works immediately.
  - `templates/` — empty directory tree mirroring target on-disk layout (`templates/etc/`, `templates/home/user/`, `templates/srv/data/lab/`, `templates/systemd/`).
  - `docs/install.md` — literal click-by-click Debian 13 netinst cheat sheet with screenshots: USB boot, language/locale, network, hostname `ser8`, user creation, **LUKS + ext4 on NVMe1** (single partition under LUKS, EFI separate), **leave NVMe2 untouched**, minimal install (SSH server + standard utilities only, no desktop — the automation installs Plasma). Ends with "eject USB, reboot, log in as your user, create `~/.config/ser8-setup/secrets.env` from these env var names, clone the repo, run `./run.sh`."
  - `docs/recovery.md` — skeleton document explaining the reinstall-and-rerun flow at the highest level. Fleshed out in Phase 3 after the disaster drill has been walked.
  - `docs/projects.md` — skeleton document explaining "how to add a Docker project to the SER8." Fleshed out in Phase 3 when the lab actually exists.
  - `docs/acceptance.md` — skeleton of the manual acceptance walk. Populated as each phase lands.
  - **Legacy cleanup:** `xfce-setup.sh`, `hyprland-setup.sh`, `debian-post-install.sh`, `beelink_ubuntu_post_install.sh` are deleted from the repo root. `beelink_debian_post_install.sh` is retained (it's the porting source for Phases 1–2).
  - **Pre-commit hook skeleton** — a simple shell script under `.git/hooks/pre-commit` (documented in `README.md` so the user can symlink it) that runs `shellcheck` on changed `.sh` files and greps for unguarded destructive verbs adjacent to modified lines.
- **What this phase does NOT include:** any real module logic, any Ansible/template content beyond empty directory stubs, any hardware or software touching the real SER8.

### User-facing changes
- New repo top-level layout; legacy scripts gone. Nothing on any machine.

### Implementation notes
- `docs/install.md` is the single most important deliverable of this phase. Treat it like production documentation: numbered steps, screenshots where the Debian installer UI is non-obvious, zero branching, zero "or".
- `lib/guards.sh` is where the whole idempotency story lives. Every guard must have a doctest-style comment example showing a typical call. The guards are the contract the modules consume; they need to be right before the modules start landing.
- `run.sh` must exit 0 cleanly even with empty module stubs. The CI-ish loop is "edit module, run `./run.sh <module>`, run `./run.sh --dry-run <module>`, iterate." Having that loop functional from day zero keeps the subsequent phases tight.
- The pre-commit hook is best-effort (shell-based grep, not a proper parser). The real enforcement is the user noticing `./run.sh --dry-run` reporting changes on a converged machine.

### Blocking dependencies
- None. Phase 0 is the entry point.
- Phase 1 cannot start until `./run.sh` runs cleanly against its empty modules and `docs/install.md` has been walked at least once mentally (not necessarily executed in a VM — user explicitly declined a VM rehearsal gate in the deleted PRD).

---

## Phase 1: Foundation

- **Summary:** Land modules `00-base`, `10-hardware`, `20-storage`, `30-security` so that `./run.sh` against a freshly installed SER8 produces a hardened, LAN-reachable, `/srv/data`-mounted base system.
- **What this phase delivers:**
  - **`00-base.sh`** — apt sources template (main + contrib + non-free-firmware + backports), backports pinning (`/etc/apt/preferences.d/backports`), `apt update && apt upgrade`, `apt-mark hold nodejs npm`, locale (`en_US.UTF-8`), timezone (user-configurable, default `Europe/Madrid` or equivalent — actual value in a variable at the top of `run.sh`), OS gate (non-Trixie → fail with detected distro), core CLI packages (`git build-essential make jq curl wget htop ripgrep fd-find bat tree unzip`).
    - Smoke: `smoke_00_base` checks: backports repo present, `dpkg -s` on core packages, `apt-mark showhold` lists nodejs/npm, `locale -a | grep en_US.utf8`.
  - **`10-hardware.sh`** — backports kernel (`linux-image-<generic>-backports` or the matching meta), AMD firmware (`firmware-amd-graphics`), `amd64-microcode`, `fwupd`, NVMe scheduler udev rule (templated to `/etc/udev/rules.d/60-nvme-scheduler.rules`), `power-profiles-daemon` with `power_profile` variable (default `balanced`).
    - Smoke: `smoke_10_hardware` checks: `uname -r` is a backports kernel, `modinfo amdgpu`, `dpkg -s amd64-microcode`, udev rule file present and matches template, `systemctl is-active power-profiles-daemon`, `powerprofilesctl get` matches configured profile.
  - **`20-storage.sh`** — NVMe2 LUKS container creation (**one-shot, guarded by `cryptsetup isLuks`** — re-runs must not reformat), keyfile generation at `/etc/luks-keys/srv-data.key` mode 0400 (guarded by `guard::file_exists`), `/etc/crypttab` entry templated, ext4 format on decrypted device (guarded by `blkid` reporting ext4), `/etc/fstab` entry templated, `/srv/data` mountpoint created and mounted, directory skeleton under `/srv/data/` (`projects/`, `lab/compose/`, `docker/`), `/etc/docker/daemon.json` templated with `data-root: /srv/data/docker` (Docker itself is installed in Phase 3), `/etc/systemd/system/docker.service.d/waits-for-srv-data.conf` templated to enforce `srv-data.mount` → `docker.service` ordering.
    - Smoke: `smoke_20_storage` checks: `cryptsetup isLuks` on NVMe2, `/srv/data` is a mountpoint, keyfile exists and is mode 0400, crypttab and fstab have the expected lines, `daemon.json` exists with correct `data-root`, `docker.service.d/waits-for-srv-data.conf` exists.
  - **`30-security.sh`** — `/etc/nftables.conf` templated (deny WAN, allow loopback + established/related + LAN subnet for 22/80/443, explicit log-and-drop rule for debugging), `nftables.service` enabled, `/etc/ssh/sshd_config` templated (key-only, no root, no password), pre-flight assertion that `~/.ssh/authorized_keys` (or the variable holding authorized key lines) is non-empty before touching sshd, `/etc/apt/apt.conf.d/50unattended-upgrades` templated (security-only, `Remove-Unused-Kernel-Packages "false"`), `unattended-upgrades` service enabled, `/etc/sudoers.d/ser8` templated (password-prompted), reload sshd + nftables.
    - Smoke: `smoke_30_security` checks: `nft list ruleset` matches the templated ruleset byte-for-byte, `systemctl is-active ssh` and `systemctl is-active nftables`, `ss -Hltn` shows sshd listening on `0.0.0.0:22` with no surprises, sshd_config matches template, `apt-config dump APT::Periodic::Update-Package-Lists` is `"1"`.
- **What this phase does NOT include:** no desktop, no shell customization, no dev tools, no Docker, no Traefik, no restic, no lab. SSH from LAN is the only external interface.

### User-facing changes
- Running `./run.sh` on a fresh install converges the machine and reports zero destructive actions on a second run.
- `ssh <user>@ser8.local` from a LAN device (once Avahi-daemon is pulled in transitively — or directly via the SER8's DHCP-assigned IP) works with the authorized key.
- `/srv/data` is mounted and empty. NVMe2 is LUKS-open and auto-unlocks on boot.
- The machine is a text-console-only hardened server at the end of this phase.

### Implementation notes
- The `20-storage` module is the deepest and riskiest in this phase. Develop it on a second LUKS loop device on a test machine (or a spare disk image) before running it against the real NVMe2. Once the module is proven idempotent against a test target, run it on the SER8.
- LUKS format and ext4 mkfs are the two "destructive if re-run" operations in the whole automation. Both MUST have bulletproof guards. Wrong = user loses data. Test these guards by running `./run.sh 20-storage` twice in a row on a fresh NVMe2 — second run must be a no-op.
- The SSH authorized key variable is sourced from `secrets.env` (`SSH_AUTHORIZED_KEYS` — a newline-separated list). If empty, `30-security.sh` fails before touching sshd.
- The nftables template should log dropped packets at a low rate (`limit rate 10/minute`) so that debugging connectivity failures is possible from the console without watching tcpdump.
- Unattended-upgrades kernel-retention must be tested explicitly: after the first backports kernel upgrade, at least two kernel packages must be visible in `dpkg -l | grep linux-image`.

### Blocking dependencies
- Phase 0 complete (repo runnable, guards library exists, install.md exists).
- A populated `~/.config/ser8-setup/secrets.env` with at least `SSH_AUTHORIZED_KEYS` set.

---

## Phase 2: Workstation

- **Summary:** Land modules `40-desktop`, `50-shell`, `60-dev` so that the SER8 becomes a usable Plasma workstation with the full dev toolchain. At the end of this phase, the legacy `beelink_debian_post_install.sh` is deleted as the final act.
- **What this phase delivers:**
  - **`40-desktop.sh`** — minimal Plasma 6 allow-list from PRD §5.5 (`plasma-desktop sddm konsole dolphin kate ark gwenview okular plasma-nm plasma-pa kscreen kwalletmanager xdg-desktop-portal-kde breeze-gtk-theme qt6-wayland fonts-noto fonts-noto-color-emoji fonts-jetbrains-mono`), `sddm.service` enabled, JetBrainsMono Nerd Font tarball fetched from upstream to `/usr/local/share/fonts/JetBrainsMonoNerdFont/` (guarded by directory existence), `fc-cache -fv` triggered on font install only, Flatpak + Flathub remote added (`flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo`), **no Flatpaks installed**.
    - Smoke: `smoke_40_desktop` checks: all allow-list packages installed, `systemctl is-enabled sddm`, font file `JetBrainsMonoNerdFont-Regular.ttf` exists under `/usr/local/share/fonts/`, `fc-list | grep -q JetBrainsMono`, `flatpak remotes` lists flathub.
  - **`50-shell.sh`** — `zsh` install, `chsh` to zsh for the primary user (guarded by `getent passwd` field 7), apt `zsh-autosuggestions` + `zsh-syntax-highlighting`, starship via `curl -sSL https://starship.rs/install.sh | sh -s -- -y` (guarded by `command -v starship`), `~/.zshrc` deployed via `deploy_config` from `templates/home/user/.zshrc`, `~/.config/starship.toml` from `templates/home/user/.config/starship.toml`. pnpm's PATH entry placed ahead of `/usr/bin` in `~/.zshrc` so system Node (if ever installed) can never shadow pnpm's.
    - Smoke: `smoke_50_shell` checks: `getent passwd $USER | cut -d: -f7` is `/usr/bin/zsh`, `command -v starship`, `~/.zshrc` matches template, `~/.config/starship.toml` matches template, `zsh -ic 'echo $PATH'` shows pnpm path ahead of `/usr/bin`.
  - **`60-dev.sh`** — Microsoft apt repo + signing key → `code` package, pnpm via official install script run as the primary user with `pnpm env use --global lts`, uv via official install script, `golang-go` from `trixie-backports`, pre-flight assertion that `nodejs` and `npm` apt packages are absent (if present, fail with `apt purge nodejs npm` instruction), `which node` must resolve under `~/.local/share/pnpm` not `/usr/bin`.
    - Smoke: `smoke_60_dev` checks: `command -v code`, `command -v pnpm`, `command -v uv`, `command -v go`, `dpkg -s nodejs 2>/dev/null` returns non-zero (absent), `which node` resolves under pnpm path, `node --version` and `go version` succeed.
  - **Legacy cleanup (final):** After `40`/`50`/`60` have landed and their smoke tests pass, every line of `beelink_debian_post_install.sh` that represents working content for these modules has been ported. `beelink_debian_post_install.sh` is **deleted** at the end of Phase 2 as the closing act. `README.md` is updated to reflect this.
- **What this phase does NOT include:** no Docker, no Traefik, no Avahi, no lab, no restic, no backups. The machine is now a usable dev workstation but has no "deploy my container" capability.

### User-facing changes
- Machine boots to SDDM, logs into Plasma 6, zsh is the default shell, Konsole opens, VS Code launches, the full dev toolchain (`node pnpm python uv go git code`) is in PATH.
- Nerd Font renders in Konsole and VS Code terminal.
- `apt install nodejs` still fails thanks to the hold from Phase 1.

### Implementation notes
- The pnpm PATH entry in `~/.zshrc` MUST land before `code` launches its first terminal, or VS Code caches a stale Node path. Verified by the smoke test `zsh -ic 'echo $PATH'` showing pnpm path first.
- The starship install script is a `curl | sh` pattern — wrap it in a `guard::command_exists starship` check so re-runs don't re-fetch.
- Microsoft's apt repo + GPG key has to be added idempotently. Use `gpg --dearmor` → `/etc/apt/keyrings/microsoft.gpg` with a `guard::file_exists` check and an `apt-get update` trigger only if the key file was just created.
- The `pnpm env use --global lts` step runs as the primary user, not root. `run.sh` supports `run_as_user <cmd>` via `sudo -u $SUDO_USER` or similar — established in Phase 0 as a common helper.
- Deleting `beelink_debian_post_install.sh` at the end of Phase 2 is a git commit that is worth its own PR/commit so the history captures the "now there is one source of truth" moment.

### Blocking dependencies
- Phase 1 complete (foundation converges cleanly, idempotent on re-run).
- Phase 2 can technically develop against a Phase-1-converged SER8 directly (no VM rehearsal required — user rejected the VM gate).

---

## Phase 3: Lab + Backup + Disaster Drill

- **Summary:** Land `70-lab.sh` (Docker + Traefik + Avahi + whoami) and `80-backup.sh` (restic + B2 + retention), then execute the mandatory NVMe1-wipe disaster drill as the acceptance gate.
- **What this phase delivers:**
  - **`70-lab.sh`** — docker.com apt repo + GPG key → `docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`, primary user added to `docker` group (guarded by `id -Gn`), `docker.service` enabled **after** verifying `daemon.json` is in place and `srv-data.mount` drop-in is active, vendored `avahi-aliases` copied to `/usr/local/sbin/avahi-aliases` (guarded by `guard::file_matches_template`), `avahi-daemon` installed and enabled, `/etc/avahi/aliases` created as empty file (guarded by `guard::file_exists`), templated `avahi-aliases.service` + `avahi-aliases.path` systemd units dropped into `/etc/systemd/system/` (the `.path` watches `/etc/avahi/aliases` and triggers the service on change), `traefik-proxy` external Docker network created (guarded by `guard::docker_network_exists`), Traefik Compose stack dropped into `/srv/data/lab/compose/traefik/docker-compose.yml` from a template, `docker compose up -d` against the Traefik stack (guarded by `guard::container_running traefik`), reference `whoami` stack dropped into `/srv/data/lab/compose/whoami/` from a template with `traefik.enable=true` + `Host(\`whoami.local\`)` label, `echo whoami.local >> /etc/avahi/aliases` (guarded by `guard::file_has_line`), final smoke: `curl -sf http://whoami.local` returns 200 with whoami's body **when run from the SER8 itself** (LAN-client verification is a manual step in `docs/acceptance.md`).
    - Smoke: `smoke_70_lab` checks: Docker service active, user in docker group, `traefik-proxy` network exists, traefik container running, whoami container running, `getent hosts whoami.local` resolves to a `192.168.x.x` address, `curl -sf -H 'Host: whoami.local' http://127.0.0.1` returns 200.
  - **`80-backup.sh`** — `restic` install from apt (`restic` package — verify version is recent enough for B2 native backend, otherwise pin to backports), templated `/etc/restic/ser8.env` file (sourced by systemd units, pulls B2 creds from the user's secrets.env via a small bridge script), **one-shot** `restic init` on B2 guarded by the presence of a `.restic-initialized` marker file on NVMe2 (`guard::file_exists /srv/data/.restic-initialized`), templated `restic-backup.service` + `restic-backup.timer` (nightly 03:00), templated `restic-forget.service` + `restic-forget.timer` (weekly), include/exclude files templated to `/etc/restic/includes.txt` and `/etc/restic/excludes.txt`, `./run.sh backup now` subcommand wired to `systemctl start restic-backup.service`.
    - Smoke: `smoke_80_backup` checks: restic installed, `/etc/restic/includes.txt` matches template, `systemctl is-enabled restic-backup.timer`, `systemctl is-enabled restic-forget.timer`, `restic snapshots --latest 1 --json` returns at least one snapshot (after the first run — the smoke test is conditional on `./run.sh backup now` having been invoked).
  - **`docs/projects.md`** — fleshed out: how to add a Docker project (drop compose, add alias, `./run.sh lab-up <project>`), the Traefik label reference, the known-footguns checklist, the reference whoami compose file as a copy-paste starter.
  - **`docs/recovery.md`** — fleshed out: the exact step-by-step reinstall procedure, the secrets recreation checklist, the `restic restore` procedure, the "NVMe2 is still encrypted, here's how to unlock it mid-install" procedure, and the expected timeline.
  - **`docs/acceptance.md`** — fully populated with every PRD §8 user story as a manual check.
  - **Disaster drill execution:** Actually run the drill. Wipe NVMe1 on the real SER8 (or a rehearsed clone, if the user has one available — but the drill must exercise the real reinstall path at some point). Reinstall Debian per `docs/install.md`. Run `./run.sh`. Unlock NVMe2, verify `/srv/data/docker/volumes/` contents match pre-wipe. Restart `whoami` and any other pre-existing projects via `./run.sh lab-up-all`. Restore `/home/<user>` from B2 via `restic restore`. Walk every check in `docs/acceptance.md`. **If any check fails, fix the responsible module and re-run the drill from scratch. v1 is not done until the drill passes clean.**
- **What this phase does NOT include:** no HTTPS, no per-project backup hooks, no k3s, no external access, no preset self-hosted apps. The parking lot in PRD §13 stays parked.

### User-facing changes
- `docker ps` shows Traefik + whoami running.
- From any LAN device: `curl http://whoami.local` returns 200 (verified during the drill from at least one client device per type — laptop, phone).
- Nightly restic snapshots appear in `restic snapshots` output.
- `./run.sh backup now` triggers an immediate backup that finishes and produces a new snapshot.
- A deleted `~/testdir/` is recoverable from B2 in minutes via the procedure in `docs/recovery.md`.
- After the disaster drill: the machine behaves identically to before the drill. Docker volumes survived. Previously-running projects can be restarted with `docker compose up -d` per directory. `/home/<user>` is back from restic.

### Implementation notes
- The `70-lab` module is the second deepest after `20-storage`. Break it into clear sub-steps internally (Docker install, Avahi setup, network creation, Traefik stack, whoami stack) each with its own guard. Re-running `./run.sh 70-lab` after a `docker rm whoami` should bring whoami back from the same compose file without fuss.
- `restic init` is the one backup operation that must run exactly once per B2 repository. The marker file approach (`/srv/data/.restic-initialized`) is simpler than querying B2 to ask "is this repo initialized already?" — and more reliable if B2 is temporarily unreachable.
- The systemd `.path` unit watching `/etc/avahi/aliases` is the slickest part of the Avahi story: `echo foo.local >> /etc/avahi/aliases` is sufficient to trigger an `avahi-aliases` reload. Verify it actually fires during the lab module's smoke test by writing to the file and polling for the new alias to resolve.
- The disaster drill is uncomfortable but load-bearing. Do not skip it, do not reduce it to "we talked about it." The recovery path is the entire justification for the modular-bash + reinstall-rerun strategy.
- After the drill, commit a "v1 acceptance walk passed" marker somewhere visible (e.g. a line in `README.md` or a git tag). Future regressions are measured from that point.

### Blocking dependencies
- Phase 2 complete (workstation landed, `beelink_debian_post_install.sh` deleted, all prior smoke tests green).
- A Backblaze B2 account with a bucket and an application key provisioned before `80-backup.sh` runs. Credentials populated in `secrets.env`.
- A LAN client device available for the post-drill acceptance walk (laptop or phone on the same network).

---

## Remaining work

Parked beyond Phase 3. All of these are listed in PRD §6 (Non-goals) and PRD §13 (Open Questions) — consult those sections before proposing to un-park.

- HTTPS in the lab (mkcert + local CA, or per-host Traefik certs). Revisit when a project actually needs it.
- Per-project dev-database backup hooks (finer granularity than nightly). Revisit when it hurts.
- Auto-removal of Avahi aliases when a project directory is deleted. Revisit if operator discipline fails in practice.
- Retention policy tuning (adjust the 7d/4w/6m defaults once B2 real usage is known for a month).
- Preset self-hosted apps (Vaultwarden, Immich, etc). Out of scope unless the user explicitly changes the project's identity.
- k3s / Kubernetes. Out of scope unless a project under test requires it.
- Second-machine / fleet support. Out of scope; PRD §6 is explicit.
- Public exposure (Tailscale, Cloudflare Tunnel, public DDNS). Out of scope; LAN-only is a hard requirement.

## Testing strategy

- **Per module:** each module defines `smoke_<modulename>` at the bottom. Smoke checks externally visible state only (see PRD §11.2 for what counts as a good smoke check).
- **Per phase:** `./run.sh --dry-run` on a converged box must report zero planned actions after every phase lands. This is the primary regression gate.
- **Per commit:** `./run.sh lint` (shellcheck + shfmt diff) + the pre-commit grep hook for the guard/SAFE_REPLAY convention. Blocking on errors.
- **Acceptance walk:** `docs/acceptance.md` walked once at the end of Phase 3 during the disaster drill.
- **No framework-provided tests.** There is no molecule, no terratest, no Ansible assertion module — idempotency is `--dry-run` + smoke functions + the user's eye.

## How to consume this plan

- **Where to start:** Phase 0. Do not skip it — `lib/guards.sh` has to exist before any real module can land safely.
- **Phase-to-issue breakdown:** feed this plan into the `plan-to-issues` skill. Each phase becomes a directory of tracer-bullet issues — one per module per phase, plus the Phase 0 scaffold issues, plus the Phase 3 disaster drill issue.
- **Re-running is safe:** every phase after Phase 0 assumes `./run.sh` is idempotent from the moment it finishes landing. Any phase that breaks this property is buggy, not an exception.
- **Secrets:** before running anything that touches `80-backup`, populate `secrets.env` with `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY`. Before running `30-security`, populate `SSH_AUTHORIZED_KEYS`.
- **Editing the automation, not the box:** if you catch yourself editing `/etc/foo` on the machine, stop and edit `templates/etc/foo` instead. Then run `./run.sh <module>` to push the change. Deleted PRD and this PRD both carry the same rule for the same reason.

## References

- [PRD.md](../ideas/ser8-dev-setup/PRD.md) — requirements source of truth.
- [prd-input.md](../ideas/ser8-dev-setup/prd-input.md) — original first-principles ideation output.
- PRD §5 — scope (what each module delivers).
- PRD §8 — user stories walked in the Phase 3 acceptance drill.
- PRD §9 — acceptance criteria.
- PRD §10 — module decomposition and deep-module analysis.
- PRD §11 — testing decisions.
- PRD §12 — risk mitigations (R1 idempotency discipline, R4/R6 disaster drill justification).
- Existing `beelink_debian_post_install.sh` — porting source for Phases 1–2; deleted at end of Phase 2.
