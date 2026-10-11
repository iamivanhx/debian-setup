# aule targets the SER8 only, with no machine profiles

The earlier architecture split the setup into a portable dev layer and a machine layer, and chose the machine-layer steps per machine through named profiles in `machines/` (the SER8's and a test VM's), recorded once at bootstrap. aule drops all of that. It customizes one machine, the SER8. The only other place it runs is the test VM, which differs from the SER8 only in lacking its hardware. So a module that touches that hardware (disk encryption, the second NVMe, hardware tuning) carries a `# host: ser8` header, and the runner detects the machine once, with `systemd-detect-virt` and the DMI product name. In a VM it skips those modules and lists each one as not applicable in the run summary, and on bare metal that isn't a SER8 it refuses to run. We chose this because profiles, a layer boundary and its lint are upkeep that one user on one machine never gets back, and the Mac's configuration is out of scope.

## Considered Options

- **Machine profiles and a dev/machine layer split** (the earlier [Repo architecture and layer boundary](https://github.com/iamivanhx/debian-setup/issues/32)). Rejected: they serve several machines, and there is one.
- **A `--vm` flag on the runner.** Rejected: forgetting it in the VM fails on the hardware modules, and passing it on the SER8 silently skips them.
- **Each module checks for its own hardware and no-ops.** Rejected: the rule is spread across modules, and a wrong check silently skips work on the SER8, against the baseline's rule that a failure is never skipped.

## Consequences

- Host-only modules are proven only on the SER8 itself, as `ADR-20261010-develop-on-the-ser8` already accepts for hardware, LUKS and NVMe. Its consequence that the `vm-arm64` profile becomes a test-VM profile no longer applies: there are no profiles.
- Running aule on a second machine means revisiting this decision, not adding a profile.
