# debian-setup

Automation that turns a fresh Debian trixie install into Ivan's dev machine, the SER8 first, and keeps it converged.

## Language

**lilypad**:
The name this setup goes by on the machine: its install path, config and state directories, and commands.
_Avoid_: ser8-setup (the old name), debian-setup (the repo, not the product)

**Installed clone**:
The checkout of this repo at `~/.local/share/lilypad` that a machine runs from and that updates fast-forward. It is separate from any dev checkout.
_Avoid_: install dir, dotfiles repo

**Dev layer**:
The portable part of the setup: desktop, themes, shell, dev tools, `bin/` commands, and migrations, runnable on any Debian trixie box, amd64 or arm64.
_Avoid_: dotfiles, workstation layer, user layer

**Machine layer**:
The part of the setup bound to one physical machine: hardware tuning, disk encryption and storage, firewall, sshd, the lab stack, and backup.
_Avoid_: host config, system layer, SER8 modules

**Machine profile**:
A named, in-repo selection of the machine-layer steps one machine gets, such as the SER8's or the arm64 VM's. Bootstrap records which profile a machine uses.
_Avoid_: machine config, flavour, target

**Step**:
One unit of install work: a directory under `install/` holding an executable `apply`, a separate `check`, and the files it installs. It declares its layer and whether it needs root, and it is idempotent.
_Avoid_: module (the old sourced-file unit), phase, leaf
