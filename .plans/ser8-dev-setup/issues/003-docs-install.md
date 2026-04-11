# docs/install.md — click-by-click Debian netinst cheat sheet

## Type

HITL

## Phase

Phase 0: Pre-flight

## Parent plan

../../ser8-dev-setup.md

## What to build

The literal click-by-click Debian 13 netinst cheat sheet. This is the single most important document in the repo because it's the one step that cannot be automated, and a mistake here is a reinstall. It must be unambiguous enough that the user can follow it at 2 AM after a disaster.

Structure:

1. **Prerequisites** — USB stick with the Debian 13 netinst image; the SER8 powered off; a wired or working Wi-Fi network; the SSH public key lines ready to paste.
2. **Boot from USB** — how to get into the SER8 BIOS to select the USB; which UEFI vs. legacy setting to use.
3. **Debian installer walkthrough** — every screen, every field, every button, with screenshots where the UI is non-obvious:
   - Language, location, keyboard, hostname (`ser8`), domain (blank).
   - Root password: **leave blank** (disables root login).
   - Primary user creation.
   - Partitioning: **manual**, and then the exact sequence for NVMe1:
     - Create EFI system partition (1 GB, FAT32, `/boot/efi`).
     - Create encrypted physical volume on the rest of NVMe1 (LUKS, user-chosen passphrase).
     - Inside the LUKS container, create one ext4 partition mounted at `/`.
     - Write changes, confirm.
   - **Leave NVMe2 untouched.** The automation handles it post-install.
   - Base system install, mirror selection.
   - Software selection: **uncheck every preset except "SSH server" and "standard system utilities."** No desktop from the installer. (Plasma comes from the 40-desktop module.)
   - GRUB install to the EFI partition.
   - Finish, eject USB, reboot.
4. **First boot checklist**:
   - Unlock LUKS at the boot prompt.
   - Log in as the primary user.
   - `sudo apt update && sudo apt install -y git` (the only pre-automation command needed).
   - `git clone <repo-url> ~/debian-setup && cd ~/debian-setup`.
   - Create `~/.config/ser8-setup/secrets.env` — paste the template from this doc, fill in real values from the password manager.
   - Run `./run.sh`.
5. **Expected secrets.env keys** — the full list (`SSH_AUTHORIZED_KEYS`, `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY`, any others introduced by later modules) with a placeholder template at the end of the doc.

Every screen in the Debian installer gets a screenshot. Any branching in the installer (e.g. "if you see this message, click Continue") becomes a numbered step, not prose.

## Acceptance criteria

- [ ] `docs/install.md` exists with every Debian netinst screen documented.
- [ ] Screenshots captured on a real Debian 13 netinst walkthrough (in UTM or on the real SER8 — up to the user).
- [ ] The LUKS + ext4 partitioning sequence for NVMe1 is stepped through in unambiguous terms.
- [ ] The software selection step explicitly says "uncheck everything except SSH server and standard system utilities."
- [ ] The first-boot checklist ends with `./run.sh` and a link to the recovery doc if anything fails.
- [ ] The full list of `secrets.env` keys is included as a copy-paste template.
- [ ] A peer (even self-peer 24 hours later) can follow the doc without asking a single clarifying question.

## Blocked by

None — can start immediately, runs in parallel with 001/002.

## Implementation notes

- This issue is HITL because it requires actually running the Debian netinst at least once to capture screenshots. Use UTM on macOS for the rehearsal if convenient — the user explicitly does not want a full VM-rehearsal gate, but taking screenshots once in a throwaway VM is fine and cheaper than taking them on the real SER8.
- Screenshots can be trimmed to just the installer panel (no full desktop frame needed).
- If the Debian installer's UI changes between Debian 13 point releases, this doc must be updated — document that assumption explicitly at the top.

## Requirements addressed

- Plan Phase 0, docs/install.md bullet
- PRD User Story 5 (reinstalling developer wants click-by-click install)
- PRD §7 Constraint "User not familiar with exotic partition schemes"
