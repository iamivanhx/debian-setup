# An update converges, with no migrations

Omarchy and omadeb keep `migrations/<timestamp>.sh`: one-shot scripts tracked by marker files, which a fresh install pre-marks as done, so they only ever serve machines that existed before the change. aule has one machine, and the cutover's clean reinstall resets its history, so there are no migrations. Convergence covers what changed, and a removal is a **retired item**: the module that used to own the thing declares it must be absent, and its `check` verifies that it is. The item is deleted from the repo once the SER8 has converged past it.

An **update** is one runner command with a fixed order: preflight (one update at a time, a clean clone that only fast-forwards, free space on `/`), fetch, preview, confirm, sudo, the pre-update snapshot, fast-forward, `apt full-upgrade`, converge, report. The preview shows the incoming commits and diff, pinned versions as `old → new`, a simulated `apt full-upgrade` with its removals, and the drift the run will revert. No fetched code runs before the confirm, so drift is measured by `check` from the commit already installed. Convergence comes after the apt upgrade so it re-asserts every managed file a package touched. A failing stage stops the update and is never skipped. The clone stays at the new commit, the update prints the pre-update snapshot and how to roll back, and a re-run picks up where it stopped. The trust boundary is the protected `main` (changes only through PRs) plus the preview. Commit signatures aren't checked, because GitHub's merge commits and the bump bot's commits don't carry Ivan's key.

## Considered Options

- **Omarchy 4-style migrations** (strict, a failure stops the queue, no skip, pre-marked on a fresh install). Rejected: with one machine, a migration only ever runs once, and a retired item stays checkable where a migration doesn't.
- **A manual sequence** (`git pull`, `run.sh`, `apt full-upgrade`). Rejected: nothing would enforce the preview or a snapshot that fails closed.
- **Run `check` from the incoming commit for the preview.** Rejected: it runs fetched code before the confirm.
- **Converge before the apt upgrade.** Rejected: a package upgrade could leave a managed file drifted until the next run.
- **Verify commit signatures against a key pinned on the machine.** Rejected: every PR, bot bumps included, would have to be merged locally and signed.

## Consequences

- Updates are manual. unattended-upgrades still applies Debian security fixes, and GitHub's PR notifications announce pinned bumps.
- Self-heal code that only cleans up after older runs is dropped. A module restarts any service whose managed file it changed.
- Retired items have to be pruned by hand once the SER8 has run them.
