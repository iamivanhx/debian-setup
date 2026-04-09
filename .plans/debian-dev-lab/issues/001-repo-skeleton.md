# Repo skeleton + no-op `site.yml`

## Type

AFK

## Phase

Phase 0: Pre-flight

## Parent plan

../../debian-dev-lab.md

## What to build

Stand up the Ansible repo layout per PRD §5.13 with all nine roles stubbed as no-ops, an inventory for localhost, vars files, an empty vault, and a `site.yml` that includes the roles in dependency order. The goal: `ansible-playbook --syntax-check site.yml` passes from day one and every later phase fills in existing hooks rather than restructuring the tree.

See parent plan, Phase 0 → "What this phase delivers" (bullets 1–4).

## Acceptance criteria

- [ ] Directory tree matches PRD §5.13: `ansible/{roles,group_vars,host_vars,inventory}/`, `docs/`, `scripts/`.
- [ ] Nine role directories exist (`base`, `hardware`, `storage`, `security`, `desktop`, `shell`, `dev`, `lab`, `backup`), each with `meta/main.yml` declaring dependencies in PRD §10 order, and `tasks/main.yml` containing a single `debug` task.
- [ ] `ansible/site.yml` includes all nine roles, applied to `localhost`.
- [ ] `ansible/inventory/localhost.yml` defines `beelink` as a localhost connection.
- [ ] `ansible/group_vars/all.yml` exists with stub tunable defaults.
- [ ] `ansible/host_vars/beelink.yml` exists with stubs for hostname, timezone, SSH keys.
- [ ] `ansible/group_vars/all/vault.yml` exists, encrypted with `ansible-vault` (empty body acceptable).
- [ ] `ansible.cfg` configured for localhost connection and `ask_vault_pass = True`.
- [ ] `ansible-playbook --syntax-check site.yml` passes.
- [ ] `ansible-playbook --ask-vault-pass site.yml` runs all nine no-op debug tasks successfully.

## Blocked by

None — can start immediately.

## Implementation notes

- Role dependency order is locked by PRD §10 and must be reflected in each role's `meta/main.yml`.
- Vault password is NOT stored in the repo. Use `--ask-vault-pass` (no `~/.vault_pass` file).
- This issue intentionally writes ZERO real role logic. Resist the urge to start `base` here — it has its own issue.

## Requirements addressed

- Phase 0, deliverables 1, 2, 3, 4 (repo skeleton, site.yml, inventory/vars, ansible.cfg).
- PRD §5.13 (repo layout), §10 (role dependency order).
