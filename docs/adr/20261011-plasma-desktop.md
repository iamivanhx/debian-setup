# The SER8 runs KDE Plasma from Debian, with Cmd habits mapped by static keyd rules

The SER8 is used only for agentic coding: a terminal, an editor, a browser and agents. It runs KDE Plasma 6.3 from Debian trixie, as a Wayland session with its packages named explicitly. Plasma covers every desktop role from its own Debian packages: the launcher (KRunner), clipboard history (Klipper), screenshots (Spectacle), notifications, lock and idle, the polkit agent and the portal. So nothing is assembled and no add-on is installed. Its defaults are INI files that cascade from `/etc/xdg`, which the repo can ship as files. Trixie to forky stays within Plasma 6. No KDE Store widget, KWin script or theme is used, so the whole desktop stays in Debian and none of it is an **exception**. The panel is Plasma's default and is arranged by hand.

Mac Cmd habits are mapped below the desktop by keyd, from Debian, with static rules and no detection of the focused app:

- Super+C/V/X send Ctrl+Insert, Shift+Insert and Shift+Delete. These copy, paste and cut in Qt, GTK, Chrome and terminals alike.
- Super+A/F/T/W/S send Ctrl+…, with terminal flow control turned off.
- Super+Z stays unmapped, because Ctrl+Z in a terminal suspends the running job.
- Window-manager keys (Super+Space, Super+Tab, Super+Q, Super+1…4) are KWin binds.

Decided in [Desktop choice and composition](https://github.com/iamivanhx/debian-setup/issues/51), from the evidence in [Research: Desktop environments on Debian trixie](https://github.com/iamivanhx/debian-setup/issues/45).

## Considered Options

- **Hyprland.** Dropped by the map before this decision. Its churn and the work of assembling a dozen separate parts were too much to maintain.
- **GNOME 48**, which today's `modules/40-desktop.sh` installs. Rejected: Ivan has never liked it. Tiling and clipboard history also come only as extensions, and the extension API breaks every six months.
- **COSMIC.** Rejected: it isn't in any Debian suite, so it would be a source build of about 31 unsigned repos admitted as an exception. It is also ten months past 1.0.
- **Sway or niri.** Rejected: both are tiling compositors to assemble, and Ivan doesn't tile.
- **Xfce 4.20.** Rejected: its Wayland support is experimental.
- **Toshy for app-aware Cmd mapping.** Rejected: it isn't in Debian, and it installs a Python venv and two user services. keyd's own application mapper doesn't support Plasma.

## Consequences

- Cmd habits are partial. Super+Z doesn't undo, and Mac shortcuts beyond the mapped keys use Ctrl.
- Trixie's Plasma 6.3 lacks per-desktop tile layouts (6.4) and scheduled light/dark switching (6.5) until forky.
- Walker and Elephant leave the plan, because KRunner replaces them. Their two exceptions go with them.
- Plasma's own login screen (SDDM) and keyring (KWallet) replace greetd and gnome-keyring.
- Still to verify in the test VM: SDDM's greeter running on Wayland, and Ghostty honouring Ctrl+Insert and Shift+Insert.
