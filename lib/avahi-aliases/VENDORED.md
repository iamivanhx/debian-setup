# Vendored: avahi-aliases (Python 3 port)

| field                | value                                           |
| -------------------- | ----------------------------------------------- |
| upstream             | https://github.com/airtonix/avahi-aliases       |
| upstream sha         | `7cf7ec6a7ae0dff1411ed0090bbd1144da45645d`      |
| upstream version     | `0.0.10`                                        |
| upstream license     | MIT                                             |
| vendored on          | 2026-05-22                                      |
| modifications        | Ported to Python 3 + python3-dbus + GLib loop   |

## Why ported instead of vendored verbatim

The upstream tool is Python 2 only — it imports the legacy `avahi` and `dbus`
modules from `python-avahi` / `python-dbus`, neither of which is packaged for
Debian 13. The behaviour we want is unchanged:

1. Read `/etc/avahi/aliases` (one CNAME per line, `#` comments, blank lines).
2. Open the Avahi system bus, create an EntryGroup.
3. For each alias, add a CNAME record pointing at the host's mDNS FQDN.
4. Commit, then idle on a GLib main loop until SIGTERM, at which point the
   entry group is reset and the process exits cleanly.

The port preserves the upstream's CLASS_IN / TYPE_CNAME / TTL constants and
the IDNA encoding of CNAME / rdata payloads so the wire format on the bus
is byte-identical. The python-daemon double-fork from upstream is dropped —
systemd handles process lifecycle on the SER8 (see `avahi-aliases.service`),
so an in-process daemonization layer is redundant and complicates debugging.

## Runtime dependencies (installed by `modules/70-lab.sh`)

- `avahi-daemon` — the actual mDNS responder
- `avahi-utils` — for `avahi-resolve-host-name`, `avahi-publish` debugging
- `python3-dbus` — D-Bus bindings
- `python3-gi` — GLib main loop
- `gir1.2-glib-2.0` — GI typelibs for GLib

## Re-vendoring

If a maintained Python 3 upstream appears, replace `avahi-aliases`
(the executable in this directory) with the new tool's main script,
update this file with the new sha / version, and re-run smoke tests.
The systemd unit template at `templates/etc/systemd/system/avahi-aliases.service`
treats this binary as opaque — same CLI contract (one positional arg = aliases
file, idle on the main loop) is all that's required.
