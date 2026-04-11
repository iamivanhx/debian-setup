# 70-lab module: Docker + Traefik + Avahi + avahi-aliases + whoami (DEEP)

## Type

AFK

## Phase

Phase 3: Lab + Backup + Disaster Drill

## Parent plan

../../ser8-dev-setup.md

## What to build

The highest-value module and the second deepest after 20-storage. Fill in `modules/70-lab.sh` so that the SER8 becomes a LAN-visible, multi-project Docker host with zero-config reachability from every device at home.

Concrete sub-deliverables (treat these as internal sub-steps with their own guards — the module is one file but should read as a clean sequence of sub-procedures):

### 70-lab-a: Docker CE install

- docker.com apt repo + GPG key (keyring file at `/etc/apt/keyrings/docker.asc`, sources file at `/etc/apt/sources.list.d/docker.list`), guarded.
- `apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`, guarded.
- Add primary user to `docker` group via `usermod -aG docker $PRIMARY_USER`, guarded by `guard::user_in_group`.
- Verify the `daemon.json` data-root from 20-storage is in effect: `docker info | grep -q "Docker Root Dir: /srv/data/docker"`. If not, fail with "20-storage did not land the daemon.json drop-in — investigate."
- `systemctl enable --now docker.service`, guarded.

### 70-lab-b: Avahi + vendored avahi-aliases

- Install `avahi-daemon` from apt.
- Vendored `avahi-aliases` under `lib/avahi-aliases/` (copied into the repo in this issue as a one-time vendoring from upstream — document the upstream URL and version in a `VENDORED.md` file next to the copy).
- Install the vendored binary to `/usr/local/sbin/avahi-aliases` via `deploy_config`, guarded.
- Create `/etc/avahi/aliases` as an empty file if absent (guarded by `guard::file_exists`).
- Template `/etc/systemd/system/avahi-aliases.service` with `After=avahi-daemon.service`, `Restart=always`, `ExecStart=/usr/local/sbin/avahi-aliases /etc/avahi/aliases`.
- Template `/etc/systemd/system/avahi-aliases.path` watching `/etc/avahi/aliases` with `TriggerLimitIntervalSec=5` and `PathChanged` directive that triggers `avahi-aliases.service` on change.
- `systemctl daemon-reload` (only if any unit file was changed — checkable via file mtime or a content guard).
- `systemctl enable --now avahi-daemon.service avahi-aliases.service avahi-aliases.path`, guarded.

### 70-lab-c: Traefik + external network + whoami reference

- `docker network create traefik-proxy`, guarded by `guard::docker_network_exists traefik-proxy`.
- Create directory `/srv/data/lab/compose/traefik/` (guarded).
- Template `/srv/data/lab/compose/traefik/docker-compose.yml` from `templates/srv/data/lab/compose/traefik/docker-compose.yml` — Traefik v3 container with:
  - `command:` args: `--providers.docker=true --providers.docker.exposedByDefault=false --providers.docker.network=traefik-proxy --entrypoints.web.address=:80 --entrypoints.websecure.address=:443`.
  - Volume mount for `/var/run/docker.sock:/var/run/docker.sock:ro`.
  - Network: `traefik-proxy` (external).
  - Ports: 80 and 443 published to host.
  - `restart: unless-stopped`.
- `docker compose -f /srv/data/lab/compose/traefik/docker-compose.yml up -d`, guarded by `guard::container_running traefik`.
- Create directory `/srv/data/lab/compose/whoami/` (guarded).
- Template `/srv/data/lab/compose/whoami/docker-compose.yml` from `templates/srv/data/lab/compose/whoami/docker-compose.yml` — `containous/whoami` (or `traefik/whoami`) container with:
  - Network: `traefik-proxy` (external).
  - Labels: `traefik.enable=true`, `traefik.http.routers.whoami.rule=Host(\`whoami.local\`)`, `traefik.http.routers.whoami.entrypoints=web`, `traefik.http.services.whoami.loadbalancer.server.port=80`.
- `docker compose -f /srv/data/lab/compose/whoami/docker-compose.yml up -d`, guarded by `guard::container_running whoami`.
- Append `whoami.local` to `/etc/avahi/aliases` (guarded by `guard::file_has_line`). The `.path` unit will pick up the change and republish.

### 70-lab-d: smoke test

- `smoke_70_lab`:
  - Docker service active.
  - Primary user in docker group.
  - `traefik-proxy` network exists.
  - Traefik container running.
  - whoami container running.
  - `/etc/avahi/aliases` contains `whoami.local`.
  - `getent hosts whoami.local` resolves to a `192.168.*` or similar LAN address (from the SER8 itself, which has Avahi running).
  - `curl -sf -H 'Host: whoami.local' http://127.0.0.1` returns 200 with whoami's body.

## Acceptance criteria

- [ ] `./run.sh 70-lab` on a converged Phase 2 machine installs Docker, sets up Traefik + Avahi, and brings up whoami as a running container.
- [ ] `./run.sh --dry-run 70-lab` on the converged box reports zero planned actions.
- [ ] From the SER8 itself: `curl http://whoami.local` returns 200 with whoami's body text.
- [ ] From a LAN client (laptop or phone on the same Wi-Fi): `curl http://whoami.local` returns 200.
- [ ] Adding a new line to `/etc/avahi/aliases` (e.g. `testproject.local`) causes the systemd `.path` unit to trigger `avahi-aliases.service` within ~5s, and the new name resolves.
- [ ] `docker info` reports `Docker Root Dir: /srv/data/docker`.
- [ ] `smoke_70_lab` passes.
- [ ] Shellcheck + shfmt + pre-commit clean.

## Blocked by

- Blocked by 008-module-20-storage.md (needs `daemon.json` and the ordering drop-in in place before Docker first starts)
- Blocked by 014-delete-legacy-beelink.md (Phase 2 must be clean)

## Implementation notes

- **Vendoring avahi-aliases:** copy the upstream tool into `lib/avahi-aliases/` with its license and a `VENDORED.md` recording the source URL and git sha. This avoids a runtime fetch and makes the install deterministic.
- **The `.path` unit** is the slickest integration point — verify it fires in testing by echoing to `/etc/avahi/aliases` and polling `getent hosts` for the new name. If it doesn't fire, check `TriggerLimitIntervalSec` and the path directive syntax.
- **Docker data-root check** (70-lab-a): the check that `docker info` reports `/srv/data/docker` as the data dir is load-bearing — if 20-storage didn't land cleanly, this module must fail loudly BEFORE Docker starts creating data in the wrong place.
- **Traefik v3 config** is via command-line args in the compose file, not a static file provider. This matches PRD §10.6 (static config in env/command args, dynamic config via Docker labels).
- **No HTTPS in v1.** The `websecure` entrypoint is declared but no cert setup. A future HTTPS issue (not in v1) will add mkcert or similar.
- **`./run.sh lab-up <project>`** convenience target is wired in `run.sh` — it's a thin wrapper around `docker compose -f /srv/data/lab/compose/$1/docker-compose.yml up -d` + `systemctl reload avahi-aliases`. Document it in `docs/projects.md` (issue 017).
- This module is deep: consider splitting into 70-lab-a.sh, 70-lab-b.sh, 70-lab-c.sh functions within the same file for readability, each with its own guarded sub-deliverables.

## Requirements addressed

- Plan Phase 3, `70-lab.sh` bullet (deep module)
- PRD §5.8 (Test-staging platform)
- PRD §10.1 table, 70-lab row
- PRD §10.2 (deep-module analysis, 70-lab)
- PRD §10.6 (Traefik + Avahi integration)
- PRD User Story 14, 15, 16, 17, 18, 19, 20
- PRD §12 R2 (avahi-aliases fragility mitigation)
- PRD §12 R3 (multi-project isolation)
