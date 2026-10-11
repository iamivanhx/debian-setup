# Apps and dev tools from omadeb and Omarchy

Research note for the ticket [Research: Apps and dev tools from omadeb and Omarchy](https://github.com/iamivanhx/debian-setup/issues/46), on the map [Map: SER8 Debian setup refactor (Omarchy/omadeb-inspired)](https://github.com/iamivanhx/debian-setup/issues/44). Written 2026-10-11. Terms (**exception**, **step**, **test VM**) are from `GLOSSARY.md`. "Verified" and "exception" carry the meaning in [`ADR-20261010-pin-outside-apt`](../adr/20261010-pin-outside-apt.md) [ADR].

**Question.** What apps and dev tools do omadeb and Omarchy install? How does that compare with what this repo installs today and with Ivan's Mac? Where would each tool come from on trixie under the map's security baseline?

**Scope.** This note does not recommend a final set. The shell and dev-tool steps are decided later on the map. Where a row names a "first source", that is the first source in the baseline's order (Debian, backports, mise, signed vendor apt, upstream release) that ships the right program. It is not a choice.

## Sources and pins

| Label | What | Pin |
| --- | --- | --- |
| **omadeb** | [omakasui/omadeb](https://github.com/omakasui/omadeb), Debian trixie + GNOME | [`654f5964`](https://github.com/omakasui/omadeb/tree/654f5964cf212483df5b3c1b2a9a15ac9a115ab4) (= `main` = tag `v1.4.3`, 2026-10-02) |
| **Omakasui repos** | omadeb's own apt repos | `packages.omakasui.org` trixie `Release` dated 2026-10-10; `core.omakasui.org` trixie `Release` dated 2026-09-18 [OMK] |
| **Omarchy** | [omacom/omarchy](https://github.com/omacom/omarchy), default branch `quattro` (Omarchy 4, Arch) | [`35a55fd2`](https://github.com/omacom/omarchy/tree/35a55fd236598598130711249a647e0071532e9a) (head, 2026-10-11) |
| **Today** | this repo's `modules/` | `main` at [`cab5fbff`](https://github.com/iamivanhx/debian-setup/tree/cab5fbffa90e4ab8c675eb9d8d3714e18bd995d2/modules) |
| **Mac** | Ivan's Mac inventory, from the earlier note | [`macos-inventory-and-tools.md` at `4e336275`](https://github.com/iamivanhx/debian-setup/blob/4e336275f7f3b83d418c9ccbc2c8a32164e03d83/docs/research/macos-inventory-and-tools.md) (gathered 2026-10-09) [MAC] |
| **Debian** | madison, suites trixie, trixie-security, trixie-backports, forky | queried 2026-10-11 [MAD] |
| **mise registry** | `jdx/mise` `registry/` | tag `v2026.10.7` = [`4599c53b`](https://github.com/jdx/mise/tree/4599c53b4286ff101de876f8122feec0797b48b2/registry) [MREG] |
| **aqua registry** | recipes behind mise's `aqua:` backend | [`63d7f713`](https://github.com/aquaproj/aqua-registry/tree/63d7f713918fcc226c94db42988f7bf0ff6084d6/pkgs) [AQUA] |
| **Upstream releases** | GitHub Releases API and attestations API, latest release per repo | queried 2026-10-11 [GHREL] |
| **Vendor apt** | `Packages` indexes of each vendor repo | fetched 2026-10-11 [VAPT] |

The earlier architecture note pinned Omarchy at `988f44ea` [ARCH]. In the 62 commits since then, `install/omarchy-base.packages` dropped `clang`, `llvm`, `kdenlive` and `obs-studio`, and added `gliff`, `usbguard` and four `fcitx5` input methods (compare `988f44ea...35a55fd2`). Omarchy's package list moves week to week.

## Answer in brief

- **A shared core of a dozen CLI tools.** fzf, zoxide, ripgrep, fd, bat, eza, jq, git, lazygit, btop, fastfetch and starship appear in omadeb, Omarchy and today's modules, and nearly all of them are on the Mac too. **All are in Debian trixie** [MAD], so none of them needs an exception. Debian's builds lag upstream, though: fzf 0.60.3 against 0.74.5, gh 2.46.0 against 2.102.0, lazygit 0.50.0 against 0.66.0, eza 0.21.0 against 0.23.5, starship 1.22.1 against 1.26.0.
- **omadeb gets newer versions by overriding Debian.** Its base list names plain Debian packages (`starship`, `fzf`, `gh`, `tmux`, `eza`…). It also adds two Omakasui apt repos that ship same-named, newer `+trixie` builds [OD-PKG][OMK]. The keyring package installs a `.sources` file and no apt pin [OMK-KR]. At equal priority apt installs "the one with the higher version number" [APTPREF], so the Omakasui builds win. Omakasui is a third-party repackager, not the tools' vendor. Its repo can replace any Debian package by version, and its keys are first fetched over TLS with no checksum [OD-KEY]. That breaks the baseline rule that a vendor repo is "pinned to its own packages".
- **Neither project pins what it fetches outside apt.** Omarchy installs gh and about twenty AI agents as lazy mise stubs. Each stub runs `mise use -g <tool>` at first use, with `MISE_MINIMUM_RELEASE_AGE=0` [OA-MISE][OA-MISEW]. omadeb runs eight npm agents through `pnpm dlx` on every launch, with a 7200-minute pnpm release age [OD-NPM][OD-NPMW]. Both install Rust and OCaml through piped installers (`curl … | bash`) [OD-DEV][OA-DEV], and Omarchy installs uv the same way [OA-DEV]. All of this conflicts with `ADR-20261010-pin-outside-apt` and the no-piped-installers rule.
- **Gaps against today.** Both projects ship things today's modules don't: tmux, gum, a set of AI agents, `install dev-env` for about 16 languages, LibreOffice, mpv/imv, LocalSend, Pinta, Xournal++, and Chromium. The Mac has six dev tools that no module installs: yq, uv, pnpm, git-delta, gitleaks and shellcheck. It also has 1Password, Chrome, and three AI agents (Claude Code, Codex, pi).
- **What only today has.** zsh with its two plugins (both projects use bash), sfw, htop alongside btop, redis-tools, five GNOME Shell extensions from extensions.gnome.org, Gruvbox GTK and icon themes, and Ghostty as the default terminal.
- **Exception-only tools.** These have no apt source and no signature or attestation upstream:
  - Ghostty, lazydocker, Walker and Elephant, the JetBrains Mono Nerd Font, zellij, Helix, Obsidian, LocalSend, the Copilot CLI and the Gemini CLI.
  - Codex and pi through mise. Their npm packages carry SLSA provenance, but mise's npm backend does not check it [MISE-NPM].
  - Any newer-than-Debian build of starship, fzf, zoxide, ripgrep, bat, eza, delta, lazygit, gitleaks, neovim, btop, fastfetch or shellcheck.

  The full list is in [Exception-only under the ADR](#exception-only-under-the-adr).
- **Verifiable through mise.** yq, uv, pnpm, gh, jq, tlrc, atuin, tree-sitter, gum, crush and herdr have a recipe that declares an attestation or a cosign signer. Node (OpenPGP), Python and Ruby (attestations) verify through mise's core plugins [MISE-NODE][MISE-PY][MISE-RUBY]. Claude Code, opencode, fd, direnv, hunk and Zed publish GitHub attestations, but their registry recipe does not declare them. mise's `github:` backend checks attestations "when the release has them" [MISE-GH].
- **Today's modules break the baseline in seven places:**
  - starship comes from a piped installer.
  - The VS Code `.deb`, the lazydocker tarball, the Ghostty community `.deb`, the Nerd Font zip and the Gruvbox tarballs are downloaded with no signature or checksum check.
  - The mise apt key is fetched with no fingerprint check.
  - The user is added to the `docker` group.

  Details are in [Today's modules against the baseline](#todays-modules-against-the-baseline).

## How to read the tables

- **omadeb / Omarchy / Today / Mac.** `base` means installed by default. `opt` means offered by a menu or `install-*` command. `—` means absent. For omadeb, `(Omakasui x.y)` means the Omakasui build outranks Debian's and is what actually lands. For Today, the cell names the module.
- **First source on trixie (version).** **D** is trixie, including trixie-security and point releases. **BP** is trixie-backports. **M** is mise, with its registry backend. **V** is a signed vendor apt repo. **U** is an upstream release. **R** is a third-party rebuild: Omakasui's signed trixie repo, which is not the tool's vendor. It is therefore outside the baseline's source list, and it outranks Debian packages by version (see [Answer in brief](#answer-in-brief)). It is listed only where it is the sole apt route. Versions are as of 2026-10-11. A later source is listed too when Debian's version is far behind. Backports sit at priority 100 by default, so each backports package needs its own pin, as today's kernel pin does [MOD-00].
- **Proof under the ADR.**
  - `apt` means a signed archive, unpinned by design.
  - `verified (…)` means mise checks a signature or attestation that the recipe declares.
  - `attested, recipe silent` means the latest upstream release carries a GitHub attestation, but mise's registry recipe does not declare it. mise's `github:` backend checks it when present [MISE-GH].
  - `integrity only` means a checksum file or digest from the same release. Under the ADR that is an **exception**.
  - `none` means no proof found, which also makes it an exception.

# Part A: Desktop-independent

## A1. Shell and prompt

| Tool | Job | omadeb | Omarchy | Today | Mac | First source on trixie (version) | Proof | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bash (+ bash-completion) | shell | base; config in `default/bash/` [OD-SH] | base; `bash-completion` [OA-PKG L9] | system shell only | — | D 5.2.37, bash-completion 2.16.0 | apt | **Overlap** with zsh. Both projects' shell config is bash-only. |
| zsh + zsh-autosuggestions + zsh-syntax-highlighting | shell, add-ons | — | — | `50-shell` [MOD-50 L32] | yes | D 5.9 / 0.7.1 / 0.8.0 | apt | |
| starship | prompt | base (Omakasui 1.26.0) [OD-PKG L83] | base [OA-PKG L130] | `50-shell`: **piped `starship.rs/install.sh`**, v1.25.1 [MOD-50 L17, L43-51] | yes | D 1.22.1 (forky 1.26.0); M `aqua:starship/starship` | M: integrity only (`.sha256` per asset, no attestation) [AQUA][GHREL] | Today's install breaks the no-piped-installers rule. Debian's build avoids an exception. |

## A2. CLI utilities

| Tool | Job | omadeb | Omarchy | Today | Mac | First source on trixie (version) | Proof | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fzf | fuzzy finder | base (Omakasui 0.74.4) [OD-PKG L30] | base [OA-PKG L47] | `00-base` [MOD-00 L73-77] | yes | D 0.60.3; upstream 0.74.5 | M: integrity only | |
| zoxide | directory jumping | base (Omakasui 0.10.0) | base | `00-base` | yes | D 0.9.7 (forky 0.10.0) | M: none | |
| ripgrep | search | base (D) | base | `00-base` | yes | D 14.1.1; upstream 15.2.0 | M: integrity only | |
| fd | find | base `fd-find` (D); alias `fd='fdfind'` [OD-ALIAS L9] | base `fd` | `00-base` `fd-find` | yes | D 10.2.0, **binary `fdfind`** | M: attested, recipe silent (v10.5.0) | Debian binary name trap [MAC]. |
| bat | pager | base (D); alias `bat='batcat'` [OD-ALIAS L39] | base | `00-base` | yes | D 0.25.0, **binary `batcat`** | M: none | Same name trap. |
| eza | `ls` | base (Omakasui 0.23.5) | base | `00-base` | yes | D 0.21.0 | M: none | |
| jq | JSON | base (D) | base | `00-base` | yes | D 1.7.1 (trixie-security deb13u4) | M: verified (attestation) | |
| yq (mikefarah) | YAML | — | — | — | yes | **M** `aqua:mikefarah/yq` 4.54.1 | verified (cosign-signed checksums; attestation) | Debian's `yq` 3.4.3 is kislyuk's jq wrapper, a different program [MAC]. |
| tldr client | cheat sheets | — | base `tldr` [OA-PKG L136] | — | `tlrc` | D tealdeer 1.7.2 (binary `tldr`); M `tlrc` 1.13.1 | tealdeer apt; tlrc verified (attestation) | **Overlap**: three clients for one job. |
| tree, plocate, curl, wget, unzip | basics | base (plocate, curl, wget, unzip) | base (plocate, unzip) | `00-base` | n/a | D | apt | |
| fastfetch | system info | base (Omakasui 2.69.0) | base ("About") [OA-M21] | `00-base` | — | D 2.40.4 | M: none | |
| btop | system monitor | base (Omakasui 1.4.7) | base ("Activity") [OA-M21] | `00-base` | — | D 1.3.2 (forky 1.4.7) | M: none | **Overlap** with htop. |
| htop | system monitor | — | — | `00-base` | — | D 3.4.1 | apt | |
| gum | TUI prompts for scripts | installer dependency (Omakasui 2.0.2) [OD-PRES] | base [OA-PKG L54] | — | — | D 0.14.4; M 2.x | M: verified (cosign) | Both projects' installers and menus depend on gum. |
| usage | CLI spec, completions | — | base [OA-PKG L148] | — | — | M `packslip:github.com/jdx/usage` | packslip signer [MREG] | jdx's companion to mise. |
| yt-dlp | video download | — | base | — | — | D 2025.04.30 (stale); BP 2026.08.19 | apt | Usually needs backports to work. |
| imagemagick, ffmpeg (+ libvips) | media libs and CLIs, also Rails Active Storage | base | base | — | — | D (trixie-security) | apt | |
| pipx | Python app installer | base; installs `terminaltexteffects`, `gnome-extensions-cli` [OD-PIPX] | — | — | — | D 1.7.1 | apt | **Overlap** with uv's `uv tool`. |

## A3. Git and code review

| Tool | Job | omadeb | Omarchy | Today | Mac | First source on trixie (version) | Proof | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| git | VCS | dependency | base | `00-base` | yes | D 2.47.3 | apt | |
| gh | GitHub CLI | base (Omakasui 2.102.0) | lazy mise stub [OA-MISE L9] | `00-base` (D 2.46.0) | yes | D 2.46.0 (old); M `github-cli` = `aqua:cli/cli` 2.102.0; V `cli.github.com/packages` 2.102.0 | M: verified (attestation, signer `cli/cli/.github/workflows/deployment.yml`) | Three possible sources. |
| lazygit | git TUI | base (Omakasui 0.66.0) | base | `60-dev` [MOD-60 L57-65] | yes | D 0.50.0 | M: integrity only | |
| git-delta | diff pager | — | — | — | yes | D 0.18.2; upstream 0.20.1 | M: none | |
| gitleaks | secret scan | — | — | — | yes | D 8.16.0 (old); upstream 8.30.1 | M: integrity only | |
| shellcheck | shell lint | — | — | — | yes | D 0.10.0; BP 0.11.0 | apt | |
| ghui | PR TUI | npm wrapper [OD-NPM L8] | mise `npm:@kitlangton/ghui` [OA-MISE L18] | — | — | M `npm:` 0.9.1 | npm SLSA provenance exists; mise's npm backend does not check it [MISE-NPM][NPM] | |
| hunk | diff viewer | — | mise `aqua:modem-dev/hunk` [OA-MISE L19] | — | — | M `aqua:modem-dev/hunk` 0.23.0 | attested, recipe silent | |

## A4. Terminal multiplexers and TUIs

| Tool | Job | omadeb | Omarchy | Today | Mac | First source on trixie (version) | Proof | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| tmux | multiplexer | base (Omakasui 3.7c) | base; layout functions `tdl`, `tsl` [OA-M15] | — | — | D 3.5a; BP 3.6b | apt | **Overlap** with zellij and herdr. |
| zellij | multiplexer | config package `omadeb-zellij` in the core repo, not in the base list [OMK] | — | — | — | M `aqua:zellij-org/zellij` 0.45.1 | none (per-asset `.sha256sum` only) → **exception** | Not in Debian. |
| herdr | workspace manager | — | base [OA-PKG L58][OA-M21] | — | — | M `github:herdrdev/herdr` 0.9.3 | verified (attestations since 0.1.0) [MREG] | |
| lazydocker | Docker TUI | base (Omakasui 0.25.2) | — (gone from v4's list) | `60-dev`: pinned x86_64 tarball, **no checksum** [MOD-60 L102-110] | — | M `aqua:jesseduffield/lazydocker` 0.25.2 | integrity only → **exception** | Not in Debian. |

## A5. Editors

| Tool | Job | omadeb | Omarchy | Today | Mac | First source on trixie (version) | Proof | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Neovim | editor | base `omadeb-nvim` (a LazyVim config) pulling Omakasui `nvim` 0.12.5 [OMK] | base `nvim` + `omarchy-nvim`; the default `EDITOR` [OA-PKG L96][OA-M18] | `00-base` `neovim` | — | D 0.10.4 (forky 0.12.4); upstream 0.12.6 | M (`vfox:jdx/vfox-neovim`, `aqua:neovim/neovim`): none → **exception** | Debian and Omakasui name the package differently (`neovim` vs `nvim`). |
| VS Code | editor | opt: Microsoft apt [OD-VSC] | opt (Install > Editor) [OA-M18] | `60-dev`: downloads the `.deb` from `code.visualstudio.com`, whose postinst adds the repo [MOD-60 L78-93] | yes (`EDITOR`) | V Microsoft `packages.microsoft.com/repos/code` 1.141.0 | apt | Today's first fetch skips signature checking (see below). |
| Zed | editor | opt (Omakasui `zed` 1.23.2) [OD-MENU L474] | opt [OA-M18] | — | — | U `zed-linux-x86_64.tar.gz` v1.23.2 (not in the mise registry) | attested, recipe silent → verifiable with `github:zed-industries/zed` | Debian's `zed` is an unrelated OCaml library [MAC]. |
| Helix | editor | — | opt | — | — | M `aqua:helix-editor/helix` 25.07.1 | none → **exception** | Not in Debian. |
| Emacs | editor | opt (Doom) | opt | — | — | D 30.1 | apt | |
| Cursor | AI editor | opt: AppImage fetched with `curl \| xargs curl`, no check [OD-CURSOR] | opt | — | — | U AppImage | not assessed | |

## A6. Runtime manager, toolchains and build dependencies

| Tool | Job | omadeb | Omarchy | Today | Mac | First source on trixie (version) | Proof | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| mise | runtimes and tools | mise apt; key fetched with `curl`, no fingerprint check [OD-MISE] | base `mise-bin` [OA-PKG L84] | `60-dev`: mise apt; key via `curl \| gpg --dearmor`, no fingerprint check [MOD-60 L24-49] | yes | **V** `mise.jdx.dev/deb` 2026.10.7 (not in Debian) | apt; releases also carry minisign, OpenPGP and attestations [GHREL] | |
| Node.js | JS runtime | on demand: `mise use --global node`; npm wrappers use `node@latest` [OD-DEV][OD-NPMW] | `install dev-env node` [OA-DEV] | mise `node@lts`; apt `nodejs`/`npm` held [MOD-60 L136-143][MOD-00 L60-66] | mise LTS | M `core:node` | verified (OpenPGP signature on `SHASUMS256.txt`, `node.gpg_verify` default true) [MISE-NODE] | D 20.19.2. The doc doesn't say whose keys mise trusts. |
| Ruby (+ Rails) | language | dev-env: `ruby.compile false`, `ruby@latest`, `gem install rails` [OD-DEV L49-57] | dev-env; base `ruby` [OA-PKG L126] | build deps only (`60-dev`); apt `ruby` held | — | M `core:ruby`, precompiled from jdx/ruby | verified (attestation) [MISE-RUBY] | With the precompiled build, the `-dev` libraries are needed only for native gems. |
| Python | language | base `python3-pip`; dev-env `python@latest` + `uv@latest` [OD-DEV] | dev-env `python@latest`, then **piped `astral.sh/uv/install.sh`** [OA-DEV L71-73] | system `python3` only | uv-managed | M `core:python` (python-build-standalone) | verified (attestation) [MISE-PY] | D python3 3.13.5. |
| uv | Python tools | dev-env (mise) | dev-env (piped) | — | yes | **M** `aqua:astral-sh/uv` 0.13.0 | verified (attestation) | Not in trixie; forky has a source package only [MAD]. |
| pnpm | Node packages | `npm install -g pnpm` from Debian npm, inside each wrapper [OD-NPMW L32-36] | — | — | yes | **M** `aqua:pnpm/pnpm` 12.11.2 | verified (attestation) | Not in Debian. |
| Go | language | dev-env `go@latest` | dev-env `go@latest` | — | — | D golang-go 1.24; BP 1.27 | M `core:go`: integrity only (`.sha256` from the same mirror) [MISE-GO] → apt avoids an exception | |
| Rust | language | base `rustc` + `cargo` (D) **and** dev-env piped `sh.rustup.rs` [OD-PKG L12,L80][OD-DEV] | dev-env piped `sh.rustup.rs` [OA-DEV L97-98] | — | — | D 1.85.1; BP 1.95.0; D `rustup` 1.27.1 | apt; rustup's own download checks not assessed | **Overlap**: omadeb ends up with two Rust toolchains. |
| Bun, Deno | JS runtimes | dev-env (mise) | dev-env (mise) | — | — | M `core:bun`, `core:deno` | not assessed | |
| PHP, Elixir/Phoenix, Java, Zig, OCaml, .NET, Clojure, Scala | languages | dev-env (mise; PHP from apt; **OCaml via piped opam installer**) [OD-DEV] | the same set (Laravel and Symfony added) [OA-DEV][OA-M18] | — | — | mostly M `core:`/`aqua:` | not assessed | Both projects offer about 16 environments on demand. |
| build-essential, autoconf, bison, clang, pkg-config, cmake, `lib*-dev`, libjemalloc2 | native builds | base (adds cmake, pkg-config, libvips, libmagickwand-dev) [OD-PKG] | `base-devel` | `60-dev` (Ruby build deps), `00-base` build-essential | — | D (clang 19, cmake 3.31.6; BP cmake 4.3.4) | apt | |
| postgresql-client, sqlite3, redis-tools, MySQL client libs | DB clients | base (no redis-tools) | `postgresql-libs`, `mariadb-libs` | `60-dev` (all) | — | D 17 / 3.46.1 / 8.0.2 | apt | |

## A7. Containers

| Tool | Job | omadeb | Omarchy | Today | Mac | First source on trixie (version) | Proof | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Docker Engine | containers | Docker CE apt incl. `docker-ce-rootless-extras`; **adds the user to `docker`** [OD-DOCKER][OD-SETUPDOCKER L28] | base `docker`; user **not** in `docker`, an opt-in "Sudoless Docker" [OA-M18] | `70-lab`: Docker CE apt; **`usermod -aG docker`** [MOD-70 L64-82] | — | D docker.io 26.1.5; V Docker CE 29.9.0 | apt | **Overlap**: docker.io vs docker-ce. The baseline forbids the `docker` group. |
| Compose, Buildx | container tooling | V plugins | base | `70-lab` V plugins | — | D docker-compose 2.26.1, docker-buildx 0.13.1; V compose 5.6.0, buildx 0.38.0 | apt | |
| Podman | rootless containers | — | — | — | — | D 5.4.2 | apt | Daemonless alternative [MAC]. |
| Dev databases in containers | Postgres, MySQL, Redis… | `install-docker-dbs`, ports on `127.0.0.1` [OD-DBS] | the same [OA-M18] | Traefik and whoami stacks (`70-lab`) | — | images | n/a | |

## A8. AI coding agents

| Tool | Job | omadeb | Omarchy | Today | Mac | First source on trixie (version) | Proof | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Claude Code | agent | npm wrapper (`pnpm dlx @anthropic-ai/claude-code` on every run) [OD-NPM L1] | lazy mise stub `claude` [OA-MISE L6] | — | own installer | M `claude` = `aqua:anthropics/claude-code` 2.1.296 | the recipe declares only `SHASUMS256.txt`. The release also has `SHASUMS256.txt.sig` and an attestation on `claude-linux-x64.tar.gz` → attested, recipe silent | The npm package has no provenance [NPM]. |
| Codex | agent | npm wrapper | lazy mise stub | — | cask | M `aqua:openai/codex` 0.162.1 | the recipe declares nothing. The release has per-binary `.sigstore` bundles but no attestations. npm has SLSA provenance (unchecked by mise) → **exception** unless the Sigstore bundle is checked separately | |
| pi | agent | npm wrapper | lazy mise stub | — | own installer | M `aqua:earendil-works/pi` 1.1.0 | the recipe declares nothing. The release has only `SHA256SUMS`. npm has provenance (unchecked) → **exception** as above | |
| opencode | agent | npm wrapper (Omakasui also ships a `.deb` 1.18.35) | lazy mise stub | — | — | M `aqua:anomalyco/opencode` 1.19.0 | attested, recipe silent | |
| GitHub Copilot CLI | agent | npm wrapper | lazy mise stub | — | — | M `aqua:github/copilot-cli` 1.0.95 | integrity only; npm has no provenance → **exception** | |
| Gemini CLI | agent | npm wrapper | — | — | — | M `gemini-cli` = `npm:@google/gemini-cli` 0.63.0 | npm has no provenance → **exception** | |
| crush | agent | — | lazy mise stub | — | — | M `aqua:charmbracelet/crush` 0.98.1 | verified (cosign; identity is the release workflow) | |
| Playwright CLI | browser automation | npm wrapper | mise `npm:playwright` | — | — | M `npm:playwright` 1.64.0 | npm provenance (unchecked) | |
| antigravity, grok, cursor-agent, oh-my-pi, hey, basecamp, cf, ori, muse | agents and vendor CLIs | — | lazy mise stubs; cursor-agent and muse use the `http:` backend [OA-MISE L8-24] | — | — | M | `cursor-agent`'s registry entry declares no checksum [MREG]; the rest not assessed | |
| sfw (Socket Firewall) | npm/pnpm supply-chain wrapper | — | — | `60-dev`: `npm install -g sfw@2.0.4` under mise node [MOD-60 L126-144] | mise `npm:` | M `npm:sfw` 2.0.6 (not in the registry) | npm SLSA provenance (unchecked by mise) | |

## A9. Identity, secrets and network CLIs

| Tool | Job | omadeb | Omarchy | Today | Mac | First source on trixie (version) | Proof | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1Password app | passwords, SSH agent, commit signing | opt: `wget …/1password-latest.deb`, then `apt install ./` [OD-1P] | opt `install-service-1password` | — | yes | V 1Password apt 8.12.40 | apt (after the first fetch) | The SSH agent and signing setup on the Mac depend on it [MAC]. |
| 1Password CLI (`op`) | secrets CLI | — | — | — | yes | V 2.40.0; M `1password` (vfox, `aqua:1password/cli` http) | apt; M: none declared | |
| Tailscale | mesh VPN | opt: Tailscale apt [OD-TS] | opt | — | — | V Tailscale trixie 1.104.1 | apt | |
| ufw, ufw-docker | firewall front end | base (ufw D, ufw-docker Omakasui) [OD-PKG L88-89] | base | nftables instead (`30-security`) | — | D ufw 0.36.2 | apt | **Overlap** with today's nftables. The security baseline is another ticket's question. |

## A10. Fonts

| Tool | Job | omadeb | Omarchy | Today | Mac | First source on trixie (version) | Proof | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| JetBrains Mono Nerd Font | code and terminal font | opt `fonts-jetbrains-mono` (no Nerd glyphs) [OD-FONT] | base `ttf-jetbrains-mono-nerd-basic` [OA-PKG L141] | `40-desktop`: Nerd Fonts v3.4.0 zip, **no checksum** [MOD-40 L38-39] | yes | U Nerd Fonts v3.5.1 (`SHA-256.txt` only) | integrity only → **exception** | D `fonts-jetbrains-mono` 2.304 has no Nerd glyphs. |
| Cascadia Mono NF | omadeb's default font | base (Omakasui 3.5.0) | — | — | — | D `fonts-cascadia-code` 2407.24 (not the NF build) | apt / n/a | |

# Part B: GUI apps that run on any desktop

These are desktop apps whose choice doesn't hinge on the desktop. Integration (default terminal, launcher entries, theming) still does.

| Tool | Job | omadeb | Omarchy | Today | Mac | First source on trixie (version) | Proof | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Ghostty | terminal | opt (Omakasui 1.3.1) [OD-TERM] | opt [OA-TERM] | `40-desktop`: community `.deb` mkasberg 1.3.1-0.ppa2, the default terminal [MOD-40 L29-30, L256-270] | yes | none in D or the mise registry; upstream ships no Linux binaries [MAC]. R: Omakasui `ghostty` 1.3.1-1+trixie [OMK] | community `.deb` with no proof → **exception** (or build from source). R is signed by Omakasui, not by the Ghostty project | Omakasui's build is the only apt route. |
| Alacritty | terminal | **default** (Omakasui 0.17.0) [OD-PKG L3]; first in [`config/xdg-terminals.list`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/config/xdg-terminals.list) | opt | — | — | D 0.15.1 | apt | **Overlap**: four terminals across the sets. |
| foot | terminal | — (Omakasui ships it) | **default** [OA-PKG L46][OA-M15] | — | — | D 1.21.0 | apt | Wayland-only. |
| kitty | terminal | opt | opt | — | — | D 0.41.1 | apt | |
| Google Chrome | browser | opt (Google apt) [OD-CHROME] | opt | — | default | V Google 155.0.8059.39 | apt | |
| Chromium | browser | base | base, the default [OA-PKG L17] | — | — | D 154.0.8037.92 (trixie-security) | apt | Omarchy's web apps are Chromium windows. |
| Firefox | browser | base `firefox-esr` | — | `40-desktop` `firefox-esr` | — | D firefox-esr 153.4.0esr (trixie-security); V Mozilla `firefox` 157.0.1 | apt | **Overlap**: three browsers across the sets. |
| LibreOffice | office | base | base (`libreoffice-fresh`) | — | — | D 25.2.3; BP 26.8.0.3 | apt | |
| Obsidian | notes | opt (Omakasui 1.14.4) | base | — | — | U `obsidian_1.14.4_amd64.deb` | none → **exception** | Not in Debian. |
| LocalSend | file transfer | base (Omakasui 1.18.2) | base | — | — | U `.deb` 1.18.2 | none → **exception** | Not in Debian. |
| Pinta | image editing | base (Omakasui 3.0.5) | base | — | — | not in trixie | n/a | |
| Xournal++ | PDF annotation | base | base | — | — | D 1.2.6; BP 1.3.1 | apt | |
| mpv, imv | media viewers | base | base | `loupe` (image) | — | D 0.40.0 / 4.5.0 | apt | |
| Web apps | site launchers | WhatsApp, ChatGPT, YouTube, GitHub [OD-WEB] | about ten `.desktop` web apps [OA-APPS] | — | — | browser-dependent | n/a | |
| Discord, Signal, Spotify, Typora, Dropbox, Steam, Ollama… | misc | opt | opt | — | — | various | not assessed | |

# Part C: Desktop-bound

Their value or their existence depends on the desktop choice: GNOME (omadeb, today) or Hyprland with Quickshell (Omarchy).

| Tool | Job | omadeb | Omarchy | Today | Mac | First source on trixie (version) | Proof | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Launcher | app and command launcher | `omadeb-walker`: Walker 2.17.1 + Elephant providers (Omakasui) [OMK] | built into the Quickshell shell, Super+Space [OA-M05] | GNOME overview | Spotlight | Walker/Elephant: U v2.17.2 / v2.22.1, no proofs [GHREL][ADR]; R: Omakasui `walker` 2.17.1-1+trixie, `elephant` 2.22.1-1+trixie [OMK]; Quickshell: BP 0.3.0 | Walker → **exception** upstream; R is a third-party rebuild | **Overlap** across the three designs. The same Omakasui repo also carries `niri` 26.04-1+trixie (a compositor, for the desktop ticket). |
| wl-clipboard | Wayland clipboard CLI | base | base | — | n/a | D 2.2.1; BP 2.3.0 | apt | |
| Screenshots and recording | capture | `flameshot` | `grim` + `slurp` + `gpu-screen-recorder` | `40-desktop` `flameshot` | `screencapture` | D flameshot 12.1.0 (BP 13.3.0), grim 1.4.0, slurp 1.5.0; gpu-screen-recorder not in trixie (forky source only) | apt | **Overlap** |
| xdg-terminal-exec | default-terminal launcher | base (Omakasui 0.14.3) | base | — | n/a | D 0.12.3 | apt | |
| Nautilus and add-ons | files | GNOME's + `gnome-sushi`, `nautilus-open-any-terminal` (Omakasui), `python3-nautilus` | base `nautilus`, `sushi`, `nautilus-python` | `40-desktop` `nautilus`, `file-roller` | Finder | D nautilus 48.3, gnome-sushi 46.0 | apt | |
| GNOME tooling | settings, extensions | `gnome-tweaks`, Extension Manager; extensions via pipx `gnome-extensions-cli` | n/a | `gnome-tweaks`, Extension Manager; five EGO extensions downloaded at run time [MOD-40 L186-190] | n/a | D | apt; EGO downloads have no proof | |
| GNOME apps | editor, calculator, monitor, viewers | (GNOME defaults) | n/a | `gnome-text-editor`, `gnome-calculator`, `gnome-system-monitor`, `loupe`, `evince` [MOD-40 L44-52] | n/a | D | apt | |
| Themes, cursors, fonts | look | Yaru GTK, icons, sound and shell (Omakasui) | Omarchy themes, `yaru-icon-theme` | Gruvbox GTK and icons (pinned GitHub tarballs, no checksum), `bibata-cursor-theme`, Inter, Noto [MOD-40 L20-39] | n/a | D bibata 2.0.6, Inter 4.1, Yaru 24.04.3 | apt; tarballs have no proof | |
| flatpak + Flathub | app source | base; adds Flathub [OD-FLAT] | — | — | n/a | D flatpak 1.16.6 | Flathub is not in the baseline's source order | |
| Omarchy's own apps | Hype, Monologue, omacalc, omacut, omawrite, omasnap, Aether, OWE, Superwhisper, gliff, disktree | — | base [OA-PKG][OA-PRE] | — | — | Arch/Omarchy repos only | n/a | |
| tlp, plymouth-themes, asdcontrol | power, boot splash, Apple display brightness | base | asdcontrol | — | n/a | D tlp 1.8.0 (BP 1.10.2) | apt | Hardware ticket's concern. |

# Overlaps

Two or more tools doing one job, across or within the four sets:

| Job | Tools | Where they collide |
| --- | --- | --- |
| Interactive shell | bash, zsh | Both projects configure bash; today and the Mac use zsh. |
| System monitor | btop, htop | Today installs both. |
| tldr client | tealdeer, tlrc, Arch `tldr` | Mac `tlrc`, Omarchy `tldr`. |
| Python app installer | pipx, `uv tool` | omadeb pipx, Mac uv. |
| Rust toolchain | Debian `rustc`/`cargo`, rustup | omadeb installs both. |
| Multiplexer | tmux, zellij, herdr | Each project ships a different one or two. |
| Container engine | docker.io, Docker CE, Podman | Debian vs vendor build of the same engine. |
| Firewall front end | ufw (+ ufw-docker), nftables | Both projects vs today. |
| Terminal | Ghostty, Alacritty, foot, kitty | A different default in each set. |
| Browser | Chrome, Chromium, Firefox ESR / Mozilla Firefox | A different default in each set. |
| Screenshots | flameshot, grim + slurp | Desktop-dependent. |
| Launcher | Walker, the Quickshell shell, GNOME overview | Desktop-dependent. |
| Neovim package | Debian `neovim`, Omakasui `nvim` | Same program, different package names and versions. |
| gh source | Debian, mise (`aqua:cli/cli`), GitHub's apt repo | Three channels; only Debian's is 2.46.0. |

# Exception-only under the ADR

A tool lands here when no apt source in the baseline order ships it and no route checks a signature or attestation. Under the ADR, admitting it needs a named exception with a pinned, reviewed digest [ADR].

- **Desktop-independent:**
  - lazydocker
  - zellij
  - Helix
  - the JetBrains Mono Nerd Font
  - the Copilot CLI, the Gemini CLI
  - Codex and pi, unless the Sigstore bundle (Codex) or npm provenance is checked outside mise
  - the 1Password CLI through mise (the vendor apt avoids this)
- **Desktop and GUI:**
  - Ghostty (community `.deb`, or a source build that this note did not cost)
  - Walker and Elephant
  - Obsidian
  - LocalSend
  - GNOME extensions from extensions.gnome.org
  - Gruvbox theme tarballs
- **Only when newer than Debian is wanted:** starship, fzf, zoxide, ripgrep, bat, eza, git-delta, lazygit, gitleaks, neovim, btop, fastfetch, shellcheck and the Go toolchain. All are integrity-only or unproven through mise. Their Debian or backports builds need no exception.

Omakasui's signed trixie repo (R) carries apt builds of several of these: Ghostty 1.3.1-1+trixie, Walker 2.17.1-1+trixie, Elephant 2.22.1-1+trixie, lazydocker 0.25.2, zellij 0.45.1, Zed 1.23.2, Obsidian 1.14.4, LocalSend 1.18.2 and Pinta 3.0.5 [OMK]. It is a third-party rebuild, not the vendor's own repo. Under the baseline it is not a source in the order, so it does not take these tools out of exception status. Adopting it would need its own decision, and an apt pin that holds it to the packages it is meant to supply.

Tools whose upstream publishes an attestation that the mise registry recipe does not declare (Claude Code, opencode, fd, direnv, hunk, Zed) are not exceptions if installed through mise's `github:` backend, which checks attestations when present [MISE-GH]. Whether that satisfies the ADR's "identity committed in the repo" is open (see Gaps).

# Today's modules against the baseline

These findings come from reading the modules for the table above. They are listed because they bear on where each tool would come from.

| Where | What it does | Baseline rule it meets |
| --- | --- | --- |
| `50-shell.sh` L43-51 | `curl -fsSL https://starship.rs/install.sh \| sh` | no piped installers |
| `60-dev.sh` L24-36 | mise apt key via `curl \| gpg --dearmor`, no fingerprint compared | `Signed-By` with a fingerprint committed in the repo |
| `60-dev.sh` L78-93 | VS Code `.deb` downloaded over HTTPS and installed, no signature check | verified or exception |
| `60-dev.sh` L102-110 | lazydocker tarball piped into `tar`, no checksum | verified or exception with a pinned digest |
| `40-desktop.sh` L29-30, L256-270 | Ghostty community `.deb`, no checksum | the same |
| `40-desktop.sh` L38-39, L88-130 | Nerd Font zip and Gruvbox tarballs, no checksum | the same |
| `40-desktop.sh` L142-190 | GNOME extensions fetched from extensions.gnome.org at run time | never fetch and run unreviewed code |
| `70-lab.sh` L77-83 | `usermod -aG docker` | no root-equivalent groups |

# Gaps

- **Arch to Debian mapping.** Omarchy's list names Arch packages. Their Debian counterparts were matched by name and job, not by checking Arch's build options. Arch package versions were not recorded.
- **Omarchy release vs head.** Omarchy's `v4.0.4` tag (`c668141e`) sits on a different line from `quattro` head (813 commits ahead, 109 behind). This note reads head. The package list changed noticeably in two days.
- **"Identity committed in the repo".** mise's aqua recipes carry the signer identity in the aqua registry, not in this repo. mise's lockfile records provenance once verified, and `locked_verify_provenance` re-checks it [MISE-LOCK]. Whether a lockfile entry counts as the committed identity the ADR asks for is for the shell and dev-tool step ticket.
- **Whose keys.** mise's Node docs don't say which OpenPGP keys it trusts for `SHASUMS256.txt` [MISE-NODE].
- **Not assessed.** Proofs for Bun, Deno, the other `dev-env` languages, rustup's toolchain downloads, Cursor, and Omarchy's `http:`-backend agents.
- **Codex's Sigstore bundles** were seen on the release but not verified with `cosign`.
- **Version snapshot.** Versions are as of 2026-10-11. The Mac inventory dates from 2026-10-09 and was not re-gathered.

# Sources

All fetched or queried 2026-10-11.

**omadeb at `654f5964`** (base URL `https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/`)

- [OD-PKG] [`install/omadeb-base.packages`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/omadeb-base.packages)
- [OD-NPM] [`install/packaging/npm.sh`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/packaging/npm.sh)
- [OD-NPMW] [`bin/omadeb-npm-install`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-npm-install) (sets `PNPM_CONFIG_MINIMUM_RELEASE_AGE=7200`)
- [OD-MISE] [`install/packaging/mise.sh`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/packaging/mise.sh)
- [OD-DOCKER] [`install/packaging/docker.sh`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/packaging/docker.sh); [OD-SETUPDOCKER] [`bin/omadeb-setup-docker` L28](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-setup-docker#L28)
- [OD-DBS] [`bin/omadeb-install-docker-dbs`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-install-docker-dbs)
- [OD-DEV] [`bin/omadeb-install-dev-env`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-install-dev-env)
- [OD-TERM] [`bin/omadeb-install-terminal`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-install-terminal)
- [OD-VSC] [`bin/omadeb-install-vscode`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-install-vscode)
- [OD-1P] [`bin/omadeb-install-1password`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-install-1password)
- [OD-CHROME] [`bin/omadeb-install-browser-chrome`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-install-browser-chrome)
- [OD-TS] [`bin/omadeb-install-tailscale`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-install-tailscale)
- [OD-CURSOR] [`bin/omadeb-install-cursor`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-install-cursor)
- [OD-FONT] [`bin/omadeb-install-font`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-install-font)
- [OD-MENU] [`bin/omadeb-menu`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-menu) (L363-378 services, L465-485 editors and terminals)
- [OD-KEY] [`bin/omadeb-update-keyring`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/bin/omadeb-update-keyring)
- [OD-PIPX] [`install/packaging/pipx.sh`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/packaging/pipx.sh); [OD-FLAT] [`install/packaging/flathub.sh`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/packaging/flathub.sh); [OD-WEB] [`install/packaging/webapps.sh`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/packaging/webapps.sh)
- [OD-PRES] [`install/helpers/presentation.sh` L1-3](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/install/helpers/presentation.sh#L1-L3)
- [OD-SH] [`default/bash/init`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/default/bash/init); [OD-ALIAS] [`default/bash/aliases`](https://github.com/omakasui/omadeb/blob/654f5964cf212483df5b3c1b2a9a15ac9a115ab4/default/bash/aliases)

**Omakasui apt repos**

- [OMK] Package indexes [`packages.omakasui.org/dists/trixie/main/binary-amd64/Packages`](https://packages.omakasui.org/dists/trixie/main/binary-amd64/Packages) and [`core.omakasui.org/dists/trixie/main/binary-amd64/Packages`](https://core.omakasui.org/dists/trixie/main/binary-amd64/Packages); `Release` files alongside.
- [OMK-KR] [`packages.omakasui.org/omakasui-archive-keyring/trixie.deb`](https://packages.omakasui.org/omakasui-archive-keyring/trixie.deb): ships `/etc/apt/sources.list.d/omakasui.sources` (with `Signed-By: /usr/share/keyrings/omakasui-packages.gpg`) and no `/etc/apt/preferences.d` file.

**Omarchy at `35a55fd2`** (base URL `https://github.com/omacom/omarchy/blob/35a55fd236598598130711249a647e0071532e9a/`)

- [OA-PKG] [`install/omarchy-base.packages`](https://github.com/omacom/omarchy/blob/35a55fd236598598130711249a647e0071532e9a/install/omarchy-base.packages)
- [OA-MISE] [`install/user/mise.sh`](https://github.com/omacom/omarchy/blob/35a55fd236598598130711249a647e0071532e9a/install/user/mise.sh); [OA-MISEW] [`bin/omarchy-mise-install`](https://github.com/omacom/omarchy/blob/35a55fd236598598130711249a647e0071532e9a/bin/omarchy-mise-install)
- [OA-DEV] [`bin/omarchy-install-dev-env`](https://github.com/omacom/omarchy/blob/35a55fd236598598130711249a647e0071532e9a/bin/omarchy-install-dev-env)
- [OA-TERM] [`bin/omarchy-install-terminal`](https://github.com/omacom/omarchy/blob/35a55fd236598598130711249a647e0071532e9a/bin/omarchy-install-terminal)
- [OA-PRE] [`bin/omarchy-install-preinstalls`](https://github.com/omacom/omarchy/blob/35a55fd236598598130711249a647e0071532e9a/bin/omarchy-install-preinstalls); [OA-APPS] [`applications/`](https://github.com/omacom/omarchy/tree/35a55fd236598598130711249a647e0071532e9a/applications)
- Manual: [OA-M05] [`manual/05-the-top-bar.md`](https://github.com/omacom/omarchy/blob/35a55fd236598598130711249a647e0071532e9a/manual/05-the-top-bar.md), [OA-M15] [`15-terminal.md`](https://github.com/omacom/omarchy/blob/35a55fd236598598130711249a647e0071532e9a/manual/15-terminal.md), [OA-M17] [`17-ai.md`](https://github.com/omacom/omarchy/blob/35a55fd236598598130711249a647e0071532e9a/manual/17-ai.md), [OA-M18] [`18-development-tools.md`](https://github.com/omacom/omarchy/blob/35a55fd236598598130711249a647e0071532e9a/manual/18-development-tools.md), [OA-M19] [`19-shell-tools.md`](https://github.com/omacom/omarchy/blob/35a55fd236598598130711249a647e0071532e9a/manual/19-shell-tools.md), [OA-M21] [`21-tuis.md`](https://github.com/omacom/omarchy/blob/35a55fd236598598130711249a647e0071532e9a/manual/21-tuis.md)
- Package-list diff since the earlier pin: [`988f44ea...35a55fd2`](https://github.com/omacom/omarchy/compare/988f44ea1a16250785eee1c73cbaf558080589db...35a55fd236598598130711249a647e0071532e9a)

**This repo**

- [MOD-00] [`modules/00-base.sh`](https://github.com/iamivanhx/debian-setup/blob/cab5fbffa90e4ab8c675eb9d8d3714e18bd995d2/modules/00-base.sh), [MOD-40] [`40-desktop.sh`](https://github.com/iamivanhx/debian-setup/blob/cab5fbffa90e4ab8c675eb9d8d3714e18bd995d2/modules/40-desktop.sh), [MOD-50] [`50-shell.sh`](https://github.com/iamivanhx/debian-setup/blob/cab5fbffa90e4ab8c675eb9d8d3714e18bd995d2/modules/50-shell.sh), [MOD-60] [`60-dev.sh`](https://github.com/iamivanhx/debian-setup/blob/cab5fbffa90e4ab8c675eb9d8d3714e18bd995d2/modules/60-dev.sh), [MOD-70] [`70-lab.sh`](https://github.com/iamivanhx/debian-setup/blob/cab5fbffa90e4ab8c675eb9d8d3714e18bd995d2/modules/70-lab.sh), all at `cab5fbff`.
- [ADR] [`docs/adr/20261010-pin-outside-apt.md`](https://github.com/iamivanhx/debian-setup/blob/cab5fbffa90e4ab8c675eb9d8d3714e18bd995d2/docs/adr/20261010-pin-outside-apt.md)
- [MAC] [`docs/research/macos-inventory-and-tools.md` at `4e336275`](https://github.com/iamivanhx/debian-setup/blob/4e336275f7f3b83d418c9ccbc2c8a32164e03d83/docs/research/macos-inventory-and-tools.md)
- [ARCH] [`docs/research/omarchy-omadeb-architecture.md` at `e81cf38d`](https://github.com/iamivanhx/debian-setup/blob/e81cf38df5375d7c8af897b50c8882839e0ab1d8/docs/research/omarchy-omadeb-architecture.md)

**Debian**

- [MAD] Debian QA archive index: `https://qa.debian.org/madison.php?package=<names>&table=debian&s=trixie,trixie-security,trixie-updates,trixie-backports,forky&text=on`
- [APTPREF] [`apt_preferences(5)`, trixie](https://manpages.debian.org/trixie/apt/apt_preferences.5.en.html): "If two or more versions have the same priority, install the most recent one (that is, the one with the higher version number)."

**mise and aqua**

- [MREG] mise registry at `v2026.10.7`, e.g. [`registry/claude.toml`](https://github.com/jdx/mise/blob/4599c53b4286ff101de876f8122feec0797b48b2/registry/claude.toml), [`registry/github-cli.toml`](https://github.com/jdx/mise/blob/4599c53b4286ff101de876f8122feec0797b48b2/registry/github-cli.toml), [`registry/herdr.toml`](https://github.com/jdx/mise/blob/4599c53b4286ff101de876f8122feec0797b48b2/registry/herdr.toml), [`registry/cursor-agent.toml`](https://github.com/jdx/mise/blob/4599c53b4286ff101de876f8122feec0797b48b2/registry/cursor-agent.toml), [`registry/gemini-cli.toml`](https://github.com/jdx/mise/blob/4599c53b4286ff101de876f8122feec0797b48b2/registry/gemini-cli.toml). Not in the registry: `ghostty`, `walker`, `zed`, `satty`, `sfw`.
- [AQUA] aqua-registry at `63d7f713`: `pkgs/<owner>/<repo>/registry.yaml`, read for the catch-all (`version_constraint: "true"`) override. For example: [`cli/cli`](https://github.com/aquaproj/aqua-registry/blob/63d7f713918fcc226c94db42988f7bf0ff6084d6/pkgs/cli/cli/registry.yaml) (attestation), [`mikefarah/yq`](https://github.com/aquaproj/aqua-registry/blob/63d7f713918fcc226c94db42988f7bf0ff6084d6/pkgs/mikefarah/yq/registry.yaml) (cosign), [`anthropics/claude-code`](https://github.com/aquaproj/aqua-registry/blob/63d7f713918fcc226c94db42988f7bf0ff6084d6/pkgs/anthropics/claude-code/registry.yaml) (checksum only), [`openai/codex`](https://github.com/aquaproj/aqua-registry/blob/63d7f713918fcc226c94db42988f7bf0ff6084d6/pkgs/openai/codex/registry.yaml) (none).
- [MISE-AQUA] [mise: aqua backend](https://mise.jdx.dev/dev-tools/backends/aqua.html) ("Which checks run depends on what each package's recipe declares").
- [MISE-GH] [mise: github backend](https://mise.jdx.dev/dev-tools/backends/github.html) ("on public GitHub it checks GitHub artifact attestations when the release has them").
- [MISE-NPM] [mise: npm backend](https://mise.jdx.dev/dev-tools/backends/npm.html) (no provenance or signature check described).
- [MISE-LOCK] [mise: `mise.lock`](https://mise.jdx.dev/dev-tools/mise-lock.html).
- [MISE-NODE] [mise: Node](https://mise.jdx.dev/lang/node.html); [MISE-RUBY] [Ruby](https://mise.jdx.dev/lang/ruby.html); [MISE-PY] [Python](https://mise.jdx.dev/lang/python.html); [MISE-GO] [Go](https://mise.jdx.dev/lang/go.html).

**Upstream and vendor**

- [GHREL] GitHub REST: `GET /repos/{owner}/{repo}/releases/latest` (assets, per-asset `digest`) and `GET /repos/{owner}/{repo}/attestations/{digest}` for the linux x86_64 asset. Repos queried: anthropics/claude-code, openai/codex, anomalyco/opencode, earendil-works/pi, github/copilot-cli, charmbracelet/crush, starship/starship, jesseduffield/lazygit, jesseduffield/lazydocker, gitleaks/gitleaks, ajeetdsouza/zoxide, eza-community/eza, BurntSushi/ripgrep, sharkdp/fd, sharkdp/bat, dandavison/delta, junegunn/fzf, neovim/neovim, helix-editor/helix, zellij-org/zellij, aristocratos/btop, fastfetch-cli/fastfetch, koalaman/shellcheck, sxyazi/yazi, casey/just, direnv/direnv, Wilfred/difftastic, mikefarah/yq, astral-sh/uv, pnpm/pnpm, cli/cli, tldr-pages/tlrc, atuinsh/atuin, jdx/mise, tmux/tmux-builds, alexpasmantier/television, modem-dev/hunk, herdrdev/herdr, zed-industries/zed, abenz1267/walker, abenz1267/elephant, ryanoasis/nerd-fonts, mkasberg/ghostty-ubuntu, obsidianmd/obsidian-releases, localsend/localsend.
- [NPM] npm registry `https://registry.npmjs.org/<pkg>/latest`, field `dist.attestations.provenance` (SLSA v1 present for sfw, @kitlangton/ghui, playwright, @openai/codex, @earendil-works/pi-coding-agent; absent for @anthropic-ai/claude-code, @google/gemini-cli, @github/copilot, opencode-ai).
- [VAPT] Vendor apt `Packages` (amd64): [Microsoft VS Code](https://packages.microsoft.com/repos/code/dists/stable/main/binary-amd64/Packages.gz), [Google Chrome](https://dl.google.com/linux/chrome/deb/dists/stable/main/binary-amd64/Packages.gz), [1Password](https://downloads.1password.com/linux/debian/amd64/dists/stable/main/binary-amd64/Packages.gz), [Docker trixie](https://download.docker.com/linux/debian/dists/trixie/stable/binary-amd64/Packages.gz), [Tailscale trixie](https://pkgs.tailscale.com/stable/debian/dists/trixie/main/binary-amd64/Packages.gz), [mise](https://mise.jdx.dev/deb/dists/stable/main/binary-amd64/Packages.gz), [Mozilla](https://packages.mozilla.org/apt/dists/mozilla/main/binary-amd64/Packages.gz), [GitHub CLI](https://cli.github.com/packages/dists/stable/main/binary-amd64/Packages).
