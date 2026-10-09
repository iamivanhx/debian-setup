# debian-setup

Automation that turns a fresh Debian trixie install into Ivan's dev machine, the SER8 first, and keeps it converged.

## Language

**Dev layer**:
The portable part of the setup: desktop, themes, shell, dev tools, `bin/` commands, and migrations, runnable on any Debian trixie box, amd64 or arm64.
_Avoid_: dotfiles, workstation layer, user layer

**Machine layer**:
The part of the setup bound to one physical machine: hardware tuning, disk encryption and storage, firewall, sshd, the lab stack, and backup.
_Avoid_: host config, system layer, SER8 modules
