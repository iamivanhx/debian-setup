# debian-setup — SER8 dev + test-staging

Modular bash automation for Debian 13 on a Beelink SER8. Each module is an
idempotent script that converges one slice of system state — packages,
configuration files, services, user environment — from version-controlled
templates. You run `./run.sh` on a freshly installed machine and it builds
the full workstation + lab stack; you re-run it at any time to bring drift
back into line.

**Core rule: edit the automation, not the box.**
Any change you would otherwise make by hand on the machine goes into a module
or a file under `templates/` and gets replayed through `./run.sh`. Never
hand-edit configs directly on the box. If a config exists only on the box, it
is invisible to version control and will disappear on the next reinstall.

---

## Quick start

```sh
git clone <repo> && cd debian-setup
```

Create a secrets file (SSH keys, API tokens, passwords):

```sh
mkdir -p ~/.config/ser8-setup
"$EDITOR" ~/.config/ser8-setup/secrets.env   # KEY=value pairs, chmod 600
```

Run the full stack, or a single module:

```sh
sudo ./run.sh
sudo ./run.sh <module>          # e.g. ./run.sh 20-base
```

---

## Subcommands

| Command | Effect |
|---|---|
| `./run.sh` | Run all modules in order |
| `./run.sh <module>` | Run one module by name or prefix |
| `./run.sh --dry-run [module]` | Print what would change, make no changes |
| `./run.sh smoke [module]` | Run smoke-test assertions only |
| `./run.sh lint` | shellcheck all scripts |
| `./run.sh backup now` | Trigger an immediate backup |
| `./run.sh lab-up <project>` | Start a lab project stack |

---

## Phase status

- [ ] Phase 0: Pre-flight — repo scaffold, install cheat sheet, legacy cleanup
- [ ] Phase 1: Foundation — base + hardware + storage + security
- [ ] Phase 2: Workstation — desktop + shell + dev
- [ ] Phase 3: Lab + Backup + Disaster Drill
- [ ] Phase 4: Resilience — monitoring, auto-updates, drift detection
- [ ] Phase 5: Acceptance — full walk of docs/acceptance.md on real hardware
