# Research: Omarchy and omadeb architecture

Ticket: [Research: Omarchy and omadeb architecture](https://github.com/iamivanhx/debian-setup/issues/27), part of the map [Hyprland dev environment refactor](https://github.com/iamivanhx/debian-setup/issues/26).

**Question.** How do Omarchy and omadeb implement the six patterns this map adopts (theme switcher, migrations, `bin/` command suite, config layering, one-line bootstrap with a self-updating clone, setup menu), plus the update command and the manual? How does omadeb adapt Omarchy to Debian?

Both projects are **reference only** for this map (see the map's Notes). Nothing below is a recommendation to copy code. The last section measures each mechanism against the map's security baseline.

## Sources and pinned commits

Every claim cites a file at one of these commits. Line anchors are against that commit.

| Label | Repo | Commit | What it is |
| --- | --- | --- | --- |
| **Omarchy 4** | [omacom/omarchy](https://github.com/omacom/omarchy) (default branch `quattro`) | [`988f44ea`](https://github.com/omacom/omarchy/tree/988f44ea1a16250785eee1c73cbaf558080589db), 2026-10-09 | Current head. The v4.x line (latest release `v4.0.4`, 2026-09-15). Ships as Arch packages. |
| **Omarchy 3** | same repo, tag `v3.8.4` | [`8fcc9d60`](https://github.com/omacom/omarchy/tree/8fcc9d6048af4cb0e3af8512c78049857a3b53dd), 2026-07-20 | The last git-clone release, with `boot.sh` and `install.sh` at the root. |
| **omadeb** | [omakasui/omadeb](https://github.com/omakasui/omadeb) (`main` = `dev` = tag `v1.4.3`) | [`654f5964`](https://github.com/omakasui/omadeb/tree/654f5964cf212483df5b3c1b2a9a15ac9a115ab4), 2026-10-02 | Debian trixie and GNOME. |
| **omadeb site** | [omakasui/omadeb.omakasui.org](https://github.com/omakasui/omadeb.omakasui.org) | [`4af2ee5a`](https://github.com/omakasui/omadeb.omakasui.org/tree/4af2ee5acbf60fac8071fc5352786ce38fb2216f) | The omadeb manual site. |

`github.com/basecamp/omarchy` now redirects to `omacom/omarchy`; the GitHub API reports `full_name: omacom/omarchy`, default branch `quattro`.

### The finding that frames everything else

The ticket asks about `boot.sh` and `install.sh`. **Current Omarchy no longer has them.** Omarchy 4 replaced the git-clone model with Arch packages built from the repo. A separate `omarchy-pkgs` repo holds the PKGBUILDs, and an ISO installs the system ([`docs/file-layout.md` L6-31](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/docs/file-layout.md#L6-L31); [`manual/02-getting-started.md` L3-5](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/manual/02-getting-started.md#L3-L5); [`agents/skills/install-scripts.md`](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/agents/skills/install-scripts.md): "The ISO owns installation orchestration"). Existing v3 installs move over through [`bin/omarchy-upgrade-to-quattro`](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-upgrade-to-quattro).

So there are three designs to learn from:

1. **Omarchy 3**: a git clone in `~/.local/share/omarchy`, updated with `git pull`. This is the model the map's "one-line bootstrap with a self-updating clone" describes.
2. **Omarchy 4**: packages under `/usr/share/omarchy`, user defaults seeded from `/etc/skel`, and a hardened update pipeline. A git checkout survives only as the `dev` channel ("dev-link").
3. **omadeb**: a near-verbatim port of the **Omarchy 3** design to Debian and GNOME. It has no Hyprland.

## 1. Install flow

### Omarchy 3

- **Entry.** [`boot.sh`](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/boot.sh) is meant to be fetched with curl. It picks a pacman mirror from `OMARCHY_REF` (stable/rc/edge) and writes `/etc/pacman.d/mirrorlist`. It then installs `git`, runs `rm -rf ~/.local/share/omarchy/`, clones `OMARCHY_REPO` at `OMARCHY_REF` into that path, and `source`s `install.sh` (L22-48). `OMARCHY_REPO` and `OMARCHY_REF` are environment overrides, used for forks and branches.
- **Phases.** [`install.sh` L4-18](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/install.sh#L4-L18) sets `set -eEo pipefail` and exports `OMARCHY_PATH`, `OMARCHY_INSTALL`, `OMARCHY_INSTALL_LOG_FILE=/var/log/omarchy-install.log` and `PATH`. It then sources six phases in this order: `helpers/`, `preflight/`, `packaging/`, `config/`, `login/`, `post-install/`. Each phase is an `all.sh` that lists its leaf scripts in execution order, for example [`install/config/all.sh`](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/install/config/all.sh) (about 70 leaves, hardware quirks included).
- **Leaf runner.** `run_logged` ([`install/helpers/logging.sh` L114-134](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/install/helpers/logging.sh#L114-L134)) runs each leaf as `bash -c "source '$script'"` with stdin from `/dev/null` and all output appended to the install log. It logs Starting, Completed or Failed with timestamps and returns the exit code. A background loop tails the log on screen (L1-53).
- **Error handling.** [`install/helpers/errors.sh`](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/install/helpers/errors.sh) traps `ERR INT TERM` into `catch_errors` and `EXIT` into `exit_handler` (L159-160). `catch_errors` prints the log tail, the failed script (`$CURRENT_SCRIPT`) and the exit code. It then offers Retry (re-runs the whole `install.sh`), Upload log, View log, or Exit (L76-143).
- **Preflight guards.** [`install/preflight/guard.sh`](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/install/preflight/guard.sh) checks for vanilla Arch, not root, x86_64, Secure Boot off, no GNOME or KDE, limine, and a btrfs root. Each failure is only a `gum confirm` "proceed anyway".
- **Idempotency.** The install is not idempotent as a whole. `boot.sh` deletes and re-clones the checkout. `config/config.sh` runs `cp -R` over all of `config/*` into `~/.config` and overwrites `~/.bashrc` ([L1-6](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/install/config/config.sh#L1-L6)). Retry works by running everything again. Individual leaves are written to tolerate re-runs, but nothing records which phases have finished.
- **Migration baseline.** [`install/preflight/migrations.sh`](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/install/preflight/migrations.sh) `touch`es a state marker for every shipped migration, so a fresh install never runs historical migrations.
- **First run.** [`install/preflight/first-run-mode.sh` L5-16](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/install/preflight/first-run-mode.sh#L5-L16) writes `/etc/sudoers.d/first-run` with `NOPASSWD` for `systemctl`, `ufw` and others, so post-login steps can run unattended. A cleanup command removes it later.

### Omarchy 4

- The ISO installs the packages (`install/omarchy-base.packages`, `omarchy-other.packages`). Inside the chroot it runs `omarchy-apply-system` as root, which sources `install/config/all.sh`, `install/hardware/all.sh` (through `omarchy-apply-hardware`), `install/login/all.sh` and `install/post-install/all.sh`. It then runs `omarchy-provision-user --force --first-install` as the user ([`docs/file-layout.md` L201-227, L303-322](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/docs/file-layout.md#L303-L322)).
- **Three layers populate `$HOME`** (L33-48):
  1. Seed: `/etc/skel` from the `omarchy-settings` package.
  2. Finalize: `omarchy-provision-user`, run once per user, which does what needs `$HOME` or live state.
  3. Resync: `omarchy-reinstall-configs`, an explicit and destructive `cp -af /etc/skel/. ~/`.
- **Idempotency** is now explicit through completion markers under `~/.local/state/omarchy/done/`, managed by `omarchy-done check|mark|ensure`. First-run has one marker and retries at the next login if it fails (L263-301).
- **Root versus user split.** Root-side leaves live under `install/{config,hardware,login,post-install}`, per-user leaves under `install/user/`. Leaves are sourced through `run_logged` and carry no shebang ([`agents/skills/install-scripts.md`](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/agents/skills/install-scripts.md)).

### omadeb

- **Entry.** The manual's install command is `curl -fsSL https://omadeb.omakasui.org/install | bash` ([site `docs/03-setup/01-installation.md`](https://github.com/omakasui/omadeb.omakasui.org/blob/4af2ee5acbf60fac8071fc5352786ce38fb2216f/docs/03-setup/01-installation.md)). That URL serves a one-liner, `eval "$(curl -fsSL https://raw.githubusercontent.com/omakasui/omadeb/main/boot.sh)"` ([site `public/install`](https://github.com/omakasui/omadeb.omakasui.org/blob/4af2ee5acbf60fac8071fc5352786ce38fb2216f/public/install)).
- [`boot.sh`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/boot.sh) runs `apt-get install git`, then `rm -rf ~/.local/share/omadeb`. It clones `OMADEB_REPO`, checks out `OMADEB_REF` (default `main`) and maps `dev` to the dev channel, everything else to stable. Finally it sources `install.sh` (L18-46). `OMADEB_BRAND` re-labels the whole install, which is how omadeb serves as a base for other brands.
- [`install.sh`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install.sh) has the same six phases in the same order as Omarchy 3, with `OMADEB_*` variables.
- **The Debian-specific parts:**
  - [`install/preflight/guard.sh`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/preflight/guard.sh) checks `ID=debian`, `VERSION_ID >= 13`, x86_64 and `XDG_CURRENT_DESKTOP=GNOME`.
  - [`install/helpers/mirror.sh`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/helpers/mirror.sh) repairs a broken apt configuration. It writes a deb822 `debian.sources` for trixie, trixie-updates and trixie-security when no debian.org source exists (L6-40). It then calls `omadeb-refresh-apt` to add the **Omakasui APT repos** (L42-44).
  - Packages are installed with `apt-get` through `omadeb-pkg-add`, which re-checks `dpkg-query` because apt sometimes exits 0 without installing ([`bin/omadeb-pkg-add`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-pkg-add)).
  - GNOME is configured with `gsettings` scripts under `install/config/gnome/`.
- **First run.** The same `NOPASSWD` sudoers drop-in as Omarchy 3, plus a systemd `--user` oneshot unit that runs `omadeb-first-run` at the next login and disables itself ([`install/preflight/first-run-mode.sh`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/preflight/first-run-mode.sh)).

**Trade-offs.** The phase/`all.sh`/`run_logged` structure is cheap and readable. The order is explicit, each leaf's output is captured, and the failing script is named. Its weaknesses are a retry that re-runs everything (no per-phase checkpoint), `rm -rf` plus re-clone at the entry point, and guards that only warn. Omarchy 4's `omarchy-done` markers and seed/finalize/resync split are the more mature answer to idempotency.

## 2. Config layering

The pattern is the same in all three projects. Owned defaults are **sourced or included in place** from the install tree, never copied. User-editable files are **copied once** into `~/.config`, and they include the defaults first and the user's overrides after.

### Omarchy 3

- **`config/`** is copied wholesale to `~/.config` at install ([`install/config/config.sh`](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/install/config/config.sh#L1-L6)). After that the user owns those files.
- **`default/`** stays in the clone and is referenced by path. [`config/hypr/hyprland.conf` L3-23](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/config/hypr/hyprland.conf#L3-L23) shows the full stack:
  1. `source = ~/.local/share/omarchy/default/hypr/*.conf` (the defaults, "don't edit these directly")
  2. `source = ~/.config/omarchy/current/theme/hyprland.conf` (the active theme)
  3. `source = ~/.config/hypr/{monitors,input,bindings,looknfeel,autostart}.conf` (user overrides)
  4. `source = ~/.local/state/omarchy/toggles/hypr/*.conf` (runtime toggle flags)

  The shell works the same way: `~/.bashrc` sources `default/bash/rc`.
- **Survival across updates.** `git pull` changes `default/`, so improved defaults reach the user immediately and user override files are never touched. A new default for a *user-owned* file reaches existing users only through a **migration** or an explicit `omarchy-refresh-<thing>`. [`bin/omarchy-refresh-config`](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/bin/omarchy-refresh-config#L20-L44) copies `config/<path>` over `~/.config/<path>`. It first takes a timestamped `.bak.<epoch>` backup, deletes the backup if nothing changed, and otherwise prints the diff.
- **Copy versus symlink versus source.** Defaults are sourced. User files are copied. Theme outputs are linked: `~/.config/btop/themes/current.theme` and `~/.config/mako/config` are symlinks into `~/.config/omarchy/current/theme/` ([`install/config/theme.sh` L16-21](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/install/config/theme.sh#L16-L21)).

### Omarchy 4

- The same three tiers, relocated. Defaults are package-owned under `/usr/share/omarchy/default/**`. User files are seeded from `/etc/skel/.config/**`, with `/usr/share/omarchy/config/**` kept as the source for resyncing. Generated state lives in `~/.local/state/omarchy/current/` ([`docs/file-layout.md` L57-139](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/docs/file-layout.md#L57-L139)). `~/.config/omarchy/` is reserved for files "a user may intentionally version in a dotfile manager" (L57-60).
- Hyprland moved to Lua. [`config/hypr/hyprland.lua`](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/config/hypr/hyprland.lua) runs `dofile($OMARCHY_PATH/default/hypr/bootstrap.lua)`, then `require("default.hypr.omarchy")`, then `require("hypr.monitors")` and the other user files, then the toggles.
- Where an app supports a system config layer, Omarchy 4 uses it. Kitty reads `/etc/xdg/kitty/kitty.conf` (package-owned) before the user file (L361-363).
- Upstream-owned `/etc` files Omarchy must change ship under `/usr/share/omarchy/etc-overrides/` and are force-copied into place on every upgrade. The doc says outright that this "clobbers" user edits (L143-154).
- The manual states the rule users see: `~/.config` is yours, `/usr/share/omarchy` is Omarchy's, so override there rather than edit here ([`manual/31-dotfiles.md`](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/manual/31-dotfiles.md)).

### omadeb

- Identical to Omarchy 3. [`install/config/config.sh`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/config/config.sh) runs `cp -R` over `config/*` into `~/.config`. [`default/bashrc`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/default/bashrc) sources `~/.local/share/omadeb/default/bash/rc` and leaves room for user additions. `omadeb-refresh-config` is the Omarchy 3 script with the name changed.
- **GNOME has no include mechanism**, so desktop settings are not layered at all. They are imperative `gsettings` writes in `install/config/gnome/*.sh`. "Restore defaults" means re-running those scripts ([`bin/omadeb-refresh-gnome`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-refresh-gnome)). Hyprland's `source`/`require` makes layering much cleaner than GNOME does, which is good news for this map.

**Trade-offs.** Defaults sourced in place mean updates land without touching user files. The cost is that the install path is baked into user files: Omarchy 3 hard-codes `~/.local/share/omarchy/...`, and Omarchy 4 reads `$OMARCHY_PATH`. Copied user files drift silently from new defaults; the only reconciliation is a migration or a manual `refresh-*` with backup and diff.

## 3. Theme system

### What a theme folder contains

- **Omarchy 3**, for example [`themes/tokyo-night/`](https://github.com/omacom/omarchy/tree/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/themes/tokyo-night): `colors.toml` (the palette), `backgrounds/`, `btop.theme`, `icons.theme`, `keyboard.rgb`, `neovim.lua`, `vscode.json`, `preview.png`, `preview-unlock.png` and `unlock.png`.
- Built-in templates in [`default/themed/*.tpl`](https://github.com/omacom/omarchy/tree/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/default/themed) generate the rest: alacritty, btop, chromium, foot, ghostty, gum, helix, hyprland, hyprlock, keyboard, kitty, mako, obsidian, swayosd, walker and waybar.
- **Omarchy 4** adds `shell.toml` (the Quickshell desktop), Lua outputs (`hyprland.lua`, `gum_env.lua`, `neovim.lua`) and app themes for claude, pi, hermes and t3code, plus a `light.mode` marker and intro videos ([`docs/theming.md` L1-16](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/docs/theming.md#L1-L16)).
- **omadeb** themes ([`themes/tokyo-night/`](https://github.com/omakasui/omadeb/tree/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/themes/tokyo-night)) swap in GNOME-specific files: `gtk.theme` (a Yaru variant name), `accent.theme` (the GNOME accent colour) and `zellij.kdl`. Its [`default/themed/`](https://github.com/omakasui/omadeb/tree/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/default/themed) adds templates for the GNOME extensions `rounded-window-corners-reborn` and `tophat`.

### How `theme-set` applies a theme

The Omarchy 3 and omadeb versions are near-identical: [Omarchy 3 `bin/omarchy-theme-set`](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/bin/omarchy-theme-set) and [omadeb `bin/omadeb-theme-set`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-theme-set). Both:

1. Normalise the name ("Tokyo Night" becomes `tokyo-night`). Look it up in `$PATH/themes/` or the user's `~/.config/<proj>/themes/`.
2. Build a staging dir `~/.config/<proj>/current/next-theme`. Copy the shipped theme, then overlay the user theme of the same name.
3. If `colors.toml` is missing, derive it from `alacritty.toml`.
4. Render templates ([`omarchy-theme-set-templates` L17-46](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/bin/omarchy-theme-set-templates#L17-L46)). It reads `key = "value"` lines from `colors.toml` into a sed script that replaces `{{ key }}`, `{{ key_strip }}` and `{{ key_rgb }}`. User templates in `~/.config/<proj>/themed/*.tpl` render first. A template never overwrites a file the theme ships by hand.
5. **Atomic swap.** `rm -rf current/theme` and `mv next-theme current/theme`, then write `current/theme.name`.
6. Advance the background, restart or retint apps, run per-app setters, then fire the `theme-set` hook.

Apps pick the theme up because their configs *include* or *link* `current/theme/<file>`, a path that never changes. Only its contents change.

**Apps reached and reload method:**

- **Omarchy 3** restarts waybar, swayosd, the terminal, Hyprland (`hyprctl reload`), btop, opencode, mako and helix. It then runs setters for foot, GNOME/GTK, the browser (Chromium policy), VS Code, Obsidian and keyboard RGB (L52-70).
- **Omarchy 4** runs those in parallel (`post_theme_commands`, [`bin/omarchy-theme-set` L490-529](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-theme-set#L490-L529)). It serialises concurrent switches with `flock`, and pushes the theme to other machines over SSH when the user opts in.
- **omadeb** restarts btop, the terminal, zellij and opencode. Setters cover GNOME (`gsettings` color-scheme, gtk-theme, accent: [`bin/omadeb-theme-set-gnome`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-theme-set-gnome)), the GNOME extensions, VS Code and Obsidian.

**Security hardening in Omarchy 4.** `omarchy theme install <git-url>` clones third-party repos into the user themes dir. From a cloned theme (one with a `.git` dir), `theme-set` drops anything that can run code: `*.lua`, terminal configs that name a program to launch, `vscode.json` (it names an extension to install), and symlinks. A test fails if a new template is not classified as code or colour ([`docs/theming.md` L49-67](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/docs/theming.md#L49-L67); `INSTALLED_THEME_DENIED` at [`bin/omarchy-theme-set` L32](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-theme-set#L32)). Omarchy 3 and omadeb stage cloned themes in full.

**Trade-offs.** A palette file plus templates keeps a theme small and makes new apps cheap to add: one `.tpl` covers every theme. The atomic directory swap prevents half-applied themes. The sed-based renderer is fragile; it is line-based TOML parsing with no escaping. "Restart everything" means a theme switch kills running TUIs like btop. Supporting an app means maintaining both a template and a reload command.

## 4. Migrations

| | Omarchy 3 | Omarchy 4 | omadeb |
| --- | --- | --- | --- |
| **Files** | `migrations/<unix-ts>.sh` (330 at v3.8.4) | `migrations/<unix-ts>.sh` (149 at head; history reset at the 3-to-4 cut) | `migrations/<unix-ts>.sh` (24) |
| **Naming** | Timestamp of the last commit: `git log -1 --format=%cd --date=unix` ([`omarchy-dev-add-migration`](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/bin/omarchy-dev-add-migration)) | same, `omarchy-dev-add-migration --no-edit` | same, `omadeb-dev-add-migration` |
| **State** | Empty marker `~/.local/state/omarchy/migrations/<file>`; skipped ones in `.../skipped/<file>` | Marker per user, no skip dir; `OMARCHY_MIGRATION_STATE` overrides the path | same as Omarchy 3 under `~/.local/state/omadeb/` |
| **Order** | Shell glob order (lexical, so chronological for 10-digit timestamps) | same; "strictly ordered and synchronous" | same |
| **Runner** | `bash $file`; on failure `gum confirm` "Skip and continue?", which marks it skipped, otherwise exit ([`bin/omarchy-migrate`](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/bin/omarchy-migrate)) | `bash -euo pipefail "$file"`; a failure stops the queue and stays pending, **no skip**; waits for the pacman lock first; `--pending` lists without running ([`bin/omarchy-migrate` L31-97](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-migrate#L31-L97)) | Omarchy 3 runner verbatim ([`bin/omadeb-migrate`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-migrate)) |
| **When** | Inside `omarchy-update-perform`, after `git pull` and the pacman upgrade, before AUR | After the package transaction, in the visible update terminal; also prompted at login by `omarchy-migrate-notify.service`, which never runs them silently | After `git pull`, apt upgrade and GNOME extensions |
| **Fresh install** | Every shipped migration pre-marked as done ([`preflight/migrations.sh`](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/install/preflight/migrations.sh)) | `omarchy-provision-user --first-install` marks them; `/etc/skel` also seeds the markers | same as Omarchy 3 |

Omarchy 4's authoring rules ([`agents/skills/migrations.md` L107-149](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/agents/skills/migrations.md#L107-L149)):

- mode 0644, no shebang
- open with an `echo` describing the change
- idempotent ("check existing state before changing it")
- per-user, and a no-op when another user already did the machine-wide part
- testable with `HOME=$(mktemp -d) bash -euo pipefail migrations/<ts>.sh`
- "a migration that cannot finish must exit non-zero, remain pending, and stop the queue"

Omarchy 4 dropped Omarchy 3's skip-and-continue on purpose.

**Trade-offs.** Marker files are trivially inspectable and need no database. Per-user state handles multi-user installs, which this map rules out. Timestamp names avoid merge conflicts between branches, but they say nothing about content; the opening `echo` fills that role. Skip-on-failure (Omarchy 3 and omadeb) lets later migrations run against state an earlier one never set up. Omarchy 4 calls this out and removes it.

## 5. The update command

### Omarchy 3

[`bin/omarchy-update`](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/bin/omarchy-update):

1. Re-exec under `script(1)` to log to `/tmp/omarchy-update.log`.
2. Confirm (skipped with `-y`).
3. `omarchy-snapshot create` (snapper; exit 127 means no snapper and is ignored).
4. [`omarchy-update-git`](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/bin/omarchy-update-git): `git -C $OMARCHY_PATH pull --autostash`, then `git diff --check || git reset --merge`, with Hyprland error display suppressed during the pull.
5. [`omarchy-update-perform`](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/bin/omarchy-update-perform): keyring, `pacman -Syu`, **migrate**, AUR (`yay`), orphans, `omarchy-hook post-update`, log analysis, and restart prompts.

**Channels.** `omarchy-channel-set stable|rc|edge|dev` maps each channel to a git branch (`master`, `rc` or `dev`) plus a pacman mirror. It then runs a full update ([`bin/omarchy-channel-set`](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/bin/omarchy-channel-set#L14-L22)).

### Omarchy 4

[`docs/update-process.md` L117-168](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/docs/update-process.md#L117-L168) and [`bin/omarchy-update` L99-160](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/bin/omarchy-update#L99-L160):

1. Transcript log and a per-user update lock.
2. A 10 GiB free-space check, then confirm.
3. **Ask for the sudo password once**, after revoking any cached timestamp so the prompt belongs to this update, and keep it fresh in the background.
4. Prune the package cache, snapshot, and inhibit sleep.
5. `omarchy-update-dev` (fast-forwards the checkout only in dev-link mode), then the keyring.
6. `pacman -Syu` through a guard-approved wrapper inside a `systemd-run --scope`.
7. **migrate**, orphan removal, log analysis, update-indicator refresh, service restarts.
8. The `post-update` hook and `mise up`.
9. **Revoke sudo**, then build AUR packages with a sudo wrapper that prompts per command and caches nothing ("AUR builds run third-party PKGBUILD code").
10. Release the inhibitor and offer a reboot.

The entry point runs `#!/bin/bash -p` and scrubs `BASH_ENV` and exported functions (L1-35).

**Pacman guard.** An ALPM pre-transaction hook aborts a bare `pacman -Syu` and points the user to `omarchy update`, unless `OMARCHY_ALLOW_DIRECT_PACMAN=1` is set (L66-115). Updates that bypass the guard still get migrations through the login notifier.

**Channels.** stable, rc and edge each select a pacman repo; `dev` links the runtime to a git checkout (L265-280).

### omadeb

[`bin/omadeb-update`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-update) confirms, then runs `omadeb-update-git` (the same `pull --autostash` as Omarchy 3, minus the Hyprland handling). After that, [`omadeb-update-perform`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-update-perform) runs in this order:

1. Tee the output to `/tmp/omadeb-update.log`.
2. Keyring.
3. `apt-get update`, `upgrade` and `dist-upgrade`, `autoremove`, and `flatpak update` ([`omadeb-update-system-pkgs`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-update-system-pkgs)).
4. GNOME extensions.
5. **migrate**.
6. The `post-update` hook.
7. Restart and logout prompts.

There is no snapshot step. The flatpak check `! command -v "flatpak --version"` (L20) always succeeds, because no command has that name. So `flatpak update` runs whether or not flatpak is installed.

**Channels.** `stable` maps to branch `main` plus apt suite `trixie`; `dev` maps to branch `dev` plus suite `trixie-dev` ([`bin/omadeb-channel-set`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-channel-set), [`bin/omadeb-refresh-apt`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-refresh-apt)). `omadeb-update-available` compares the newest remote tag against the newest local tag ([source](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-update-available)). The update itself pulls the branch head, not a tag.

**Neither project shows what the update will run before running it.** Omarchy 3 and omadeb `git pull` and then run whatever migrations arrived. The confirm screen only links the release notes ([`omadeb-update-confirm`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-update-confirm)). Omarchy 4's `omarchy-migrate --pending` can list pending migrations, but the update pipeline does not call it before running them.

## 6. The `bin/` command suite

- **Naming.** Every command is `bin/<proj>-<group>-<verb...>`. The prefix carries the purpose: `cmd-`, `pkg-`, `refresh-`, `restart-`, `launch-`, `install-`, `setup-`, `toggle-`, `theme-`, `update-` and so on ([Omarchy 4 `AGENTS.md` L34-60](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/AGENTS.md#L34-L60); [omadeb `AGENTS.md` L11-34](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/AGENTS.md#L11-L34)). Counts: Omarchy 3 has 283 commands, Omarchy 4 has 491, omadeb has 163.
- **Router.** A single `bin/<proj>` script maps `omarchy theme set foo` to `exec bin/omarchy-theme-set foo`. There is no registry: every executable `bin/<proj>-*` is a command and its filename is its route.
  - **Dispatch.** Longest-prefix match on the arguments. A fast path probes filenames (a few `stat` calls). Header metadata loads only when needed.
  - **Metadata.** The first 80 comment lines can carry `# omarchy:summary|args|examples|group|name|alias|hidden|requires-sudo`.
  - **Groups.** A hand-curated `GROUP_DESCRIPTIONS` table drives the top-level listing.
  - **Introspection and lint.** `omarchy commands [--all|--json|--markdown|--check]`. `--check` is the metadata lint run by the tests.

  Sources: [Omarchy 4 `docs/cli-router.md`](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/docs/cli-router.md) and [`agents/skills/command-metadata.md`](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/agents/skills/command-metadata.md). omadeb's [`bin/omadeb`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb) (1046 lines) differs from Omarchy 3's [`bin/omarchy`](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/bin/omarchy) (1063 lines) in only 33 lines once the project name is normalised, measured by a `diff` after `s/omadeb|omarchy/X/`.
- **Finding the install location.**
  - **Omarchy 3 and omadeb** hard-code `OMARCHY_PATH`/`OMADEB_PATH=$HOME/.local/share/<proj>` and prepend `$PATH/bin` in two places: the session environment and the bash envs. Omarchy 3 uses [`config/uwsm/env` L4-5](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/config/uwsm/env#L4-L5) and [`default/bash/envs` L10-11](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/default/bash/envs#L10-L11), with the comment "Duplicated from .config/uwsm/env so SSH works too". omadeb uses [`config/environment.d/omadeb.conf`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/config/environment.d/omadeb.conf) and [`default/bash/envs`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/default/bash/envs). Some scripts also hard-code the literal path.
  - **Omarchy 4** has one file, [`default/bash/env-bootstrap`](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/default/bash/env-bootstrap), sourced by every entry point: profile.d, `.bashrc`, uwsm `env.d`, and SSH envs. It reads `/etc/omarchy.conf` (written by `omarchy-dev-link`) or defaults to `/usr/share/omarchy`, and adds `$OMARCHY_PATH/bin` to `PATH` only for a dev checkout. Binaries otherwise live in `/usr/bin`. Rule: commands use `$OMARCHY_PATH` and never derive it from `$HOME` ([`AGENTS.md` L61-64](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/AGENTS.md#L61-L64)). `omarchy-dev-link` also writes a `sudoers.d` `secure_path` so `sudo omarchy-*` resolves to the checkout ([`docs/file-layout.md` L164-199](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/docs/file-layout.md#L164-L199)).
- **Hooks.** `<proj>-hook <name>` runs `~/.config/<proj>/hooks/<name>` and every file in `<name>.d/`, skipping `*.sample` files. A failing hook only prints a message ([Omarchy 3 `bin/omarchy-hook`](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/bin/omarchy-hook#L13-L28)). Events include `post-update`, `theme-set` and `font-set` (omadeb ships [`config/omadeb/hooks/`](https://github.com/omakasui/omadeb/tree/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/config/omadeb/hooks)).

**Trade-offs.** The filename-as-route convention scales to hundreds of commands with no registry to drift. The cost is a large, flat `bin/`, a global namespace on `PATH`, and a hand-kept `GROUP_DESCRIPTIONS`. Duplicating the path in several env files (Omarchy 3, omadeb) led Omarchy 4 to a single bootstrap file.

## 7. The setup menu

- **Omarchy 3** has one 891-line bash script, [`bin/omarchy-menu`](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/bin/omarchy-menu). Its `menu()` function pipes `\n`-joined options into `walker --dmenu` (L27-46). Each `show_*_menu` is a `case` on the selected label: substring matches like `*Audio*)`, each calling one `omarchy-*` command or opening a submenu. Root is `show_main_menu` with Apps, Learn, Trigger, Style, Setup, Install, Remove, Update, About and System (L851-853). `omarchy-menu <name>` jumps straight to a submenu through `go_to_menu`, which keybindings use. Users extend it by sourcing `~/.config/omarchy/extensions/menu.sh`, which can redefine any `show_*` function (L880-882). Entries map to commands one-to-one. Setup > Monitors, for example, opens `~/.config/hypr/monitors.conf` in the editor (L314-335).
- **Omarchy 4** makes the menu **data**: [`default/omarchy/omarchy-menu.jsonc`](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/default/omarchy/omarchy-menu.jsonc), rendered by a Quickshell plugin. It is overlaid per key by the user's `~/.config/omarchy/extensions/omarchy-menu.jsonc` and hot-reloaded ([`docs/menu.md`](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/docs/menu.md)).
  - **Tree.** The dotted id is the tree (`setup.network.dns`). The kind is inferred: `action` means a command, `target` a link, anything else a submenu.
  - **Guards.** `when` (hide), `checked` (tick) and `disabled` (dim) are bash conditions, batched into one bash process per open.
  - **Providers.** Rows can be generated at runtime (apps, fonts, power profiles).
  - **CLI.** `omarchy menu summon <route>` opens any route.
  - **Tests.** The pure logic is plain JS that Node tests exercise directly.
- **omadeb** keeps the Omarchy 3 bash-plus-walker design ([`bin/omadeb-menu`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-menu), 713 lines). Walker comes from omadeb's own `omadeb-walker` apt package. The entries are rewritten for GNOME. Most of the file differs from Omarchy 3 (617 lines in the normalised diff), but the structure is the same: `menu()`, `show_*_menu`, `go_to_menu`, and an `extensions/menu.sh` overlay (L678-705). Keybindings are GNOME custom shortcuts set by [`install/config/gnome/hotkeys.sh` L58-64](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/config/gnome/hotkeys.sh#L58-L64): Super+Alt+Space for the menu, Super+Escape for system.

**Trade-offs.** The bash `case` menu is simple and dependency-light: it needs only a dmenu-style picker. But labels and actions are intertwined, matching is by substring, and user extension means overriding whole functions. The JSONC menu separates data from rendering, merges per entry, and is testable. It is tied to Omarchy 4's Quickshell, though the schema could work with any picker.

## 8. Manual and docs site

- **Omarchy 3** has no manual in the repo. The menu links an external site, `https://learn.omacom.io/2/the-omarchy-manual` ([`bin/omarchy-menu` L86](https://github.com/omacom/omarchy/blob/8fcc9d6048af4cb0e3af8512c78049857a3b53dd/bin/omarchy-menu#L86)).
- **Omarchy 4** moved the manual **into the repo** as 51 numbered Markdown chapters in `manual/`, "its authoritative source" ([`README.md`](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/README.md)). They are published at `https://omarchy.org/manual/`, which the menu opens ([`omarchy-menu.jsonc` L46](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/default/omarchy/omarchy-menu.jsonc#L46)).
  - Three doc trees split by audience: `manual/` for end users, `docs/` for system reference, `agents/skills/` for contributor procedure ([`AGENTS.md` L14-20](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/AGENTS.md#L14-L20)).
  - `manual/` ships in **neither** package, so there is no offline copy on the machine ([`docs/file-layout.md` L29-31](https://github.com/omacom/omarchy/blob/988f44ea1a16250785eee1c73cbaf558080589db/docs/file-layout.md#L29-L31)).
  - The site generator and the publish job are not in this repo; see Gaps.
- **omadeb** keeps the manual in a **separate repo**, [omakasui/omadeb.omakasui.org](https://github.com/omakasui/omadeb.omakasui.org/tree/4af2ee5acbf60fac8071fc5352786ce38fb2216f).
  - **Build.** It is built with **Astro** (`astro ^7.3.1`) and the `@lancher-dev/jaad` docs theme ([`package.json`](https://github.com/omakasui/omadeb.omakasui.org/blob/4af2ee5acbf60fac8071fc5352786ce38fb2216f/package.json)). It is configured in [`jaad.config.ts`](https://github.com/omakasui/omadeb.omakasui.org/blob/4af2ee5acbf60fac8071fc5352786ce38fb2216f/jaad.config.ts) with `docsDir: ./docs`, `routeBase: /manual` and `editLink: true`.
  - **Publish.** It is deployed to **GitHub Pages** by `withastro/action` plus `actions/deploy-pages` on every push to `main` ([`.github/workflows/deploy.yml`](https://github.com/omakasui/omadeb.omakasui.org/blob/4af2ee5acbf60fac8071fc5352786ce38fb2216f/.github/workflows/deploy.yml)).
  - **Bootstrap.** The same site serves the bootstrap one-liner (`public/install`, `public/install-dev`).
  - **No sync mechanism.** Nothing ties the docs to the configs. They are hand-maintained in another repo, and drift is visible: [`docs/06-configuration/03-apt-repository.md`](https://github.com/omakasui/omadeb.omakasui.org/blob/4af2ee5acbf60fac8071fc5352786ce38fb2216f/docs/06-configuration/03-apt-repository.md) says "packages Ubuntu doesn't carry", wording carried over from the sibling Omabuntu project. The menu links to the site online ([`bin/omadeb-menu` L83-85](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-menu#L83-L85)).

**Trade-offs.** In-repo Markdown (Omarchy 4) puts docs in the same commit as the change, but still does not *generate* anything from configs. The keybindings page, for instance, is written by hand. A separate site repo (omadeb) decouples release cadence and invites drift. Neither project generates docs from source. That would be the gap to close if this map wants the manual to "stay in sync".

## 9. How omadeb adapts Omarchy to Debian

1. **It forks the Omarchy 3 shape, not Omarchy 4.** It keeps the git clone in `~/.local/share/omadeb`, `boot.sh` plus `install.sh`, the same six phases, `run_logged`, marker-file migrations, the router, refresh-config, hooks, the theme pipeline and the walker menu. Key scripts are near-verbatim: `migrate` differs from Omarchy 3's in 1 line, `refresh-config` in 6, `theme-set-templates` in 6, and the router in 33.
2. **pacman and AUR become apt plus self-hosted APT repos.** Packages missing from trixie, or too old there, come from two **Omakasui APT repos**: `core.omakasui.org` (always installed, for example `omadeb-walker` and `omadeb-nvim`) and `packages.omakasui.org` (optional, newer builds).
   - **Suites.** Channels select `trixie` or `trixie-dev`.
   - **Keyrings.** Sources and keys ship inside the `omakasui-*-archive-keyring` .debs. The first install fetches them with `curl` over HTTPS with no checksum ([`bin/omadeb-update-keyring`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-update-keyring)).
   - **Other repos.** mise comes from its upstream apt repo ([`install/packaging/mise.sh`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/packaging/mise.sh)), and Flathub is added for GUI apps.
   - **Build pipeline.** The org's [`build-apt-packages`](https://github.com/omakasui/build-apt-packages) and [`apt-packages`](https://github.com/omakasui/apt-packages) repos appear to build and host these packages (not inspected; see Gaps).
3. **Hyprland becomes GNOME.** Tiling, keybindings and the dock are GNOME extensions and `gsettings`. Themes add `gtk.theme` and `accent.theme` and drive GNOME's colour scheme and accent. Config layering for the desktop shrinks to "re-run the gsettings script".
4. **Arch-only hardware quirks are dropped.** omadeb has two hardware leaves (`fix-fkeys` and Framework text scaling) against Omarchy 3's 34. limine, snapper, mkinitcpio and SDDM are replaced by GDM and Plymouth tweaks. **There is no snapshot step** in update.
5. **Branding is a variable.** `OMADEB_BRAND` and the `brand` file make it a base for derived setups. The org also has `omabuntu` (Ubuntu) and `omari` ("Opinionated Debian and Niri Setup", a Debian plus tiling-Wayland sibling).

## 10. Against this map's security baseline

The map's Notes set the baseline. Each row is a gap or a model:

| Baseline rule | Omarchy 3 / omadeb | Omarchy 4 | Takeaway |
| --- | --- | --- | --- |
| Bootstrap is a `git clone`, never a piped script | `curl \| bash` of `boot.sh` (omadeb: `curl \| bash` of an `eval "$(curl ...)"`) | ISO, no bootstrap script | Neither is a model. Keep `git clone` plus running from the checkout. |
| No unsigned third-party apt repos | omadeb adds two self-hosted repos (signed, but keys fetched over TLS with no checksum) plus mise's repo | n/a (own signed pacman repo plus `omarchy-keyring`) | Building the same tool set on Debian means mise or upstream releases, not an Omakasui-style repo. |
| No standing root, no `NOPASSWD` | First-run writes `NOPASSWD` for `systemctl` and `ufw`, removed after first login | One sudo authorization per update, revoked before AUR; `-p` bash entry; sanitized `PATH` | Omarchy 4's update sudo lifecycle is the model to study. |
| Migrations and updates show what they'll run first; never run unreviewed fetched code | `git pull` then run new migrations; the confirm screen only links release notes | `--pending` exists but isn't shown pre-run; migrations arrive in signed packages | Neither shows a preview. This map needs its own "list pending migrations and the incoming diff, then confirm" step. |
| Upstream downloads verified | omadeb keyring `.deb`s: TLS only | packages signed | — |
| Secrets outside the repo | n/a | n/a | — |

## Gaps

- **Omarchy 4 manual build.** The repo holds `manual/*.md`, but the generator and deploy pipeline behind `omarchy.org/manual/` are not in it, and the page exposes no generator meta. They probably live in a separate site repo (not located). So it is unknown whether omarchy.org builds straight from `manual/` at a tag or from a copy.
- **`omarchy-pkgs` PKGBUILDs.** The packaging repo that turns the tree into `omarchy` and `omarchy-settings` was not read. The `/etc/skel` seeding and the `etc-overrides` post-install are described only from Omarchy's own `docs/file-layout.md`.
- **Omakasui APT build pipeline.** `build-apt-packages`, `apt-packages`, `build-apt-omakasui` and `apt-omakasui` were not inspected. Which packages come from which repo, how they're built, and how signing keys are managed are unverified. The manual's claim that keyrings live at `/usr/share/keyrings/omakasui-*.gpg` was not checked against the keyring package.
- **omadeb tests.** omadeb has one test, `test/omadeb-cli-test.sh`, which was not read. Coverage is unknown beyond its name.
- **Omarchy 4 internals not traced line by line:** the `omarchy-done` marker helper, `omarchy-dev-link` and `omarchy-upgrade-to-quattro` (3-to-4 conversion) were read only through `docs/` and command headers. The Quickshell menu renderer (`shell/plugins/menu/`) was not read; the menu claims rest on `docs/menu.md`.
- **The 3-to-4 migration history.** Omarchy 4 has 149 migrations against Omarchy 3's 330. That points to a reset at the package cut (consistent with `agents/skills/migrations.md`: "Do not add compatibility migrations for old installer layouts"). The exact cut-over commit was not identified.
- **`omari`** (Debian plus Niri) was not examined. As a Debian setup on a tiling Wayland compositor, it may be closer to this map's target than omadeb is, so it is worth a look if the map wants one more reference.
- **Behaviour at runtime.** No script from either repo was run. Statements about behaviour come from reading the code and the projects' own docs.
