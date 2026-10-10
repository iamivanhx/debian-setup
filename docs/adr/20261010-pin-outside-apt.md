# Everything outside apt is pinned and bumped by review

The security baseline first said "no version pinning" to keep upkeep low, with upstream downloads tracking latest. We reversed that for everything lilypad fetches itself. mise tools are pinned by mise's lockfile. Each upstream tool has a committed recipe with its version, URL, sha256 and, where one exists, its signing identity. A scheduled bot opens a bump PR once a release has been out for a set delay, and merging that PR is the review. A signature proves who published a release, not that the release is safe. Recent supply-chain attacks shipped through real, signed channels and were caught within days, so "track latest" puts each one on the machine at the next update. Pins also turn the update preview into a diff of exact versions and digests. Debian, backports and signed vendor apt repos stay unpinned: their archives are signed, and their security fixes must arrive without waiting on a review.

Verification has two tiers. **Verified** means a signature or a GitHub artifact attestation checked against an identity committed in the repo, at bump time and again at install time, and a missing proof fails the check. A project's own checksum file or GitHub's per-asset digest proves only that the file wasn't corrupted, because it comes through the same channel as the file itself. Such a tool is admitted only as an **exception**, named with its reason, and the pinned, reviewed digest is what makes it acceptable.

## Considered Options

- **Track latest, verifying against GitHub's live digest.** Rejected: a release file replaced after review still passes.
- **Track latest, pinning only the exceptions.** Rejected: it leaves signed tools exposed to a compromised release on the day it ships.
- **Pin apt too, through snapshot.debian.org.** Rejected: security updates would stop flowing.
- **Reference:** Omarchy 4 pins sha256 in its PKGBUILDs and signs its own repo, but checks upstream signatures in only 12 of its 175 recipes. omadeb doesn't check upstream downloads at all (findings in [Hyprland desktop composition](https://github.com/iamivanhx/debian-setup/issues/36)).

## Consequences

- A security fix in a mise or upstream tool waits for its bump PR to be merged.
- Frequently released tools (Claude Code, for example) produce a steady stream of bump PRs. They can be batched.
- At the time of this decision, every upstream-only desktop tool checked (satty, impala, bluetui, ironbar, Vicinae, walker, elephant, ashell) publishes no signature, attestation or checksum file. Each one used is therefore an exception.
