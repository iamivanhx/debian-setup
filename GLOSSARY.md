# debian-setup

Automation that turns a fresh Debian trixie install into Ivan's dev machine, the SER8, and keeps it converged.

## Language

**aule**:
The name this setup goes by on the machine: the SER8's hostname, the setup's install path, config and state directories, and its commands. Named after Aulë, the smith of the Valar.
_Avoid_: lilypad, ser8-setup (old names), debian-setup (the repo, not the product)

**Installed clone**:
The checkout of this repo at `~/.local/share/aule` that the SER8 runs from and that updates fast-forward. It is separate from any dev checkout.
_Avoid_: install dir, dotfiles repo

**Module**:
One unit of install work: an executable under `modules/`, run as its own strict-mode process, either as root or as the user, with a `check` that never installs. It is idempotent, and the files it installs live in `templates/`.
_Avoid_: step (the term while the unit was planned as a directory), phase, leaf

**Host-only module**:
A module that only makes sense on the SER8's own hardware, such as disk encryption, the second NVMe or hardware tuning, marked by its header. The runner skips it in the test VM and reports it as not applicable.
_Avoid_: machine layer, machine profile, hardware step

**Managed file**:
A file, a set of keys in a file, or a line in a file whose content the repo owns, installed by a module from `templates/`. There is no user-override layer: a hand edit is drift.
_Avoid_: dotfile, default, seed, user config

**Drift**:
A difference between a managed file on the machine and its template. `check` reports it, and the next run backs the file up, shows the diff and restores the repo version.
_Avoid_: local change, override, customization

**Retired item**:
Something a module once installed and now declares must be absent. Its `check` verifies the absence, and the item is deleted from the repo once the SER8 has converged past it.
_Avoid_: migration, legacy cleanup, self-heal

**Update**:
The runner command that fetches, previews, takes the pre-update snapshot, fast-forwards the installed clone, upgrades apt and converges, in that order, after one confirm.
_Avoid_: upgrade, pull, migrate

**Pre-update snapshot**:
The snapper snapshot of root that an update takes before it changes anything. If it fails, the update aborts.
_Avoid_: backup, restore point

**Test VM**:
An amd64 KVM virtual machine on the SER8, run in the user's libvirt session, where every change that alters what a run does is proven before it merges to `main`.
_Avoid_: arm64 VM, Mac VM, sandbox

**Exception**:
An upstream tool with no signature or attestation, admitted by name with a stated reason and a pinned, reviewed digest that only a reviewed bump changes.
_Avoid_: allowlist, unverified tool, waiver
