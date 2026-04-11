# Flesh out docs/recovery.md + docs/projects.md + docs/acceptance.md

## Type

AFK

## Phase

Phase 3: Lab + Backup + Disaster Drill

## Parent plan

../../ser8-dev-setup.md

## What to build

Take the three doc skeletons from Phase 0 and fill them with full content now that the modules they describe actually exist.

### docs/recovery.md

- **Overview:** the recovery story in one paragraph — "wipe, reinstall, rerun, restore."
- **Expected timeline:** fresh install + `./run.sh` + `restic restore` in one afternoon (~3–4 hours).
- **Reinstall procedure:** point at `docs/install.md` and list any recovery-specific differences (e.g. "skip the user-creation step if the existing user account is in your backup").
- **Secrets recreation:** the full list of `secrets.env` keys and where each is recovered from (password manager, Backblaze console, Tailscale admin panel if we ever add it, etc).
- **Unlocking NVMe2:** exact steps. Before `./run.sh` can run, NVMe2 must be unlocked with its passphrase — because the keyfile on NVMe1 has been wiped. Procedure: `cryptsetup open /dev/nvme1n1 srv-data` (enter passphrase from `NVME2_LUKS_PASSPHRASE` in secrets.env), `mount /dev/mapper/srv-data /srv/data`. Then `./run.sh` restores the keyfile and fstab for future boots.
- **Running the automation:** `git clone`, create `secrets.env`, `./run.sh`.
- **Restoring /home from restic:** `export RESTIC_REPOSITORY=... RESTIC_PASSWORD=...` then `restic restore latest --target / --include /home/<user>`.
- **Verifying Docker volumes survived:** `ls /srv/data/docker/volumes/` should show the pre-disaster volumes. Spot-check a few.
- **Restarting projects:** for each directory in `/srv/data/lab/compose/`, run `docker compose up -d`. Or use `./run.sh lab-up-all` if implemented as a convenience.
- **Known-bad data loss window:** the nightly backup cadence means up to 24 hours of data under active edit can be lost. Documented explicitly.
- **When to call it "recovered":** walk `docs/acceptance.md` and tick boxes.

### docs/projects.md

- **Overview:** "this machine runs multiple Docker projects behind Traefik with per-project `.local` hostnames."
- **Adding a project (step-by-step):**
  1. `mkdir /srv/data/lab/compose/<project>/`
  2. Create `docker-compose.yml` with the required structure (Traefik labels, `traefik-proxy` external network).
  3. Add `<project>.local` to `/etc/avahi/aliases`.
  4. Run `./run.sh lab-up <project>` OR `docker compose -f /srv/data/lab/compose/<project>/docker-compose.yml up -d`.
  5. Verify from a LAN device: `curl http://<project>.local`.
- **Reference `docker-compose.yml`:** copy-paste starter with Traefik labels, `traefik-proxy` network, and a comment explaining what to change for a new project.
- **Traefik label reference:** the three labels every project must declare (`traefik.enable=true`, the router rule, the service port).
- **Avahi alias convention:** one hostname per line in `/etc/avahi/aliases`; names must end in `.local`; no wildcards.
- **Removing a project:** `docker compose down` from the project dir, then manually remove the line from `/etc/avahi/aliases`. Auto-removal is explicitly not done (plan: "Decisions resolved during planning").
- **Known footguns:**
  - Don't publish host ports from project compose files (use Traefik for routing).
  - Port 80/443 are owned by Traefik; conflicts fail silently.
  - Two projects on the same Docker network can see each other's ports (use separate networks).
  - Avahi `.local` is case-insensitive; don't rely on case.
  - mDNS doesn't work across subnets — a client on a different VLAN won't resolve `whoami.local`.
  - `.local` at coffee shops: at home this is fine; if you ever take the SER8 to a shared network, expect collisions.
- **Resource budget:** no automated resource limits in v1. Your discipline is the only constraint.

### docs/acceptance.md

Fully populate the acceptance checklist. One checkbox per PRD §8 user story, grouped by phase. At the end of Phase 3 (issue 018), this document is walked top-to-bottom as the v1 gate.

## Acceptance criteria

- [ ] `docs/recovery.md` has all the sections listed above, with real command examples (not prose placeholders).
- [ ] `docs/projects.md` has a copy-paste reference compose file and a footguns checklist.
- [ ] `docs/acceptance.md` has a checkbox for every PRD §8 user story, grouped by phase.
- [ ] All three docs pass a "could I follow this at 2 AM" test.
- [ ] Links between docs and back to the PRD are populated.

## Blocked by

- Blocked by 015-module-70-lab.md (projects doc describes the lab)
- Blocked by 016-module-80-backup.md (recovery doc describes the restic restore)

## Implementation notes

- `docs/recovery.md` is the document the user will read under stress. Prioritize "copy-paste this exact command" over prose explanations.
- `docs/projects.md` is the document the user will read every time they add a new project to the SER8. Keep the footguns checklist visible and short.
- `docs/acceptance.md` is a living doc — fine if a few items are marked "pending disaster drill" here; they get ticked in issue 018.
- The reference `docker-compose.yml` in `docs/projects.md` should be the same file as `templates/srv/data/lab/compose/whoami/docker-compose.yml` (or a near-clone) so the user sees a working example, not a hypothetical.

## Requirements addressed

- Plan Phase 3, `docs/recovery.md` + `docs/projects.md` + `docs/acceptance.md` bullets
- PRD User Story 8, 14, 18
- PRD §12 R5 (data loss window documented explicitly)
