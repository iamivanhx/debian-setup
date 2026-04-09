# `lab` role: Docker + Tailscale + Traefik + whoami

## Type

AFK

## Phase

Phase 2: Workstation + Lab

## Parent plan

../../debian-dev-lab.md

## What to build

Implement the `lab` role end-to-end: Docker CE + Compose plugin from docker.com, Tailscale from the upstream apt repo, the `/srv/data/lab/{compose,volumes,secrets}/` scaffold with a drop-in convention README, the Traefik v3 Compose stack with Docker provider and `web`/`websecure` entrypoints managed by a systemd drop-in that runs `docker compose up -d` on boot, and a `whoami` example Compose file that proves the round-trip from a second Tailscale peer over plain HTTP.

See parent plan, Phase 2 → `lab` deliverable and implementation notes, plus PRD §10 lab module and the locked decision "Plain HTTP over Tailscale only in v1".

## Acceptance criteria

- [ ] docker.com apt repo + signing key configured idempotently.
- [ ] `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-compose-plugin` installed.
- [ ] Primary user added to `docker` group.
- [ ] Tailscale apt repo + key configured idempotently; `tailscale` package installed.
- [ ] Tailscale brought up via `tailscale up` using a vaulted auth key when present, otherwise the role surfaces a clear "run `tailscale up` manually" message and continues.
- [ ] `/srv/data/lab/{compose,volumes,secrets}/` directories created with sensible perms.
- [ ] `/srv/data/lab/README.md` documents the drop-in convention (drop a `compose/<svc>/compose.yml`, `docker compose up -d`, reach it at `http://<svc>.lab.<tailnet>`).
- [ ] Traefik v3 Compose file at `/srv/data/lab/compose/traefik/compose.yml` templated, Docker provider enabled, `web` (:80) and `websecure` (:443) entrypoints declared. No cert resolvers.
- [ ] systemd drop-in unit ensures the Traefik compose stack is brought up on boot.
- [ ] `whoami` example Compose file at `/srv/data/lab/compose/whoami/compose.yml` with Traefik labels routing `whoami.lab.<tailnet>` to the container.
- [ ] Manual `curl http://whoami.lab.<tailnet>` from a second authorized Tailscale peer returns the whoami response.
- [ ] `--check --diff` reports 0 changed tasks on a converged run.

## Blocked by

- 008-security-role.md (nftables `tailscale0` rule must exist before lab traffic flows)
- 009-p1-smoke-test-and-vm-gate.md

## Implementation notes

- v1 is plain HTTP over Tailscale. WireGuard tunnel is the trust boundary. No cert machinery, no ACME, no renewal. Browser will say "Not secure" — that is the accepted state. Revisit only when a test service requires browser-trusted TLS.
- Traefik runs as a Docker container with the docker.sock provider — there is NO systemd unit for Traefik itself. The systemd drop-in only invokes `docker compose up -d` for the stack.
- Tailscale auth: vaulted key is the default to keep the playbook idempotent. The manual fallback is documented but discouraged.
- The `whoami` example is not a real service. It's a Phase 2 acceptance artifact for PRD §9 Stories 7/8.

## Requirements addressed

- Phase 2, `lab` deliverable.
- PRD §10 lab module.
- Locked decision: "Traefik internal TLS: Plain HTTP over Tailscale only in v1".
- PRD §9 Stories 7, 8.
