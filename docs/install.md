# Debian 13 netinst cheat sheet

> **Version note:** Written for Debian 13 (Trixie) netinst as of 2026-04.
> If the installer UI changes between point releases, update this doc to match.

This is the click-by-click guide for a **fresh install** of Debian 13 on the
Beelink SER8. Everything after the first-boot checklist is automated by
`./run.sh` — this doc covers the one part that cannot be scripted.

For **disaster recovery** (reinstalling after NVMe1 wipe while NVMe2 has
existing data), see `docs/recovery.md` — the steps differ because NVMe2 must
be manually unlocked before `./run.sh` can run.

A mistake here means a full reinstall. Follow every step exactly.

---

## Prerequisites

Before you start, have these ready:

- **USB stick** (2 GB+) flashed with the Debian 13 netinst ISO
  (`debian-13.x.x-amd64-netinst.iso` from <https://www.debian.org/distrib/>).
  Use [Balena Etcher](https://etcher.balena.io/), `dd`, or Rufus to flash it.
- **The SER8** powered off, with both NVMe drives installed.
- **Wired Ethernet** connected (strongly preferred). Wi-Fi may work but
  requires extra installer screens (SSID, passphrase, possibly non-free
  firmware) that are not covered in this walkthrough. Use wired if at all
  possible.
- **Your SSH public key(s)** — the full line(s) you will paste into
  `secrets.env` later. Have them in your clipboard or on a second device.
- **Your password manager** open — you will need the LUKS passphrase you choose
  and the values for `secrets.env`.

---

## Boot from USB

1. Insert the USB stick into the SER8.
2. Power on (or reboot) the SER8.
3. Press **F7** repeatedly as soon as the Beelink logo appears.
   This opens the one-time boot menu.
   - If you need full BIOS/UEFI setup instead, press **DEL**.
4. Select your USB stick from the boot menu.
   Choose the **UEFI** entry (not Legacy/CSM) if both are shown.
5. The Debian installer should load within a few seconds.

> **Tip:** If the boot menu does not appear, power off completely, wait 5
> seconds, and try again — hold F7 before the logo appears.

---

## Debian installer walkthrough

Follow every screen in order. If a screen is not listed here, accept the
default and continue.

### 1. Installer boot menu

Select **Install** (text mode). Do not select Graphical Install — it is
functionally identical but harder to document unambiguously.

### 2. Language

Select **English**.

### 3. Location

Select your country (e.g. **United States**). This sets the timezone and
default mirror.

### 4. Keyboard

Select your keyboard layout (e.g. **American English**).

### 5. Network — hostname

Enter: **`ser8`**

### 6. Network — domain name

Leave this field **blank**. Press Continue.

### 7. Root password

**Leave both fields blank.** Press Continue.

This disables the root account entirely. The primary user you create next will
get `sudo` privileges automatically — this is the intended setup.

> **Why no root?** A disabled root account means one fewer password to manage
> and no risk of someone logging in as root directly. `sudo` provides an audit
> trail.

### 8. Full name for the new user

Enter your full name (e.g. **Ivan**). This is a display name only.

### 9. Username

Enter your login username (e.g. **ivanhx**). This is the account you will use
for everything.

### 10. User password

Enter a strong password. Confirm it on the next screen. This is your login
password and your `sudo` password.

### 11. Timezone

Select your timezone (e.g. **Eastern**). The installer may narrow the choices
based on the country you selected earlier.

### 12. Partitioning — method

Select **Manual**.

> **Critical:** Do not select any "guided" option. Guided partitioning will not
> set up LUKS encryption or the partition layout we need.

### 13. Partitioning — drive overview

You will see both NVMe drives listed. Identify them:

- **NVMe1** — the drive you are installing to (typically the first listed,
  e.g. `/dev/nvme0n1`). This is where the OS goes.
- **NVMe2** — the second drive. **Do not touch this drive.** Module
  `20-storage` handles it automatically after first boot.

If either drive has existing partitions, delete them on **NVMe1 only**.
Select each existing partition on NVMe1 and choose **Delete the partition**.

If NVMe1 is completely blank (no partition table), the installer will ask
whether to create a new partition table. Select **Yes** and choose **gpt**
(GUID Partition Table). This must happen before free space appears.

### 14. Partitioning — create EFI System Partition

1. Select the **FREE SPACE** on NVMe1.
2. Choose **Create a new partition**.
3. Size: **1 GB** (enter `1 GB` or `1024 MB`).
4. Type: **Primary**.
5. Location: **Beginning**.
6. Use as: **EFI System Partition**.
7. Select **Done setting up the partition**.

> The installer automatically formats this as FAT32 and mounts it at
> `/boot/efi`.

### 15. Partitioning — create encrypted volume

1. Select **Configure encrypted volumes** from the partitioning menu.
2. Choose **Yes** when asked to write changes (this writes the EFI partition).
3. Select **Create encrypted volumes**.
4. Select the remaining free space on NVMe1 (the large chunk after the EFI
   partition). Press Space to mark it, then Continue.
5. Encryption method: **Device-mapper (dm-crypt)** (the default).
6. Encryption: **aes** (default).
7. Key size: **256** (default).
8. IV algorithm: **xts-plain64** (default).
9. Erase data: Choose **Yes** if this is a new/clean drive. Choose **No** if
   you want to skip the slow overwrite (less secure but faster for a dev
   machine).
10. Select **Done setting up the partition**.
11. Select **Finish** to return to the partitioning overview.
12. Enter your **LUKS passphrase**. Choose something strong — you will type
    this at every boot. Confirm it.

> **Remember this passphrase.** If you lose it, the drive is unrecoverable.
> Store it in your password manager.

### 16. Partitioning — create root filesystem inside LUKS

After entering the passphrase, the partitioning overview will show a new
device under the encrypted volume (e.g. `/dev/mapper/nvme0n1p2_crypt` or
similar).

1. Select the encrypted volume's partition (it will show as the large block
   under the LUKS device).
2. Use as: **Ext4 journaling file system**.
3. Mount point: **`/`** (root).
4. Select **Done setting up the partition**.

### 17. Partitioning — verify and write

Your partition table for NVMe1 should now look like this:

| # | Size | Type | Mount point |
|---|------|------|-------------|
| 1 | 1.0 GB | EFI System Partition (FAT32) | `/boot/efi` |
| 2 | (rest) | crypto (LUKS) | |
| └─ | (rest) | ext4 | `/` |

**NVMe2 should show no changes — it must remain untouched.**

Select **Finish partitioning and write changes to disk**. Confirm with **Yes**.

> **Note:** This layout has no separate `/boot` partition. GRUB reads the
> kernel directly from inside the LUKS container. The Debian installer
> configures this automatically (`GRUB_ENABLE_CRYPTODISK=y`). You will enter
> the LUKS passphrase once at boot (for GRUB) and the system unlocks the
> root filesystem automatically from there.
>
> Debian 13 ships GRUB 2.12+ which supports LUKS2 with Argon2id (the default
> key derivation). If you encounter a boot failure where GRUB cannot unlock
> the volume, the likely cause is a LUKS2/GRUB mismatch — see the
> troubleshooting table at the end of this doc.

### 18. Base system installation

The installer downloads and installs the base system. Wait for it to complete.

### 19. Package manager — scan extra media

Select **No** (do not scan extra installation media).

### 19a. Package manager — use a network mirror?

Select **Yes**. The netinst image needs a mirror to download packages beyond
the base system.

### 20. Package manager — mirror country

Select the country closest to you for the APT mirror.

### 21. Package manager — mirror

Select a mirror (e.g. **deb.debian.org** is a safe default).

### 22. Package manager — HTTP proxy

Leave **blank** unless you are behind a proxy. Press Continue.

### 23. Popularity contest

Select **No** (or Yes — this is a personal preference, it does not affect the
install).

### 24. Software selection

**This screen is critical.** You will see a list of presets with asterisks:

**Uncheck everything except:**
- [x] **SSH server**
- [x] **standard system utilities**

**Uncheck specifically:**
- [ ] Debian desktop environment
- [ ] GNOME (or any other desktop)
- [ ] web server
- [ ] print server

> **Why no desktop?** KDE Plasma 6 is installed by module `40-desktop` with an
> explicit package allow-list. Installing a desktop from the installer pulls in
> hundreds of packages we do not want.

Use Space to toggle each item. Press Continue when only SSH server and standard
system utilities are checked.

### 25. GRUB boot loader

1. Install the GRUB boot loader to your primary drive: **Yes**.
2. Select the device: choose the NVMe1 drive (e.g. `/dev/nvme0n1`).
   Do **not** select a partition — select the whole drive.

### 26. Finish the installation

1. Select **Continue** to reboot.
2. **Remove the USB stick** as the system reboots.

---

## First-boot checklist

### 1. Unlock LUKS

At the boot prompt, enter your LUKS passphrase to unlock the encrypted
root partition. The system will continue booting after a successful unlock.

### 2. Log in

Log in as the primary user you created during installation (not root — root
is disabled).

### 3. Install git

This is the only manual package install needed — everything else comes from
`./run.sh`.

```sh
sudo apt update && sudo apt install -y git
```

### 4. Clone the repo

```sh
git clone https://github.com/iamivanhx/debian-setup.git ~/debian-setup
cd ~/debian-setup
```

> **Note:** HTTPS is used here because SSH keys are not yet configured on a
> fresh machine. After `./run.sh` completes (module `30-security` deploys your
> SSH keys), you can switch the remote to SSH:
> ```sh
> git remote set-url origin git@github.com:iamivanhx/debian-setup.git
> ```

### 5. Create secrets.env

```sh
mkdir -p ~/.config/ser8-setup
chmod 700 ~/.config/ser8-setup
nano ~/.config/ser8-setup/secrets.env
```

Paste the template from the [secrets.env template](#secretsenv-template)
section below. Fill in real values from your password manager. Then lock down
permissions:

```sh
chmod 600 ~/.config/ser8-setup/secrets.env
```

### 6. Run the automation

```sh
sudo ./run.sh
```

This runs all modules in order. If anything fails, read the error message — it
will tell you which module failed and why. Fix the issue and re-run; every
module is idempotent.

> If something goes badly wrong, re-read the error output — every module is
> idempotent, so fixing the root cause and re-running `sudo ./run.sh` is
> always safe. A full recovery guide (`docs/recovery.md`) will be added in
> Phase 3.

---

## secrets.env template

Copy this block into `~/.config/ser8-setup/secrets.env` and replace the
placeholder values with your real credentials.

```bash
# --- Required ---

# SSH public key(s) for authorized_keys. For multiple keys, use a literal
# newline between them (the variable is quoted, so newlines are preserved).
SSH_AUTHORIZED_KEYS="ssh-ed25519 AAAA... user@host"

# Restic backup repository (Backblaze B2).
RESTIC_REPOSITORY="b2:your-bucket-name:/ser8"
RESTIC_PASSWORD="your-restic-encryption-password"

# Backblaze B2 credentials.
B2_ACCOUNT_ID="your-b2-account-id"
B2_ACCOUNT_KEY="your-b2-account-key"

# LUKS passphrase for NVMe2 (used by module 20-storage for first-time format
# only — not needed on subsequent runs or after the keyfile is installed).
NVME2_LUKS_PASSPHRASE="your-nvme2-luks-passphrase"

# --- Optional ---

# GitHub personal access token (for private repo access, API calls).
# GITHUB_TOKEN="ghp_..."

# Anthropic API key (for Claude API access from dev tools).
# ANTHROPIC_API_KEY="sk-ant-..."
```

> **Security:** This file is never committed to the repo. It lives only on the
> machine at `~/.config/ser8-setup/secrets.env` with mode `0600`. If you
> reinstall, you must recreate it from your password manager.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| SER8 does not boot from USB | Power off completely, reinsert USB, hold F7 before the logo appears. Check that the USB was flashed correctly. |
| UEFI entry not shown for USB | Enter BIOS (DEL), disable Secure Boot and CSM/Legacy, save and reboot. |
| LUKS passphrase rejected at boot | Caps Lock off? Keyboard layout correct? Try typing the passphrase in the username field first to verify it visually. |
| `secrets.env not found` when running `run.sh` | Create the file at `~/.config/ser8-setup/secrets.env` — see the template above. |
| `secrets.env has a syntax error` | The file must be valid bash. Check for unquoted special characters, missing closing quotes, or stray characters. |
| No network after first boot | Check the cable, or configure Wi-Fi with `nmtui` (if NetworkManager is available) or by editing `/etc/network/interfaces`. |
| `git clone` fails | Check network connectivity. If using SSH URL, switch to HTTPS (the default in this doc). Verify the repo URL is correct. |
| GRUB fails to unlock LUKS at boot | Boot from the USB stick in rescue mode. Check `/etc/default/grub` for `GRUB_ENABLE_CRYPTODISK=y`. If missing, add it and run `update-grub`. If GRUB cannot handle the LUKS2 key derivation, convert the key slot: `cryptsetup luksConvertKey /dev/nvme0n1p2 --pbkdf pbkdf2` (enter LUKS passphrase), then `update-grub` and reboot. |
