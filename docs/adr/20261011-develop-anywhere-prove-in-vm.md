# aule is developed on the Mac or the SER8 and proven in a test VM before it merges

Supersedes `ADR-20261010-develop-on-the-ser8`. That ADR had lilypad developed on the SER8 itself, because the SER8 was to replace the Mac and wasn't in daily use yet. Now Ivan keeps both as dev machines, and after the cutover the SER8 is in daily use. So aule is edited on either machine, on branches, and every change reaches `main` through a PR. A ruleset enforces this with no bypass, Ivan included: PRs are required with no approvals (he can't approve his own), the CI checks that exist are required and sourced from GitHub Actions, and force-pushes and deletion are blocked. `main` is what the SER8 trusts (`ADR-20261011-update-converges-no-migrations`), so the proof comes before the merge, not before the update. Every hand-made change to what a run does (modules, templates, `lib/`, the runner, apt sources, upstream recipes, the bootstrap) passes a run in the **test VM** before it merges. Docs, tests, CI config, the glossary and ADRs are exempt. Host-only modules are still proven only on the SER8 itself, with the pre-update snapshot as the net. Nothing records the VM pass on the PR; the gate rests on discipline.

The test VM stays an amd64 KVM virtual machine on the SER8, using virtio-gpu with virgl, started by hand. It runs in the user's libvirt session (`qemu:///session`, virt-manager, passt networking), so nobody joins the root-equivalent `libvirt` group. Its tooling is installed by a host-only module, since the test VM never runs a VM inside itself. amd64 remains the only architecture.

## Considered Options

- **Develop on the SER8 only**, as before. Rejected: the Mac stays a dev machine, and it is the cheaper way back when a module breaks the SER8.
- **Gate every PR, or none.** Rejected: a docs change gains nothing from a VM run, and no gate drops "prove first" entirely.
- **Gate the bot's version bumps too.** Rejected: weekly bumps would cost weekly VM runs. A bump changes a version, not what a module does. CI verifies it against the identities committed on `main`, the update previews it as `old → new`, and a bad one is undone by a revert PR and an update.
- **Record the VM pass** with a PR checkbox or a required `test-vm` commit status. Rejected for now: a status would also need CI to mark exempt PRs as not needing it. If proofs turn out to be skipped in practice, the harness can add one.
- **A headless VM in GitHub Actions**, alone or beside the SER8's. Not adopted: it can't show the desktop, and its image and boot flow are upkeep for one user. The test harness may add one later.
- **System libvirt**, with the `libvirt` group or `sudo virsh`. Rejected: the group is root-equivalent, and sudo on every VM action is friction for no gain on a VM that needs no LAN address.
- **An admin bypass on the ruleset.** Rejected: it would make the trust boundary a promise. An emergency fix goes through a PR too.

## Consequences

- The pre-commit hook runs shellcheck and shfmt on both machines. On the Mac (bash 3.2, BSD tools) it skips bats by name and says so. bats runs on the SER8 and in CI, which is the authority.
- A Mac-only edit to a gated path still needs the SER8 to pull the branch and run it in the test VM before the merge.
- `/dev/kvm` comes from the `kvm` group, which grants only that device, or from the seat's `uaccess` ACL. Which one Debian's udev rules give is for the test harness to check.
