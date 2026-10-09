# Omarchy criticisms: what was published, what the code shows, and the rules for this repo

Research for [Research: Omarchy criticisms](https://github.com/iamivanhx/debian-setup/issues/28), part of the map [Hyprland dev environment refactor](https://github.com/iamivanhx/debian-setup/issues/26). Researched 2026-10-09.

**Question.** What security and implementation-quality criticisms have been published about Omarchy's install and update scripts? Which apply to this repo's design, and what rule would prevent each one here?

**Method.** Omarchy was read, never run. The reference is the head of its default branch `quattro` at [`988f44ea1a16`](https://github.com/basecamp/omarchy/tree/988f44ea1a16250785eee1c73cbaf558080589db) (2026-10-09). In this note, "pinned SHA" means that commit. Earlier code was read at the commits the critics cite, mainly [`1e859d37`](https://github.com/basecamp/omarchy/tree/1e859d37cb7fef6ac687442dc1fe515d01d1302d) (the v3.0.2 era). No Omarchy script was executed. The repo now redirects from `basecamp/omarchy` to `omacom/omarchy` ([v4.0.4 changelog link](https://github.com/basecamp/omarchy/releases/tag/v4.0.4)). Links here use `basecamp/omarchy`, and both names resolve.

Abbreviations used in links below: **@pin** is `https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/`, and **@v3** is `https://github.com/basecamp/omarchy/blob/1e859d37cb7fef6ac687442dc1fe515d01d1302d/`.

## Summary

- Published criticism comes in two waves. The first, in Oct–Nov 2025, was about defaults and Bash quality: the firewall didn't run, port 22 was open, sudo and faillock were loosened, the installer piped curl into a shell, and failed migrations could be skipped and marked done. The second, in Aug 2026 around v4.0, was about privilege: the user was in the `docker` group, which is root, and untrusted strings reached shells, Lua and sed. NOPASSWD helpers could be hijacked through `PATH`, and installed themes ran code.
- Omarchy has since fixed most of the specific defects, citing commits (see the table). What hasn't changed at the pinned SHA: `NOPASSWD` sudoers drop-ins still ship, `passwd_tries=10` and faillock `deny = 10` stay loosened, root's password is set to the user's, AUR packages update with `--noconfirm`, a dev-env path still pipes `curl | sh`, and an unsigned (`SigLevel = Never`) third-party repo is added for Apple T2 hardware.
- The critics' shared root cause holds up in the code: privileged, input-handling logic written as ad hoc Bash, with security fixed one injection at a time. The rules below aim at the cause, not the instances.
- Four of these patterns exist in this repo today. `modules/70-lab.sh` adds the user to `docker`, `modules/50-shell.sh` pipes the starship installer to `sh`, `modules/60-dev.sh` downloads lazydocker without verification, and the lab publishes ports 80/443 on all addresses. The migration plan has to remove them.
- The map's security baseline covers supply chain and the bootstrap well. It is silent on root-equivalent groups, untrusted-input handling, privileged files pointing at user-writable paths, authentication defaults, network exposure, temp-file handling, and script robustness. Proposed additions are listed under [Baseline coverage](#baseline-coverage-and-proposed-additions).

## Primary sources

| Source | Author | Date | What it covers |
|---|---|---|---|
| ["A Word on Omarchy"](https://xn--gckvb8fzb.com/a-word-on-omarchy/) | マリウス (Marius) | 2025-10-22, updated 2025-11-08 | Firewall, ssh, sudo/faillock, curl\|sh, migrations, error handling, quoting. Cites code at `1e859d37` and `38f5a00a`. |
| [Framework Community thread 77363](https://community.frame.work/t/omarchy-is-not-a-secure-distribution-and-should-be-taken-off-the-linux-installation-options/77363) | MayOrMayNotBeACat, with replies | 2025-11-03 | A bullet summary of Marius's post, plus rebuttals (jlnr, abittner, Adrian_Joachim). |
| [omarchy#2712](https://github.com/basecamp/omarchy/issues/2712) | MrJack91; comments by alerque (Arch packager) and ryanrhughes (Omarchy) | 2025-10-22 to 2026-07-18 | `[omarchy]` repo signed with `SigLevel = Optional TrustAll`. |
| [omarchy#1423](https://github.com/basecamp/omarchy/issues/1423) | jonwsoto | 2025-09-03 | `ufw` inactive after install. |
| ["Omarchy: Any User Process Can Escalate to Root"](https://0xcc.io/posts/omarchy-root-creds/) | 0xCC (no other name given) | 2026-08-28 | `docker` group made the user root-equivalent, from 2025-06 until v4.0.1. |
| ["Merchants of Insecurity"](https://happyfellow.bearblog.dev/merchants-of-insecurity/) | One Happy Fellow (blog, no other name given) | 2026-08-25 | Argues the v4.0 injection bugs are a process failure. Cites PRs #7847 and #7926. |
| Mehmet Ince, [mehmetince.net/omarchy](https://mehmetince.net/omarchy/) | Mehmet Ince | Aug 2026 | Two-click RCE via video title. The page is a live proof of concept, so its content is known here only through [PR #7847](https://github.com/basecamp/omarchy/pull/7847) and [PR #7926](https://github.com/basecamp/omarchy/pull/7926). |
| Jorrit Jongma (Chainfire), ["Omarchy Exploit" video](https://www.youtube.com/watch?v=pgNvD9DaZxY) | Jorrit Jongma | Aug 2026 | USB device name executed as Hyprland Lua. Not watched; known only through [PR #8129](https://github.com/basecamp/omarchy/pull/8129). |
| Omarchy release notes [v4.0.1](https://github.com/basecamp/omarchy/releases/tag/v4.0.1), [v4.0.2](https://github.com/basecamp/omarchy/releases/tag/v4.0.2), [v4.0.3](https://github.com/basecamp/omarchy/releases/tag/v4.0.3) | Omarchy maintainers | 2026-08-25 to 2026-09-08 | The project's own list of security fixes. The PR bodies give the defect in the maintainers' words. |

GitHub's security-advisories endpoint for the repo returns an empty list (`gh api repos/basecamp/omarchy/security-advisories` → `[]`). Fixes are announced in release notes, not as GHSAs or CVEs.

## Criticism traced to code

Each entry gives the claim, its source, the code that shows it, its status at the pinned SHA, and the rule for this repo (rules are numbered in [Design rules](#design-rules)).

### Supply chain

**S1. Piped install scripts (`curl | bash`).** Marius says software is installed "via `curl | sh`". The Framework thread repeats it, and jlnr there replies that Omarchy's Tailscale use follows Tailscale's own instructions.
- *Code then:* the documented bootstrap was `curl -fsSL https://omarchy.org/install | bash` (quoted from the manual in [omarchy#2654](https://github.com/basecamp/omarchy/issues/2654)). [@v3 `boot.sh`](https://github.com/basecamp/omarchy/blob/1e859d37cb7fef6ac687442dc1fe515d01d1302d/boot.sh) runs `rm -rf ~/.local/share/omarchy/`, clones `master` (or `$OMARCHY_REPO`/`$OMARCHY_REF` from the environment) and `source`s `install.sh`. [@v3 `bin/omarchy-install-tailscale`](https://github.com/basecamp/omarchy/blob/1e859d37cb7fef6ac687442dc1fe515d01d1302d/bin/omarchy-install-tailscale) piped two scripts into shells: `tailscale.com/install.sh | sh` and `neuralink.com/tsui/install.sh | bash`.
- *Pinned SHA:* setup is ISO-only ([`75cb4f71`](https://github.com/basecamp/omarchy/commit/75cb4f7195) "Make setup ISO-only", and there is no `boot.sh`). Tailscale comes from the package manager ([@pin `bin/omarchy-install-service-tailscale`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-install-service-tailscale)). One pipe remains: `curl -fsSL https://astral.sh/uv/install.sh | sh` at [@pin `bin/omarchy-install-dev-env#L73`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-install-dev-env#L73). `omarchy-upgrade-to-quattro` describes itself as runnable "directly with curl | bash on older systems" ([#L16](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-upgrade-to-quattro#L16)).
- *Rule:* R1, R2.

**S2. The distribution's own package repo did not require signatures.** Raised in [omarchy#2712](https://github.com/basecamp/omarchy/issues/2712). In that thread alerque (an Arch packager) argues that signing turns the two single points of failure (the build host and the package host) into two that must both be compromised. ryanrhughes (Omarchy) at first calls signing "a touch unnecessary" because there are no mirrors, then agrees to adopt it.
- *Code then:* `[omarchy] SigLevel = Optional TrustAll` (quoted in the issue, and in the migration below).
- *Fixed:* [`e66c27f1`](https://github.com/basecamp/omarchy/commit/e66c27f1e7) (2026-08-24, v4.0.2 "Require signed packages from the Omarchy repository"), via [@pin `migrations/1787589206.sh`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/migrations/1787589206.sh). A first attempt was reverted the same day ([`5afc9e14`](https://github.com/basecamp/omarchy/commit/5afc9e1495)). Unsigned packages were accepted for about ten months after the issue was filed.
- *Rule:* R1. The baseline covers this.

**S3. Third-party sources get no review on update.** Marius criticises continuous `yay -Syu` and mise bypassing the system package manager.
- *Pinned SHA:* `omarchy-update` runs `yay -Sua --noconfirm` over every foreign package ([@pin `bin/omarchy-update-aur-pkgs#L15`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-update-aur-pkgs#L15), called from [`bin/omarchy-update#L148`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-update#L148)). That builds unreviewed AUR PKGBUILDs. Marius's mise point conflicts with this map's baseline, which deliberately ranks mise third. It is recorded here, not adopted.
- *Rule:* R1, R9.

**S4. Fetched themes and plugins ran code.** Not raised by an outside critic. The maintainers' own PRs describe it.
- [PR #7884](https://github.com/basecamp/omarchy/pull/7884) ([`ef6d9e66`](https://github.com/basecamp/omarchy/commit/ef6d9e6605b121df15bf310e630e04f0c1119fc8)): "Installing a theme was the same act as running its author's code." Themes carried `*.lua`, terminal configs that name the program to launch, and a `vscode.json` that reaches `code --install-extension`.
- [PR #6694](https://github.com/basecamp/omarchy/pull/6694) ([`0ad64a59`](https://github.com/basecamp/omarchy/commit/0ad64a59df1c129cc08d183d5ccd857e3c7f36e9)): a `colors.toml` value broke out of a generated sed script and used GNU sed's `e` command to run shell.
- [PR #8067](https://github.com/basecamp/omarchy/pull/8067) and [PR #8174](https://github.com/basecamp/omarchy/pull/8174): git transport-helper URLs (`ext::`). These were defence in depth, and the PRs say no stock exploit existed.
- *Rule:* R3, R4. This matters for the map because it adopts a theme switcher.

### Privilege

**P1. The default user was in the `docker` group, which is root-equivalent.** Source: 0xCC. Docker's own documentation says "The `docker` group grants root-level privileges to the user" ([post-install docs](https://docs.docker.com/engine/install/linux-postinstall/)).
- *Code then:* [@v3 `install/config/docker.sh`](https://github.com/basecamp/omarchy/blob/1e859d37cb7fef6ac687442dc1fe515d01d1302d/install/config/docker.sh) runs `sudo usermod -aG docker ${USER}`. The timeline 0xCC gives checks out: added in [`25799ee9`](https://github.com/basecamp/omarchy/commit/25799ee91f) (2025-06-01), reverted in [`c5ee230d`](https://github.com/basecamp/omarchy/commit/c5ee230daf) (2025-06-02), re-added in [`fdd2aaf4`](https://github.com/basecamp/omarchy/commit/fdd2aaf4d1) (2025-06-17).
- *Fixed:* [PR #8056](https://github.com/basecamp/omarchy/pull/8056) ([`b5ded31e`](https://github.com/basecamp/omarchy/commit/b5ded31e2f9a86a15442e838f0e548346b91f375), 2026-08-24, v4.0.1). Group membership became opt-in behind a warning ([@pin `bin/omarchy-setup-security-sudoless-docker#L32`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-setup-security-sudoless-docker#L32)). 0xCC's `id` output also showed the `input` group, which gives raw read and write on `/dev/input`, so any user process can keylog. That grant was removed by [@pin `migrations/1787865477.sh`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/migrations/1787865477.sh) and [`df819a6f`](https://github.com/basecamp/omarchy/commit/df819a6f98) ("Close three paths from an unprivileged session to root").
- **Applies here today:** [`modules/70-lab.sh` L78–83](https://github.com/iamivanhx/debian-setup/blob/2b55230/modules/70-lab.sh#L78-L83) adds the user to `docker`, and its smoke test at L304 *requires* that membership.
- *Rule:* R5.

**P2. `NOPASSWD` helpers that could be hijacked.** These come from the v4.0.1 and v4.0.2 security items and their PR bodies.
- [PR #8172](https://github.com/basecamp/omarchy/pull/8172) ([`4637735a`](https://github.com/basecamp/omarchy/commit/4637735aa2e98851c68429df1a71b6c361760609)): the `NOPASSWD` `omarchy-dns` helper inherited a `secure_path` that included a user-writable checkout, so a planted `install` binary ran as root. The grant itself had been added six days earlier, to avoid a password prompt ([PR #7472](https://github.com/basecamp/omarchy/pull/7472)).
- [PR #8194](https://github.com/basecamp/omarchy/pull/8194) ([`0ae16948`](https://github.com/basecamp/omarchy/commit/0ae1694830b6bd9511042fe1b89a0062d8c083cb)): `NOPASSWD: /usr/bin/timedatectl set-timezone *`. The wildcard crosses argument boundaries, so `--host=` let root drive an SSH transport.
- The old Tailscale installer wrote `$USER ALL=(ALL) NOPASSWD: $(which tsui)` ([@v3 `bin/omarchy-install-tailscale`](https://github.com/basecamp/omarchy/blob/1e859d37cb7fef6ac687442dc1fe515d01d1302d/bin/omarchy-install-tailscale)).
- *Pinned SHA:* three narrowed `NOPASSWD` drop-ins still ship ([@pin `etc/sudoers.d/`](https://github.com/basecamp/omarchy/tree/988f44ea1a16250785eee1c73cbaf558080589db/etc/sudoers.d): `omarchy-dns`, `omarchy-tzupdate`, `omarchy-theme-browser`). There is also a user-facing `NOPASSWD: ALL` toggle with expiry, [@pin `bin/omarchy-sudo-passwordless`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-sudo-passwordless) (hardened as "OM-SEC-01" in [`87625c2a`](https://github.com/basecamp/omarchy/commit/87625c2ad8)).
- *Rule:* R6, R7. The baseline already forbids `NOPASSWD`, and [`modules/30-security.sh`](https://github.com/iamivanhx/debian-setup/blob/2b55230/modules/30-security.sh#L138-L165) enforces that today. Omarchy's history shows why the ban should stay absolute: every narrow grant was later widened by a bug.

**P3. Privileged files pointing into user-writable paths.** Source: [PR #9002](https://github.com/basecamp/omarchy/pull/9002) ([`943d2fcb`](https://github.com/basecamp/omarchy/commit/943d2fcbe91507e5efa1da8d80736b02032019d8)). Retired v3 installers wrote root-owned udev rules with an unquoted heredoc, so `RUN+=` held a literal `/home/<user>/.local/share/omarchy/bin/...`, which udev runs as root. The PR generalises this to sudoers entries and systemd `ExecStop=` lines naming user-writable paths. The FIDO2 case has the same shape: `pamu2fcfg >/tmp/fido2; sudo mv` left `/etc/fido2/fido2` owned by the user it authenticates ([PR #7904](https://github.com/basecamp/omarchy/pull/7904), [`23dab9ec`](https://github.com/basecamp/omarchy/commit/23dab9ec4d7179bb1e03a70ae942653f8daa8003)).
- *Rule:* R7, R8.

**P4. Authentication was loosened.** Source: Marius. Defenders in the Framework thread call three tries versus ten negligible.
- *Pinned SHA, unchanged:* `Defaults passwd_tries=10` ([@pin `etc/sudoers.d/omarchy-passwd-tries`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/etc/sudoers.d/omarchy-passwd-tries)). pam_faillock is set to `deny=10 unlock_time=120` ([@pin `install/config/increase-lockout-limit.sh`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/install/config/increase-lockout-limit.sh), [`etc/security/faillock.conf#L7`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/etc/security/faillock.conf#L7)).
- Marius says the installer accepted `install` as a password. At the pinned SHA the only check is non-empty ([@pin `install/provisioning/setup-form.sh#L124-L139`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/install/provisioning/setup-form.sh#L124-L139)), and one password is "Used for user + root, and disk encryption": `chpasswd` sets root's password to the user's ([@pin `bin/omarchy-provision-owner#L740-L741`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-provision-owner#L740-L741)). [PR #8046](https://github.com/basecamp/omarchy/pull/8046) removed `su -c "faillock --reset --user $USER"`, which handed an environment variable to a root shell, and names the shared root password as what made it dangerous.
- *Rule:* R10.

**P5. Coding agents launched in bypass mode.** Source: [PR #7001](https://github.com/basecamp/omarchy/pull/7001) ([`dd9dee41`](https://github.com/basecamp/omarchy/commit/dd9dee417f53a77487d93cfa21925bbc854ab104)). Claude launched with `bypassPermissions` and Codex with `--dangerously-bypass-approvals-and-sandbox`. Per that PR, other agents "keep their existing yolo-style flags". 0xCC lists AI coding agents among the processes that inherited the `docker` group.
- *Rule:* R5, R11.

### Defaults that weaken the system

**D1. The firewall was configured but not running.** Sources: [omarchy#1423](https://github.com/basecamp/omarchy/issues/1423) and Marius.
- *Code then:* [@v3 `install/first-run/firewall.sh`](https://github.com/basecamp/omarchy/blob/1e859d37cb7fef6ac687442dc1fe515d01d1302d/install/first-run/firewall.sh) ran at first run. A fix ([`0723059f`](https://github.com/basecamp/omarchy/commit/0723059fb3), 2025-09-03, "ensure that ufw is enabled") was not enough: Marius reports `ufw` still failed to autostart on v3.0.2 and that v3.1.0/3.1.1 fixed it.
- *Pinned SHA:* `ENABLED=yes` and `systemctl enable ufw` ([@pin `install/config/firewall.sh#L53-L54`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/install/config/firewall.sh#L53-L54)).
- *Rule:* R12. The lesson is that "enabled" was asserted and never checked.

**D2. Port 22 was open in the firewall, and sshd had no hardening.** Source: Marius and the Framework thread. abittner argues a developer distro should expose ssh.
- *Code then:* `sudo ufw allow 22/tcp` in [@v3 `install/first-run/firewall.sh`](https://github.com/basecamp/omarchy/blob/1e859d37cb7fef6ac687442dc1fe515d01d1302d/install/first-run/firewall.sh).
- *Fixed:* [PR #2887](https://github.com/basecamp/omarchy/pull/2887) ([`1060a54c`](https://github.com/basecamp/omarchy/commit/1060a54c1a23419e466d7833e0914855db43e376), 2025-10-27). sshd is now opt-in and key-only, and only that step opens the port, with `ufw limit 22/tcp` ([@pin `bin/omarchy-setup-security-sshd#L73`, `#L161`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-setup-security-sshd#L73)). v4.0.2 adds "Harden existing SSH installations and disable password authentication by default".
- *Pinned SHA:* LocalSend's 53317 tcp/udp is still open to any source ([@pin `install/config/firewall.sh#L6-L7`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/install/config/firewall.sh#L6-L7)). PR #2887's plan to limit it to the LAN was struck.
- *Rule:* R12.

**D3. Docker publishes ports past the host firewall.** Marius notes the manual claims Docker is locked down with ufw-docker. Docker documents that published ports are "diverted before it goes through the ufw firewall settings" ([packet filtering docs](https://docs.docker.com/engine/network/packet-filtering-firewalls/)) and that "Publishing container ports is insecure by default" because they bind to all host addresses ([port publishing docs](https://docs.docker.com/engine/network/port-publishing/)).
- *Pinned SHA:* Omarchy installs ufw-docker rules ([@pin `install/config/firewall.sh#L13-L50`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/install/config/firewall.sh#L13-L50)). Doing so needs a shim that fakes `ufw status` and a `sed`-patched copy of the packaged `ufw-docker`.
- **Applies here today:** the lab's Traefik publishes `"80:80"` and `"443:443"` with no host address ([`templates/srv/data/lab/compose/traefik/docker-compose.yml` L20–22](https://github.com/iamivanhx/debian-setup/blob/2b55230/templates/srv/data/lab/compose/traefik/docker-compose.yml#L20-L22)). `daemon.json` sets no `"ip"` ([template](https://github.com/iamivanhx/debian-setup/blob/2b55230/templates/etc/docker/daemon.json)), and [`templates/etc/nftables.conf`](https://github.com/iamivanhx/debian-setup/blob/2b55230/templates/etc/nftables.conf) opens with `flush ruleset` and drops all forwarding. This note did not establish how that ruleset and Docker's own rules interact (see Gaps).
- *Rule:* R12.

**D4. Autologin and a passwordless keyring.** No critic raised these as security issues. The code shows them.
- On encrypted installs SDDM autologin is permanent, with the LUKS prompt as "the auth boundary" ([@pin `bin/omarchy-provision-owner#L773-L782`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-provision-owner#L773-L782)).
- The default GNOME keyring is created with no password ([@pin `install/user/default-keyring.sh`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/install/user/default-keyring.sh)), so stored app secrets are protected only by disk encryption and file mode 600.
- [omarchy#8963](https://github.com/basecamp/omarchy/issues/8963) (open) reports the Quattro upgrade turning on autologin by surprise.
- *Rule:* R13. This is flagged for the desktop composition ticket.

### Script robustness

**R-a. Error handling was lost in subshells.** Source: Marius. `install.sh` sets `set -eEo pipefail`, but `run_logged` ran each script as `bash -c "source '$script'"`, which does not inherit those options ([@v3 `install/helpers/logging.sh#L114-L134`](https://github.com/basecamp/omarchy/blob/1e859d37cb7fef6ac687442dc1fe515d01d1302d/install/helpers/logging.sh#L114-L134)). *Fixed:* the runner is now `bash -eE` ([@pin `install/helpers/logging.sh#L54`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/install/helpers/logging.sh#L54)). *Rule:* R14.

**R-b. A failed migration could be skipped and recorded.** Source: Marius, citing [`38f5a00a` `bin/omarchy-migrate`](https://github.com/basecamp/omarchy/blob/38f5a00ad6d84c10180a1012575997a28d952e1c/bin/omarchy-migrate). That code ran `bash $file` (unquoted, without `-e`) and on failure offered "Skip and continue?", which marked the migration skipped for good. *Fixed:* skipping is gone by [`75cb4f71`](https://github.com/basecamp/omarchy/commit/75cb4f7195) (2026-06-04). At the pinned SHA each migration runs under `bash -euo pipefail` and is marked done only on success ([@pin `bin/omarchy-migrate#L93-L95`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-migrate#L93-L95)).
- *Still true at the pinned SHA:* the update prompt shows no list of what will run, only "Ready to update?" and a link to release notes ([@pin `bin/omarchy-update-confirm`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-update-confirm)).
- Migration state is per user (`$HOME/.local/state/omarchy/migrations`) even though 44 of the 149 migrations call `sudo` on system state. One migration notes that "Fresh installs stamped 1780517689 and 1784763917 as applied without running them" ([@pin `migrations/1785166747.sh`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/migrations/1785166747.sh)).
- *Rule:* R14, R15, and the baseline's "show what they will run".

**R-c. Migrations are not idempotent and have no rollback.** Source: Marius. Many current migrations are guarded, or call idempotent helpers such as `omarchy-pkg-add`. 24 of the 149 have no conditional of their own and rely on those helpers. Rollback is still a Snapper snapshot taken before the update, and a failed snapshot only warns ([@pin `bin/omarchy-update#L115`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-update#L115)). Marius's specific claim that `1752104271.sh` chained five commands in one `if` was not re-checked. *Rule:* R15.

**R-d. Untrusted strings were interpolated into code.** Marius showed word-splitting breakage with a theme named `hello\ world`. The v4.0 bugs are the security form of the same habit:
- a video title became an mpv option via a notification click action ([PR #7847](https://github.com/basecamp/omarchy/pull/7847), [`b71c60fe`](https://github.com/basecamp/omarchy/commit/b71c60fe3044fcb778b564819d99e5330d22e9f3));
- notification actions were shell strings run through `bash -lc` ([PR #7926](https://github.com/basecamp/omarchy/pull/7926), [`43bfe9b9`](https://github.com/basecamp/omarchy/commit/43bfe9b9d82ba650b5b80eef79e94776790801c9));
- a USB product name was written into Lua that Hyprland sources, even on a locked session ([PR #8129](https://github.com/basecamp/omarchy/pull/8129), [`9285b19d`](https://github.com/basecamp/omarchy/commit/9285b19d6a72eba3df8537d62a4cd5506a803d89));
- theme colours went into sed and `python3 -c` ([PR #6694](https://github.com/basecamp/omarchy/pull/6694));
- `$USER` went into `su -c` ([PR #8046](https://github.com/basecamp/omarchy/pull/8046));
- more shell injection in theme and application installers is listed in the [v4.0.2 notes](https://github.com/basecamp/omarchy/releases/tag/v4.0.2).

"Merchants of Insecurity" draws the general conclusion. *Rule:* R3.

**R-e. Predictable temp paths and ownership carried into root-owned files.** Source: [PR #7904](https://github.com/basecamp/omarchy/pull/7904) (see P3). *Rule:* R8.

## Additional code findings (not traced to a published criticism)

These come from reading the pinned SHA. No outside critic raised them, so they are kept apart from the criticism above.

- **An unsigned third-party repo is added on Apple T2 hardware.** `[arch-mact2]` points at an individual's GitHub-releases mirror with `SigLevel = Never` ([@pin `install/hardware/pacman.sh#L7-L9`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/install/hardware/pacman.sh#L7-L9)). The same release that required signatures for `[omarchy]` left this repo unsigned. The baseline's "No unsigned third-party apt repos" covers the equivalent here.
- **AUR packages update without review**, via `yay -Sua --noconfirm` (S3).
- **The update log is written to a fixed path, `/tmp/omarchy-update.log`** ([@pin `bin/omarchy-update#L88`](https://github.com/basecamp/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-update#L88)). It is written as the user, not root, so the impact is low. It is the same pattern as R-e.

## Hearsay and claims not traced to code

- **"Omarchy does not make use of security mechanisms built into the kernel"** ([Framework thread](https://community.frame.work/t/omarchy-is-not-a-secure-distribution-and-should-be-taken-off-the-linux-installation-options/77363)). No file or commit is cited, and this note did not audit LSM or kernel configuration. v4.0.4 now ships a custom `linux-omarchy` kernel ([release notes](https://github.com/basecamp/omarchy/releases/tag/v4.0.4)), whose configuration was not read.
- **The DHH post on X** that "Merchants of Insecurity" cites as overstating the security team's work. It was not read, because X is not reachable without an account.
- **Secondary write-ups** (thecybersecguru.com, codetocloud.io, biggo.com, the 1Password community thread, a Korean-language summary) restate the primary sources above. They are not cited for any claim. The "433 days" exposure figure from one of them matches the commit dates: [`fdd2aaf4`](https://github.com/basecamp/omarchy/commit/fdd2aaf4d1) on 2025-06-17 to [`b5ded31e`](https://github.com/basecamp/omarchy/commit/b5ded31e2f9a86a15442e838f0e548346b91f375) on 2026-08-24.
- **Mehmet Ince's page and Chainfire's video** were not read or watched. Their content is taken from the maintainers' PR descriptions, which link them as the public reports.
- **Off-scope items in Marius's post**, not pursued: the screensaver is not a lock, the Chromium privacy defaults, `telnet` being installed, and the ISO size.

## Design rules

These are the rules that would have prevented the criticisms above here. Each names the criticisms it answers.

- **R1. No unverified code from the network.** Sources follow the baseline order: Debian, backports, mise, upstream release. Every upstream artifact is checked against a published checksum or signature and the run stops on failure. Signed apt repos only. (S1, S2, S3)
- **R2. No piped installers anywhere.** This covers vendor `install.sh` scripts for tools as well as the bootstrap: no `curl | sh`, no `source <(curl …)`. When a vendor offers only a script, download a release asset instead, or leave the tool out. (S1)
- **R3. Untrusted input is data, never code.** Window titles, notification text, device names, file names, theme files, git URLs and environment variables never reach `eval`, `bash -c`, `sh -c`, `su -c`, sed scripts, Lua, or generated config. Commands are built as argv arrays, `--` goes before operands, and values are checked against an allow-pattern before use. `$USER` and `$HOME` are never trusted in a privileged step; use `id -un` and `getent`. (S4, R-d, P4)
- **R4. Fetched assets are never executable config.** Themes and other user-installed assets are restricted to colour and image data. The switcher writes only data the repo's own templates consume, and never copies `*.lua`, shell, or program-launching config from a theme. (S4)
- **R5. No root-equivalent group memberships by default.** That means `docker`, `input`, `disk`, `kvm`, `libvirt`, `lxd` and the like. Use rootless Docker or Podman, or `sudo docker`. A group grant is an explicit, separately named opt-in. (P1, P5)
- **R6. No `NOPASSWD`, no exceptions.** This is the existing baseline. Omarchy's narrow grants were widened by wildcards and `PATH`, so a narrowed grant is no safer. (P2)
- **R7. Privileged code takes no input from user-writable locations.** Anything that runs as root sets a fixed `PATH`. Sudoers entries, udev `RUN+=`, systemd units, polkit rules and pacman/apt hooks name only root-owned paths (`/usr/…`, `/etc/…`), never `$HOME`, the repo checkout, or a symlink the user owns. Root-owned files are written with `install -o root -g root -m …` from a quoted heredoc or a template. (P2, P3)
- **R8. Temp files come from `mktemp`.** Nothing is staged at a fixed `/tmp` path, and nothing staged by the user is `mv`'d into `/etc`. (P3, R-e)
- **R9. Updates are reviewable.** An update shows the package changes and the list of migrations (names and file paths) before it runs, and has no `--noconfirm` over third-party build recipes. This is the existing baseline, applied to packages as well as migrations. (S3, R-b)
- **R10. Authentication defaults are never loosened.** Keep Debian's sudo `passwd_tries` (3) and lockout behaviour, keep the root account locked, and never set root's password to the user's. (P4)
- **R11. Agents run without permission bypass.** Coding agents launched from menus or keybindings never use permission-bypass or sandbox-disable flags. (P5)
- **R12. Network exposure is stated and verified.** Inbound is default-deny. Every open port is listed with its reason and source restriction. sshd is key-only. Docker binds published ports to `127.0.0.1` by default (`"ip": "127.0.0.1"` in `daemon.json`), and LAN exposure is a deliberate per-service choice. A smoke check proves the firewall is *active* and that no listening socket is reachable beyond what the list allows; being enabled is not enough. (D1, D2, D3)
- **R13. Login and secret storage are deliberate.** Autologin, screen lock and keyring encryption are recorded decisions with stated trade-offs, not side effects of an installer. (D4)
- **R14. Every script runs strict.** Each script runs as its own process under `set -Eeuo pipefail`, and no wrapper drops those options (no `bash -c "source …"`). A failed step stops the run and is never recorded as done or skipped. (R-a, R-b)
- **R15. Migrations are idempotent and their state is honest.** Every migration is safe to re-run. Migration state that changes the system is kept system-wide (under `/var/lib`), separate from per-user state. A snapshot or backup taken before an update is a precondition: if it fails, the update stops. (R-b, R-c)

### Mapping and baseline coverage

| Criticism | Rule(s) | Map baseline covers it? | This repo today ([`2b55230`](https://github.com/iamivanhx/debian-setup/tree/2b55230)) |
|---|---|---|---|
| S1 curl\|bash | R1, R2 | **Partly.** The bootstrap is covered ("Never a piped script"). Vendor install scripts are implied by "verified … stop on a failed check" but not named. | **Violates:** [`modules/50-shell.sh` L45–52](https://github.com/iamivanhx/debian-setup/blob/2b55230/modules/50-shell.sh#L45-L52) pipes `starship.rs/install.sh` to `sh`, and only warns on failure. |
| S2 unsigned repo | R1 | **Yes** ("No unsigned third-party apt repos"). | Docker's apt repo is signed ([`docker.sources`](https://github.com/iamivanhx/debian-setup/blob/2b55230/templates/etc/apt/sources.list.d/docker.sources)), but the baseline's source order doesn't list signed third-party apt repos at all (see Gaps). |
| S3 unreviewed third-party updates | R1, R9 | **Yes** ("never fetch and run code that hasn't been reviewed"). | n/a |
| S4 themes/plugins run code | R3, R4 | **Partly.** "Never fetch and run code" is written about migrations and updates, not user-installed assets. | n/a (no theme switcher yet) |
| P1 `docker`/`input` group | R5 | **No.** "Nothing gets standing root" doesn't name group membership, and a reader would not read `docker` as root. | **Violates:** [`modules/70-lab.sh` L78–83](https://github.com/iamivanhx/debian-setup/blob/2b55230/modules/70-lab.sh#L78-L83). |
| P2 NOPASSWD helpers | R6, R7 | **Yes** for NOPASSWD. **No** for `PATH` hygiene. | Complies: no NOPASSWD, enforced in `30-security.sh`. |
| P3 privileged files → user-writable paths | R7, R8 | **No.** | Not audited here. |
| P4 loosened auth, shared root password | R10 | **No.** | Not audited here. |
| P5 agents in bypass mode | R11 | **No.** | n/a |
| D1 firewall not running | R12 | **No.** The baseline is silent on network exposure. | `30-security.sh` has an nftables smoke check; whether it proves the ruleset is *loaded* was not checked. |
| D2 ssh open, unhardened | R12 | **No.** | sshd is LAN-only in the nftables template. |
| D3 Docker ports bypass the firewall | R12 | **No.** | **At risk:** Traefik publishes 80/443 on all addresses, there is no `"ip"` in `daemon.json`, and the interaction with `flush ruleset` is unverified. |
| D4 autologin, passwordless keyring | R13 | **No.** "Secrets … never world-readable" covers repo secrets, not desktop credential storage. | n/a (GNOME today) |
| R-a/R-b error handling, skip-on-fail | R14 | **No.** | `run.sh` sets `set -euo pipefail`. Per-module behaviour was not audited. |
| R-c idempotency, rollback | R15 | **No.** | Modules are guard-based (`lib/guards.sh`). There is no pre-update snapshot. |
| R-d injection | R3 | **No.** | Not audited here. |
| R-e temp files | R8 | **No.** | `60-dev.sh` uses `mktemp -d` correctly. |
| (code) unverified upstream download | R1 | **Yes** ("verified … stop on a failed check"). | **Violates:** [`modules/60-dev.sh` L100–112](https://github.com/iamivanhx/debian-setup/blob/2b55230/modules/60-dev.sh#L100-L112) downloads lazydocker with no checksum, warns and continues on failure, and hard-codes `Linux_x86_64` (so it breaks the arm64 VM). |

### Baseline coverage and proposed additions

The baseline doesn't cover these. They are proposals for the human to accept or reject, not changes to the map:

1. **No root-equivalent groups.** Name `docker`, `input` and similar groups as standing root, and use rootless or sudo-gated Docker. (R5)
2. **Untrusted input never becomes code**, and fetched assets (themes, plugins) are data only. (R3, R4)
3. **Privileged files and helpers take nothing from user-writable paths**: a fixed `PATH`, root-owned targets only, and `mktemp` for staging. (R7, R8)
4. **Authentication is never loosened**: keep sudo and lockout defaults, and keep root locked. (R10)
5. **Network exposure is listed and verified**: default-deny, an allowlist of ports with reasons, key-only sshd, Docker published ports bound to loopback unless a service is deliberately exposed, and a smoke check that the firewall is active. (R12)
6. **Script robustness**: strict mode in every script with no wrappers that drop it, no "skip and mark done", idempotent migrations with system-wide state, and a snapshot or backup before updates that fails closed. (R14, R15)
7. **Make "no piped installers" explicit for tools, not only the bootstrap.** (R2) This tightens an existing line rather than adding a new one.

R11 (agents) and R13 (login and keyring) are probably better settled in the desktop composition and macOS inventory tickets than in the baseline.

## Gaps

- **Docker and nftables on this repo's SER8 config.** This note did not establish whether `templates/etc/nftables.conf` (`flush ruleset`, `inet filter` forward `policy drop`) blocks, allows, or is wiped by Docker's iptables-nft rules for published ports. Recent commits mention "docker iptables init" self-heals. The way to settle it is a VM test that scans from another host, not a source read.
- **Docker's apt repo and the baseline.** The baseline lists Debian, backports, mise and upstream releases, and forbids *unsigned* third-party apt repos. It doesn't say whether a *signed* third-party apt repo (Docker CE, used today) is allowed. The repo architecture ticket should decide.
- **The exact commit that fixed `ufw` autostart.** Marius's update attributes it to v3.1.0/3.1.1. [`0723059f`](https://github.com/basecamp/omarchy/commit/0723059fb3) is an earlier attempt that he says was insufficient. The 3.1.x commit was not identified.
- **When "skip failed migration" was removed.** It was gone by `75cb4f71` (2026-06-04). The earlier commit that removed it was not identified.
- **Where `tsui`'s old installer put the binary.** That decides whether the old `NOPASSWD: $(which tsui)` grant pointed at a user-writable path. The neuralink installer was not fetched, and the claim is not made.
- **Kernel and LSM hardening claims** (Framework thread) and the configuration of the new `linux-omarchy` kernel were not audited.
- **Omarchy's disclosure page** ([omarchy.org/security](https://omarchy.org/security/)) and its security team page were not read. This note assumes nothing about their process beyond the release notes.
- **This repo's own exposure to P3, P4, R-d and R-e** was not audited. The table marks those cells "not audited". A short audit of `modules/` against R3, R7, R8 and R10 would close them.
- **Mehmet Ince's write-up and Chainfire's video** were taken only through the maintainers' PR descriptions (see Hearsay).
