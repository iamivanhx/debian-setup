# The SER8's root is btrfs, snapshotted by snapper

The security baseline asks for a pre-update snapshot that fails closed, and the SER8's root was ext4 on LUKS with no LVM, which can't take one. The cutover is a clean reinstall, so the root filesystem changes there to btrfs, still inside LUKS, with `/home` on its own subvolume so a rollback never takes user data with it. snapper snapshots root only. Debian's `snapper` package ships an apt hook (`/etc/apt/apt.conf.d/80snapper`) that takes a pre/post pair around every dpkg run, unattended-upgrades included, and an update takes its own pre-update snapshot and aborts before changing anything if that fails. Cleanup is by number (the last 10 pairs), with no hourly timeline. `/srv/data` on NVMe2 stays outside snapper: backup covers it.

## Considered Options

- **Keep ext4 and add Timeshift in rsync mode, with snapshots on NVMe2.** Rejected: slower, brings in a GTK app, and a restore needs a live USB.
- **Keep ext4 and keep a restore record instead** (the installed clone's previous commit, `dpkg` selections and versions, the managed-file backups). Rejected: rolling back means downgrading through snapshot.debian.org, and it can't undo a package's broken maintainer script.
- **LVM snapshots.** Not pursued: the layout has no LVM, and a thin pool is awkward to set up from the Debian installer.

## Consequences

- `docs/install.md`'s partitioning changes to btrfs with separate root and `/home` subvolumes. The exact layout belongs to the bootstrap.
- `grub-btrfs` isn't in Debian, so there's no boot-menu rollback. Files are restored with `snapper undochange`, and a whole-system rollback is a subvolume swap from a TTY or live USB, written up in `docs/recovery.md`.
- A snapshot isn't a backup: it lives on the same disk as what it protects.
