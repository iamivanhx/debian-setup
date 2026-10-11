# The repo owns each managed file, with no override layer

Omarchy and omadeb split config in two: defaults sourced in place from the install tree (`default/`), and user files seeded once into `~/.config` that include those defaults and hold the user's overrides. aule has one owner instead. Every managed file (a whole file, a set of keys, or a line) lives in `templates/`. A run installs it through the root or user file primitive, which backs up what was there to `~/.local/state/aule/backups/` or `/var/lib/aule/backups/`, shows the diff, and overwrites it. A hand edit on the machine is drift: `check` reports it and fails, and the next run restores the repo version. We chose this because the override layer serves users who are not the repo's author, and there is one user, who is. It keeps "edit the automation, not the box" literal, and it keeps one place to look for any setting.

Where an app rewrites its own config, a whole-file copy would fight it, so the first of these that applies wins:

1. the app's system layer (`/etc/xdg` for Plasma, `/etc/gitconfig`)
2. a managed file with the app's write-back turned off (btop's `save_config_on_exit`)
3. only the managed keys, set with the app's CLI (`kwriteconfig6`) and read back by `check`
4. not managed

Under `/etc`, a module installs a drop-in wherever the app reads one, replaces a whole file only where none exists, and never edits a package's file in place. For files shared with the installer (`fstab`, `crypttab`), the repo owns lines, not the file.

## Considered Options

- **omadeb's `default/` + `config/` split.** Rejected: two places to edit, the installed clone's path baked into user files, and a changed default taking effect on fast-forward with no run, no `check` and no diff.
- **Copy-once seeds.** Rejected: a new repo default never reaches the SER8 without a migration.
- **An unmanaged `~/.zshrc.local`.** Rejected: a second place for config, which drifts out of sight. An installer that appends to a managed file shows up in the next run's diff, and what's worth keeping moves into `templates/`.
- **`[$i]` locks on the repo's Plasma keys.** Rejected: KWin and kglobalaccel write their own state into those files. Instead, `check` reports a user key in `~/.config` that shadows a repo key in `/etc/xdg`, and the run deletes it.

## Consequences

- The Plasma panel layout (`plasma-org.kde.plasma.desktop-appletsrc`) and VS Code's settings (carried by its own Settings Sync) are not managed.
- A runtime theme switcher that rewrites managed files would be drift, so any theme system renders its output through the run.
