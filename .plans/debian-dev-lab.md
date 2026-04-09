# Debian 13 Dev + Lab Automation — Implementation Plan

Target machine: Beelink SER8 (Ryzen 7 8845HS, 780M, 64 GB RAM, 2×1 TB NVMe).
Source PRD: [`ideas/debian-dev-lab/PRD.md`](../ideas/debian-dev-lab/PRD.md).

This plan breaks the PRD into four vertical slices. Each phase is independently runnable, testable, and ends in a machine state the user can actually use.

---

## Technical decisions

All decisions below are locked. Phases must respect them; any change requires an explicit PRD amendment.

### Adopted verbatim from PRD §10

- **Automation tool:** Ansible, localhost connection, single `site.yml`, nine in-tree roles. No molecule, no galaxy, no CI.
- **Role set and dependency order:** `base` → `hardware` → `storage` → `security` → `desktop` → `shell` → `dev` → `lab` → `backup`. Dependencies declared in each role's `meta/main.yml`.
- **Base OS:** Debian 13 Trixie amd64 + `trixie-backports` pinned low; kernel and AMD firmware re-pinned high from backports; Mesa stays stock Trixie.
- **Install strategy:** manual netinst + click-by-click `docs/install.md`. No preseed, no custom ISO.
- **Storage:** two LUKS-encrypted btrfs disks, split-role (OS on NVMe1, data+backups on NVMe2). Subvolume layout per §5.4. NVMe2 auto-unlocked via keyfile on NVMe1.
- **Snapper:** pre/post apt snapshots on `@` and `@home`, timeline hourly on `@home` (keep 10h/10d).
- **Desktop:** minimal Plasma 6 package list per §5.6 + JetBrainsMono Nerd Font tarball + Flatpak/Flathub remote (no Flatpaks installed). Breeze Dark default.
- **Shell:** zsh as login shell, hand-written `~/.zshrc` template, apt plugins only, starship via official installer with templated `starship.toml`. No framework.
- **Dev:** VS Code via MS apt repo; pnpm via official script with `pnpm env use --global lts`; uv for Python; Go from `trixie-backports`. Apt `nodejs`/`npm` blacklisted and asserted absent.
- **Lab:** Docker CE + Compose plugin from docker.com, Traefik v3 as a container (auto-discovery via Docker labels, entrypoints `web`/`websecure`), Tailscale from tailscale.com apt repo. `/srv/data/lab/{compose,volumes,secrets}/` scaffold.
- **Backup trilogy:** snapper (local same-disk) + nightly `btrfs send` to NVMe2 (local cross-disk) + nightly restic→Dropbox via rclone (off-site, client-side encrypted). Retention per §5.10.
- **Security:** nftables templated (deny-all inbound, allow lo + established/related + `tailscale0`), SSH key-only with staged `ListenAddress` (loopback → tailnet), unattended-upgrades security-only, sudo password-prompted, no fail2ban.
- **Secrets:** `ansible-vault` for Dropbox rclone token, restic passphrase, Tailscale auth key. Vault password NOT in repo.
- **Single-file `site.yml`** + localhost inventory. Variables in `group_vars/all.yml`, overrides in `host_vars/beelink.yml`, vaulted secrets in `group_vars/all/vault.yml`.

### Decisions resolved during planning (PRD left open)

- **Phase breakdown:** 3 implementation phases over a Phase 0 docs/rehearsal pre-flight.
- **Traefik internal TLS:** **Plain HTTP over Tailscale only** in v1. Tailscale's WireGuard tunnel is the trust boundary; no cert machinery, no renewal timers, browser "Not secure" warning is acceptable for dev URLs. Revisit when a test service actually requires HTTPS.
- **Vault password UX:** `--ask-vault-pass` at runtime. No `~/.vault_pass` file. Playbook is run rarely enough that the prompt is not burdensome, and no plaintext vault key sits on disk.
- **VM rehearsal target:** **UTM on macOS** (wraps QEMU, native Mac UI, Hypervisor.framework accel). Sized 4 CPU / 8 GB RAM / 40 GB disk1 + 20 GB disk2 / Debian 13 netinst ISO. Used to validate `docs/install.md` end-to-end before touching the real SER8.
- **Smoke-test strategy:** `scripts/smoke-test.sh` grows incrementally per phase — each phase adds assertions only for what it delivers. Full battery lands in P3.
- **`install_dropbox_client` default:** `true`, but flagged as a smoke-test item in P3. If the 24-hour soak on encrypted btrfs fails, flip to `false` permanently in `host_vars/beelink.yml`.

---

## Vertical slice overview

1. **Phase 0: Pre-flight — repo skeleton, install cheat sheet, VM rehearsal.**
   Purpose: validate the manual install path and stand up the repo scaffold before any role code is written.
2. **Phase 1: Foundation — base + hardware + storage + security.**
   Purpose: one playbook run converges a fresh Debian 13 box to a hardened, rollback-safe, remotely-recoverable state. SSH stays on loopback.
3. **Phase 2: Workstation + Lab — desktop + shell + dev + lab.**
   Purpose: same playbook, second run, delivers Plasma 6, the full dev toolchain, Docker + Traefik + Tailscale, and rebinds SSH to the tailnet. A `whoami` Compose file round-trips over Tailscale.
4. **Phase 3: Backup Trilogy — backup role + full smoke test + acceptance.**
   Purpose: nightly restic→Dropbox lands, retention enforced, optional Dropbox client soak-tested, `scripts/smoke-test.sh` finalized, all PRD §9 acceptance criteria verified end-to-end.

---

## Phase 0: Pre-flight

- **Summary:** Build the repo skeleton and prove the manual install cheat sheet works in a UTM VM before any role code is written.
- **What this phase delivers:**
  - Repo layout per PRD §5.13 (`ansible/`, `docs/`, `scripts/`, `README.md`) with empty role directories stubbed to `meta/main.yml` only.
  - `site.yml` that includes nine roles in dependency order but each role is a no-op (single `debug` task).
  - `ansible/inventory/localhost.yml`, `ansible/group_vars/all.yml` (tunable defaults stub), `ansible/host_vars/beelink.yml` (SSH keys, hostname, timezone stub), `ansible/group_vars/all/vault.yml` (empty vaulted file).
  - `ansible.cfg` configured for localhost + `ask_vault_pass = True`.
  - `docs/install.md` — literal click-by-click manual partitioning cheat sheet with screenshots, covering both NVMes, LUKS labels, btrfs subvolume names (`@`, `@home`, `@var`, `@containers`, `@snapshots`, `@data`, `@backups`), and fstab intent.
  - `docs/rehearsal.md` — UTM setup instructions (disk sizing, ISO, BIOS vs UEFI, network).
  - A UTM VM has been stepped through the cheat sheet end-to-end and boots to a login prompt. Cheat sheet errors caught during rehearsal are fixed in `install.md`, not in prose.
  - `README.md` — top-level "edit the playbook, not the box" rule, clone/run command, phase status.
- **What this phase does NOT include:** any real role logic, any Ansible templates beyond the empty vault, any touching of the real SER8.

### User-facing changes
- New repo directories and docs. Nothing on any machine.

### Implementation notes
- `docs/install.md` is the single most important deliverable of this phase. Treat it as production documentation: numbered steps, screenshots, zero branching.
- The UTM rehearsal is where the cheat sheet earns its credibility. Run it once, fix what breaks, run it again until a clean walkthrough succeeds.
- `site.yml` noop roles exist so `ansible-playbook --syntax-check site.yml` passes from day one — every phase only has to fill in existing hooks.

### Blocking dependencies
- None. Phase 0 is the entry point.
- Phase 1 cannot start until the UTM rehearsal succeeds end-to-end.

---

## Phase 1: Foundation

- **Summary:** Write the first four roles (`base`, `hardware`, `storage`, `security`) so that one `ansible-playbook -K site.yml` run against a freshly installed SER8 produces a hardened, snapper-rollback-safe, nightly-btrfs-send-backed-up base system.
- **What this phase delivers:**
  - `base` role: apt sources template with `trixie-backports` pinned low, backports kernel/firmware re-pinned high, locale, timezone, `apt-mark hold nodejs npm`, core CLI packages (`git build-essential make jq curl wget htop ripgrep fd-find bat tree unzip`), OS gate assertion (fails loudly on non-Trixie), required-vars assertion.
  - `hardware` role: backports kernel + `firmware-amd-graphics` + `amd64-microcode` install, `fwupd` enablement, NVMe scheduler udev rule, `power-profiles-daemon` with `power_profile` variable (default `balanced`), verification that a previous kernel is kept alongside the new one.
  - `storage` role: NVMe2 LUKS container creation, keyfile on NVMe1 with `/etc/crypttab` entry, btrfs pool + subvolumes (`@data`, `@backups`), templated `/etc/fstab` covering both disks, `snapper` configs for `root` and `home` with PRD retention, `/etc/apt/apt.conf.d/80snapper` for pre/post snapshots, nightly `btrfs-send.timer` + `btrfs-send-prune.timer` as templated systemd units. Asserts expected NVMe1 subvolumes exist — fails with "your install.md layout doesn't match" if not.
  - `security` role: `/etc/nftables.conf` templated (deny-all inbound, allow `lo` + established/related, `tailscale0` allow rule conditional on interface presence), `sshd_config` template, staged `ListenAddress` logic — binds to `127.0.0.1` when `tailscale ip -4` is unavailable, rebinds to the tailnet address on a subsequent run. `unattended-upgrades` configured security-only, `APT::Periodic` enabled.
  - `scripts/smoke-test.sh` — phase-1 assertions only: snapper timers active, btrfs-send timer active, nftables ruleset loaded, sshd bound only to loopback, snapper list has at least one entry after apt, kernel fallback present in `/boot`.
- **What this phase does NOT include:** no desktop, no shell customization, no dev tools, no Docker, no Tailscale, no restic, no Dropbox. SSH is deliberately unreachable from anywhere but loopback — operator uses local Plasma console for now (it's not installed yet either; use a text console).

### User-facing changes
- Running `ansible-playbook --ask-vault-pass -K site.yml` on a fresh install converges the machine and reports `changed=0` on a second run.
- `snapper list -c root` shows pre/post entries after any apt transaction.
- `/srv/backups/` receives its first read-only snapshot after the first 02:00 tick (or after a manual `systemctl start btrfs-send.service`).

### Implementation notes
- Storage is the deepest module per PRD §10.2 — land it with a narrow variable interface (`nvme2_device`, retention vars) and keep everything else internal.
- Security's SSH staging is the cleverness the user should not have to think about. Test it explicitly in both states (no tailnet → loopback; tailnet up → tailnet address) during the UTM rehearsal of Phase 1.
- Every config file this phase writes must be traceable to a Jinja2 template in the relevant role's `templates/` directory. No heredocs, no `lineinfile` for canonical content.
- The `--check --diff` idempotency gate runs at the end of this phase on a converged VM before any SER8 work.

### Blocking dependencies
- Phase 0 complete (repo skeleton exists, cheat sheet validated).
- A Phase-1-ready VM (same UTM image used for rehearsal, cloned) to develop against without risking the SER8.

---

## Phase 2: Workstation + Lab

- **Summary:** Land the remaining four non-backup roles (`desktop`, `shell`, `dev`, `lab`) so the SER8 becomes a usable Plasma workstation with the full dev toolchain, and the lab platform can host a test service reachable over Tailscale.
- **What this phase delivers:**
  - `desktop` role: minimal Plasma 6 package list per PRD §5.6 (plasma-desktop, sddm, konsole, dolphin, kate, ark, gwenview, okular, plasma-nm, plasma-pa, kscreen, bluedevil, powerdevil, kwalletmanager, xdg-desktop-portal-kde, breeze-gtk-theme, qt6-wayland, plasma-firewall, fonts-noto, fonts-noto-color-emoji, fonts-jetbrains-mono), SDDM enablement, JetBrainsMono Nerd Font tarball fetched + installed to `/usr/local/share/fonts/JetBrainsMonoNerdFont/` with a `fc-cache` handler, Flatpak + Flathub remote added (no Flatpaks installed).
  - `shell` role: zsh install, `chsh` to zsh for the primary user, `zsh-autosuggestions` + `zsh-syntax-highlighting` from apt, `~/.zshrc` templated (pnpm PATH entry placed ahead of system PATH), starship via official installer, `~/.config/starship.toml` templated.
  - `dev` role: Microsoft apt repo + `code`, pnpm via official script with `pnpm env use --global lts` run as the primary user, uv via official script, `golang-go` from backports, pre-flight assertion that apt `nodejs`/`npm` are absent with a clear error message pointing to `apt purge nodejs npm`.
  - `lab` role: docker.com apt repo + `docker-ce docker-ce-cli containerd.io docker-compose-plugin`, primary user added to `docker` group, Tailscale apt repo + `tailscale` install, `tailscale up` documented (authed once manually or via a vaulted auth key file), Traefik v3 Compose file under `/srv/data/lab/compose/traefik/` with entrypoints `web` (:80) and `websecure` (:443) and Docker provider, `/srv/data/lab/{compose,volumes,secrets}/` directory scaffold with a README explaining the drop-in convention, a `whoami` example Compose file that proves the round-trip.
  - On second playbook run after Tailscale is up, `security` role rebinds SSH `ListenAddress` to the tailnet IP.
  - Smoke-test additions: `node`, `pnpm`, `python`, `uv`, `go`, `git`, `docker`, `code`, `tailscale` all succeed; `which node` resolves under `~/.local/share/pnpm`; `which python` resolves under uv's managed path; `docker ps` shows Traefik running; `curl http://whoami.lab.<tailnet>` from a second tailnet device succeeds.
- **What this phase does NOT include:** no restic, no rclone, no Dropbox, no backup timer, no off-site anything. Local snapper + btrfs-send from P1 is the only backup in effect.

### User-facing changes
- Machine boots to SDDM, logs into Plasma, zsh is the default shell, VS Code opens, full dev toolchain is in PATH.
- Dropping a Compose file into `/srv/data/lab/compose/<svc>/` and `docker compose up -d` makes it reachable at `http://<svc>.lab.<tailnet>` from any Tailscale peer.
- SSH is now reachable over the tailnet from authorized keys only.

### Implementation notes
- The pnpm PATH entry in the zsh rc template MUST land before the `dev` role runs VS Code's first launch, or VS Code's integrated terminal will cache the wrong Node path (PRD §10.2, `dev` module).
- Traefik runs as a Docker container with the docker.sock provider — no systemd unit for Traefik itself. A systemd drop-in ensures the Traefik compose stack comes up on boot via `docker compose up -d` at `/srv/data/lab/compose/traefik/`.
- Tailscale v1 authentication: PRD allows either a manual `tailscale up` or a vaulted auth key. Default to vaulted auth key so the playbook is fully idempotent; fall back to documented manual step if the key path is unset.
- The whoami example is not a real service — it is a v1 acceptance artifact for PRD §9 Story 7/8.

### Blocking dependencies
- Phase 1 complete and green (foundation converges cleanly, idempotent).
- A working Tailscale tailnet the operator controls (pre-existing, not part of this plan).

---

## Phase 3: Backup Trilogy

- **Summary:** Land the `backup` role, finalize the smoke-test script, run the Dropbox client soak, and walk every PRD §9 acceptance criterion to done.
- **What this phase delivers:**
  - `backup` role: restic install, rclone install, `~/.config/rclone/rclone.conf` templated with vaulted Dropbox token, restic repository init (with a vaulted passphrase), `restic-backup.service` + `restic-backup.timer` systemd units templated (03:00 nightly), include paths (`/home/<user>`, `/etc`), exclude paths per PRD §5.10, `restic-forget.service` + `restic-forget.timer` enforcing `keep 7 daily / 4 weekly / 6 monthly`, optional Dropbox desktop client behind `install_dropbox_client` flag (default `true`, flagged as smoke-test item).
  - `scripts/smoke-test.sh` finalized: all phase 1 + 2 checks plus `restic-backup.timer` active, `tailscale status` online, `nft list ruleset` includes expected chains, ss shows sshd bound only to loopback or Tailscale IP, `restic snapshots` lists at least one snapshot.
  - `docs/rollback.md` — `snapper rollback` single-command procedure.
  - `docs/recovery.md` — (a) local file recovery from `/srv/backups`, (b) file recovery from restic, (c) Tailscale-is-down LAN SSH recovery procedure (flip `nftables_allow_lan_ssh`), (d) full disaster recovery (reinstall + playbook + restic restore).
  - `docs/drift.md` — the config-file-to-template traceability checklist for PRD §9 Story 30.
  - **Acceptance runs:** every §9 acceptance criterion walked manually on the real SER8, ticked off in a `docs/acceptance.md` log.
  - **Dropbox client 24-hour soak:** run the client for 24 hours on encrypted btrfs. Pass → leave `install_dropbox_client: true`. Fail → flip to `false` permanently in `host_vars/beelink.yml`, document the decision.
- **What this phase does NOT include:** no v2 items — no preset self-hosted apps, no k3s, no preseed, no TPM2 unlock, no chezmoi, no distrobox. All parked in PRD §13.

### User-facing changes
- Nightly restic snapshots start appearing in the Dropbox repo.
- `restic snapshots` works from the command line.
- A deleted `~/testfile` can be recovered from local btrfs in seconds and from restic in minutes.

### Implementation notes
- Backup role depends on `base`, `storage`, and `lab` (for the Docker exclusion path). Role ordering already enforces this.
- Restic repository init is a one-shot — the role must be idempotent after init. Guard the init task on `stat` of the repo, not on a creation time attribute.
- Retention is enforced by a separate `restic forget --prune` timer, not inline with the backup. Two timers, two logs.
- The acceptance walk is not a ceremony — it's a gate. If any §9 criterion fails, it's a bug in the relevant phase, not a Phase 3 problem.

### Blocking dependencies
- Phase 2 complete (lab role landed, Docker exclusion path exists).
- Dropbox account + Plus tier available.
- Vaulted secrets populated: `dropbox_rclone_token`, `restic_passphrase`.

---

## Remaining work

Parked beyond Phase 3 (all per PRD §13, §6):

- Preset self-hosted apps (Vaultwarden, Immich, Nextcloud, Home Assistant, Jellyfin) — only when a concrete need appears.
- k3s / Kubernetes as an optional role — only when a product under test requires it.
- Preseed / custom ISO — only if a second machine or frequent reinstalls become reality.
- TPM2 auto-unlock via `systemd-cryptenroll` — only if unattended reboots are needed.
- chezmoi split for dotfiles — revisit after 6 months of use if templates become unwieldy.
- distrobox / devcontainers — only if host tooling creates conflicts.
- Hyprland / tiling WM — parked indefinitely.
- Restic retention tuning — revisit after one month of observed Dropbox usage.
- Traefik HTTPS via Tailscale certs — revisit when a test service requires browser-trusted TLS.

---

## Testing strategy

Aligned with PRD §11 and the phase-by-phase additions above.

**Per phase:**
- `ansible-playbook --syntax-check site.yml` as a pre-commit gate.
- `ansible-lint ansible/roles/<role>/` on each new role; errors blocking, warnings reviewed.
- `ansible-playbook --check --diff site.yml` on a converged UTM VM at the end of each phase — MUST report 0 changed tasks except for tasks explicitly marked `changed_when: false`.
- `scripts/smoke-test.sh` grows per phase; every assertion added in a phase must pass before the phase is considered done.

**Per role (pre-flight assertions that run on every playbook invocation):**
- `base`: non-Trixie → fail loudly with detected distro name. Required vars missing → fail. Apt `nodejs`/`npm` present → fail with purge instruction.
- `storage`: NVMe1 subvolumes don't match expected layout → fail with "re-check install.md" message.
- `security`: `ssh_authorized_keys` empty → fail.

**VM rehearsal gate:**
- Every phase is developed and proven green in a UTM VM clone of the post-P0 image before touching the SER8.
- Phase 1 rehearsal also validates the SSH loopback-then-tailnet staging in both states.

**No molecule, no CI, no matrix testing.** One machine, one operator.

**Acceptance walk (Phase 3 only):** every PRD §9 Given/When/Then is walked manually on the real SER8 and ticked in `docs/acceptance.md`.

---

## How to consume this plan

- **Where to start:** Phase 0. Do not skip the UTM rehearsal — every subsequent phase assumes `docs/install.md` is trustworthy.
- **Phase-to-issue breakdown:** feed this plan into the `plan-to-issues` skill. Each phase becomes a directory of tracer-bullet issues — one per role per phase, plus the cross-cutting smoke-test issue, plus the docs issues.
- **Avoid re-implementing:** every on-box configuration file is the output of a Jinja2 template under `ansible/roles/<role>/templates/`. If you catch yourself editing a file on the box, stop and edit the template instead. "Edit the playbook, not the box."
- **Re-running is safe:** the whole plan assumes `ansible-playbook -K site.yml` is idempotent from Phase 1 onward. Any phase that breaks this property is buggy, not an exception.
- **Secrets:** before running anything that touches vaulted content, populate `ansible/group_vars/all/vault.yml` via `ansible-vault edit` with `dropbox_rclone_token`, `restic_passphrase`, and optionally `tailscale_auth_key`.

---

## References

- [PRD.md](../ideas/debian-dev-lab/PRD.md) — requirements source of truth.
- [prd-input.md](../ideas/debian-dev-lab/prd-input.md) — original brainstorm + non-goals.
- PRD §5.13 — repo layout.
- PRD §10 — role decomposition and deep-module analysis.
- PRD §9 — acceptance criteria walked in Phase 3.
- PRD §11 — testing decisions.
- PRD §12 — risk mitigations.
