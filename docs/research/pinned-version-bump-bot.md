# Pinned-version bump bot

Research note for the ticket [Research: Pinned-version bump bot](https://github.com/iamivanhx/debian-setup/issues/63), on the map [Map: SER8 Debian setup refactor (Omarchy/omadeb-inspired)](https://github.com/iamivanhx/debian-setup/issues/44). Written 2026-10-11. "Verified", "exception" and "recipe" carry the meaning in [`ADR-20261010-pin-outside-apt`](../adr/20261010-pin-outside-apt.md) [ADR-PIN]. The update flow comes from `ADR-20261011-update-converges-no-migrations` (branch `docs/update-flow`, from [Update flow and migrations](https://github.com/iamivanhx/debian-setup/issues/53)) [ADR-UPD].

**Question.** Which bot opens the reviewed bump PRs that `ADR-20261010-pin-outside-apt` requires? How does it hold a release back and verify it before the PR exists? The sub-questions cover how each candidate bumps `mise.lock` and the upstream recipes, the delay, CI verification, batching, repo permissions, and the trust boundary.

**Scope.** This note recommends but does not decide. Whether mise's own provenance counts as **verified** is decided in [Shell and dev-tool modules](https://github.com/iamivanhx/debian-setup/issues/57), and this note gives the options either way. The recipe file format is not decided yet, so the config snippets below are sketches against a made-up format. None of them was run.

## Sources and pins

| Label | What | Pin |
| --- | --- | --- |
| **Renovate** | `renovatebot/renovate`: docs, the mise manager, the regex manager, datasources | [`dfbf52d3`](https://github.com/renovatebot/renovate/tree/dfbf52d31a7330279213cec6400f3120353092d9) (`main`, 2026-10-10; latest release 44.149.3) |
| **renovate-action** | `renovatebot/github-action` README | [`a2327c16`](https://github.com/renovatebot/github-action/blob/a2327c167a51153836a65e7f5fd148d8865b3e60/README.md) |
| **mise** | `jdx/mise` docs and `settings.toml` | tag `v2026.10.7` = [`4599c53b`](https://github.com/jdx/mise/tree/4599c53b4286ff101de876f8122feec0797b48b2) |
| **GitHub docs** | `github/docs` content (Dependabot, Actions, rulesets, releases) | [`be38ec5d`](https://github.com/github/docs/tree/be38ec5d78e24172587e61b3c6ff40ace1865c71) (2026-10-09) |
| **dependabot-core** | ecosystem directories, the mise request | [`4725d253`](https://github.com/dependabot/dependabot-core/tree/4725d253a379379dc85d291268d9607977b3c1af) |
| **gh** | `gh attestation verify`, `gh release verify-asset` source | [`v2.102.0`](https://github.com/cli/cli/tree/v2.102.0/pkg/cmd) |
| **cosign** | `cosign verify-blob` reference | [`v3.1.3`](https://github.com/sigstore/cosign/blob/v3.1.3/doc/cosign_verify-blob.md) |
| **minisign** | README, verification | [`4ade1121`](https://github.com/jedisct1/minisign/blob/4ade1121ba8b65e0e7568a5b411aa4733284e8a8/README.md) |
| **GitHub API** | live release objects (`cli/cli` v2.102.0, `jdx/mise` v2026.10.7), this repo's protection state | queried 2026-10-11 |

Source labels used below:

- [RN-MISE] Renovate mise manager [readme](https://github.com/renovatebot/renovate/blob/dfbf52d31a7330279213cec6400f3120353092d9/lib/modules/manager/mise/readme.md), [`index.ts`](https://github.com/renovatebot/renovate/blob/dfbf52d31a7330279213cec6400f3120353092d9/lib/modules/manager/mise/index.ts), [`artifacts.ts`](https://github.com/renovatebot/renovate/blob/dfbf52d31a7330279213cec6400f3120353092d9/lib/modules/manager/mise/artifacts.ts), [`extract.ts`](https://github.com/renovatebot/renovate/blob/dfbf52d31a7330279213cec6400f3120353092d9/lib/modules/manager/mise/extract.ts)
- [RN-OPT] Renovate [`configuration-options.md`](https://github.com/renovatebot/renovate/blob/dfbf52d31a7330279213cec6400f3120353092d9/docs/usage/configuration-options.md) (`customManagers`, `minimumReleaseAge`, `internalChecksFilter`, `groupName`, `schedule`, `postUpgradeTasks`, `platformCommit`)
- [RN-MRA] Renovate [Minimum Release Age](https://github.com/renovatebot/renovate/blob/dfbf52d31a7330279213cec6400f3120353092d9/docs/usage/key-concepts/minimum-release-age.md)
- [RN-REGEX] Renovate regex manager [readme](https://github.com/renovatebot/renovate/blob/dfbf52d31a7330279213cec6400f3120353092d9/lib/modules/manager/custom/regex/readme.md)
- [RN-GRA] Renovate `github-release-attachments` datasource [`index.ts`](https://github.com/renovatebot/renovate/blob/dfbf52d31a7330279213cec6400f3120353092d9/lib/modules/datasource/github-release-attachments/index.ts), and the lookup that fetches new digests, [`lookup/index.ts`](https://github.com/renovatebot/renovate/blob/dfbf52d31a7330279213cec6400f3120353092d9/lib/workers/repository/process/lookup/index.ts)
- [RN-GHR] Renovate `github-releases` timestamps: [`releases-query-adapter.ts`](https://github.com/renovatebot/renovate/blob/dfbf52d31a7330279213cec6400f3120353092d9/lib/util/github/graphql/query-adapters/releases-query-adapter.ts) (`releaseTimestamp: publishedAt`)
- [RN-CHK] Renovate [`filter-checks.ts`](https://github.com/renovatebot/renovate/blob/dfbf52d31a7330279213cec6400f3120353092d9/lib/workers/repository/process/lookup/filter-checks.ts) and [`generate.ts`](https://github.com/renovatebot/renovate/blob/dfbf52d31a7330279213cec6400f3120353092d9/lib/workers/repository/process/lookup/generate.ts), plus the [`security` presets](https://github.com/renovatebot/renovate/blob/dfbf52d31a7330279213cec6400f3120353092d9/lib/config/presets/internal/security.preset.ts)
- [RN-SEC] Renovate [Security and Permissions](https://github.com/renovatebot/renovate/blob/dfbf52d31a7330279213cec6400f3120353092d9/docs/usage/security-and-permissions.md)
- [RN-MEND] Mend-hosted Renovate: [FAQ](https://github.com/renovatebot/renovate/blob/dfbf52d31a7330279213cec6400f3120353092d9/docs/usage/mend-hosted/faq.md), [hosted app config](https://github.com/renovatebot/renovate/blob/dfbf52d31a7330279213cec6400f3120353092d9/docs/usage/mend-hosted/hosted-apps-config.md), [job scheduling](https://github.com/renovatebot/renovate/blob/dfbf52d31a7330279213cec6400f3120353092d9/docs/usage/mend-hosted/job-scheduling.md)
- [RN-ACT] [renovate-action README](https://github.com/renovatebot/github-action/blob/a2327c167a51153836a65e7f5fd148d8865b3e60/README.md), `token` section and "Example with GitHub App"
- [M-LOCK] mise [Lockfile](https://github.com/jdx/mise/blob/4599c53b4286ff101de876f8122feec0797b48b2/docs/dev-tools/mise-lock.md) and [lockfile reference](https://github.com/jdx/mise/blob/4599c53b4286ff101de876f8122feec0797b48b2/docs/dev-tools/mise-lock-reference.md)
- [M-CLI] mise [`mise lock`](https://github.com/jdx/mise/blob/4599c53b4286ff101de876f8122feec0797b48b2/docs/cli/lock.md)
- [M-SEC] mise [Security overview](https://github.com/jdx/mise/blob/4599c53b4286ff101de876f8122feec0797b48b2/docs/security.md) (safe mode, download verification, minimum release age), [Paranoid mode](https://github.com/jdx/mise/blob/4599c53b4286ff101de876f8122feec0797b48b2/docs/paranoid.md), [`settings.toml`](https://github.com/jdx/mise/blob/4599c53b4286ff101de876f8122feec0797b48b2/settings.toml)
- [M-GH] mise [github backend](https://github.com/jdx/mise/blob/4599c53b4286ff101de876f8122feec0797b48b2/docs/dev-tools/backends/github.md) (`github_attestations`, `slsa_signer_identity`)
- [M-PS] mise [packslip backend](https://github.com/jdx/mise/blob/4599c53b4286ff101de876f8122feec0797b48b2/docs/dev-tools/backends/packslip.md) and [verification](https://github.com/jdx/mise/blob/4599c53b4286ff101de876f8122feec0797b48b2/docs/dev-tools/packslip-verification.md)
- [DB-OPT] Dependabot [options reference](https://github.com/github/docs/blob/be38ec5d78e24172587e61b3c6ff40ace1865c71/content/code-security/reference/supply-chain-security/dependabot-options-reference.md) (`cooldown`, `package-ecosystem`), [default cooldown](https://github.com/github/docs/blob/be38ec5d78e24172587e61b3c6ff40ace1865c71/data/reusables/dependabot/default-cooldown-period.md)
- [DB-MISE] [dependabot-core#12320 "Feature request: `mise`"](https://github.com/dependabot/dependabot-core/issues/12320) (open). [PR #14500](https://github.com/dependabot/dependabot-core/pull/14500), "Add initial support for mise", is open too, and a Dependabot maintainer [declined it on 2026-04-14](https://github.com/dependabot/dependabot-core/pull/14500#issuecomment-4245738799) until the mise team commits to maintaining it.
- [GH-TOKEN] [`actions-do-not-trigger-workflows.md`](https://github.com/github/docs/blob/be38ec5d78e24172587e61b3c6ff40ace1865c71/data/reusables/actions/actions-do-not-trigger-workflows.md); [Actions settings](https://github.com/github/docs/blob/be38ec5d78e24172587e61b3c6ff40ace1865c71/content/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository.md) ("Allow GitHub Actions to create and approve pull requests")
- [GH-RULES] [Available rules for rulesets](https://github.com/github/docs/blob/be38ec5d78e24172587e61b3c6ff40ace1865c71/content/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets.md), [About rulesets](https://github.com/github/docs/blob/be38ec5d78e24172587e61b3c6ff40ace1865c71/content/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets.md), [request-changes tips](https://github.com/github/docs/blob/be38ec5d78e24172587e61b3c6ff40ace1865c71/data/reusables/repositories/request-changes-tips.md)
- [GH-IMM] [Immutable releases](https://github.com/github/docs/blob/be38ec5d78e24172587e61b3c6ff40ace1865c71/content/code-security/concepts/supply-chain-security/immutable-releases.md), [Verify release integrity](https://github.com/github/docs/blob/be38ec5d78e24172587e61b3c6ff40ace1865c71/content/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/verify-release-integrity.md)
- [GH-ATT] [Using artifact attestations](https://github.com/github/docs/blob/be38ec5d78e24172587e61b3c6ff40ace1865c71/content/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations.md); [`gh attestation verify` source](https://github.com/cli/cli/blob/v2.102.0/pkg/cmd/attestation/verify/verify.go)
- [COSIGN] [`cosign verify-blob`](https://github.com/sigstore/cosign/blob/v3.1.3/doc/cosign_verify-blob.md). [MINISIGN] [minisign README](https://github.com/jedisct1/minisign/blob/4ade1121ba8b65e0e7568a5b411aa4733284e8a8/README.md#verifying-signatures)
- [API] GitHub REST, queried 2026-10-11. `GET repos/cli/cli/releases/latest` returned `"immutable": true`, `published_at`, and a per-asset `"digest": "sha256:…"`. `GET repos/iamivanhx/debian-setup/branches/main/protection` returned `404 Branch not protected`, and `GET …/rulesets` returned an empty list. The repo is public and has no `.github/workflows/`.

## Answer in brief

- **Dependabot is out.** It has no mise ecosystem and no custom or regex manager. Its ecosystems are a fixed list (`package-ecosystem` in [DB-OPT]; the `dependabot-core` directories). The mise request is open, and the mise PR was declined until mise's maintainers back it [DB-MISE]. Dependabot could bump neither `mise.lock` nor a recipe. It could still bump the Actions that our own CI workflows use, and so could Renovate.
- **Renovate covers both files natively.**
  - Its **mise manager** reads `mise.toml` and updates `mise.lock` by running `mise lock <tool>` itself. On mise ≥ 2026.7.12 it does this in mise's **safe mode** (`MISE_SAFE=1`), so the hosted app needs no command allowlist [RN-MISE].
  - A **custom regex manager** can bump a recipe's version. With the `github-release-attachments` datasource it rewrites the sha256 in the same PR [RN-REGEX][RN-GRA].
  - The signing identity stays a committed constant, or a template on `{version}`. A changed identity is not bumped, by design (see [Verification in the bump PR's CI](#verification-in-the-bump-prs-ci)).
- **Our own Action is a workable fallback.** It runs `MISE_SAFE=1 mise lock --bump --minimum-release-age <age> --json` for mise, plus a script that walks the recipes against the GitHub Releases API. It is more code to own. A PR opened with `GITHUB_TOKEN` gets its CI runs in an "approval-required" state, so it needs a GitHub App token to run CI unattended [GH-TOKEN].
- **The hold-back.**
  - Renovate's `minimumReleaseAge` ages each version separately. It takes the age from GitHub's `publishedAt` for `github-releases` [RN-GHR]. With `internalChecksFilter: "strict"`, the default, no branch is created until the version is old enough [RN-MRA].
  - Since Renovate 42, a missing timestamp holds the update back by default (`timestamp-required`) [RN-MRA].
  - mise's own `minimum_release_age` (default 24h) applies only when mise *chooses* a version. It never applies to a version already in `mise.lock` [M-SEC][M-LOCK].
  - A sensible delay is **3 to 14 days**. Renovate's and Dependabot's defaults and presets use 3 days; Renovate's docs cite 14 days as "plenty of time"; mise's own example is 7 days. **7 days** sits in the middle. The ADR's rationale is attacks "caught within days".
- **Verification is our CI's job, whichever bot opens the PR.** A required workflow on each bump PR does four things:
  - It re-downloads each changed artifact and checks its sha256.
  - For a **verified** recipe, it checks the signature or attestation against the identity committed **on `main`**, not against the PR's own copy. It uses `gh attestation verify --repo … --signer-workflow …`, `cosign verify-blob --certificate-identity … --certificate-oidc-issuer …` or `minisign -Vm … -P …`. Each of these fails when the proof is missing [GH-ATT][COSIGN][MINISIGN].
  - It fails a PR that changes an identity or moves a tool from verified to exception.
  - For `mise.lock`, it reinstalls the changed tools from an empty data directory with `MISE_LOCKED_VERIFY_PROVENANCE=1`, and fails if an entry lost its `provenance` [M-LOCK][M-SEC].

  An **exception**'s new digest stays visible as a diff line in the PR. The job summary adds the old and new digests, GitHub's per-asset digest, and the release's `immutable` flag [API][GH-IMM].
- **Batching.** Renovate's `groupName` puts several tools in one PR, and a `schedule` limits when branches are created [RN-OPT]. A tool that releases often gets one rolling PR, which Renovate moves to the newest version past the age [RN-MRA]. Renovate's docs say to use `schedule`, not `minimumReleaseAge`, to slow down fast releasers [RN-OPT].
- **What the repo needs.**
  - For the Mend-hosted Renovate app: Code, PRs, Issues, Checks, Commit statuses and Workflows read/write; Administration and Dependabot alerts read [RN-SEC]. Plus a `renovate.json`.
  - For self-hosted Renovate or our own Action: a GitHub App with Contents and Pull requests write, its key in repo secrets, and a scheduled workflow.
- **The trust boundary doesn't change in kind, but it isn't in place yet.** Commit signatures stay unchecked, so it doesn't matter who authored a bot commit [ADR-UPD]. The boundary has four preconditions:
  1. `main` has to actually be protected. Today it has no branch protection and no ruleset [API].
  2. The bot must have no bypass and no automerge.
  3. The required verification check must be pinned to the GitHub Actions app as its source. Otherwise the bot, which holds `statuses: write`, could set it green itself [GH-RULES].
  4. The CI must verify against `main`'s identities, or a bump PR could vouch for itself.

  The PR merge is the review. GitHub lets Ivan approve a bot's PR, because it is not his own [GH-RULES].

## What a bump has to change

Two kinds of file hold pins [ADR-PIN][ADR-UPD]:

1. **`mise.lock`** sits next to the repo's mise config. It records each tool's resolved version, backend, and per-platform `url` and `checksum`. For supported backends it also records `provenance`: `slsa`, `cosign`, `minisign` or `github-attestations` [M-LOCK]. mise "verifies new provenance against each target platform's artifact before it records it" [M-LOCK].
2. **Upstream recipes**, one per tool fetched outside mise and apt. Each holds a version, URL, sha256 and, for a verified tool, a signing identity [ADR-PIN].

The next **update**'s preview reads both and shows `old → new`. Convergence installs exactly what is locked [ADR-UPD]. So the bot only has to produce a correct diff to these files, plus a PR that a human can judge.

## The candidates

### Renovate

**mise.**

- **What Renovate reads and writes.**
  - The mise manager reads the usual config names, including `mise.toml`, `.config/mise.toml` and `.config/mise/config.toml`. It supports the `core`, `aqua`, `github`, `gitlab`, `cargo`, `go`, `npm`, `pipx`/`pypi`, `ubi` and other backends [RN-MISE].
  - It has no case for `packslip:`, `forgejo:` or `http:` tools, so those are skipped (`extract.ts`) [RN-MISE].
  - When `mise.lock` is present, Renovate extracts each tool's `lockedVersion`. It updates the lock file through `updateArtifacts` [RN-MISE].
- **How it runs mise.**
  - It runs `mise lock <tool>`, or `mise lock --bump` for lock-file maintenance.
  - When the `mise` it runs is 2026.7.12 or newer, it runs in safe mode (`MISE_SAFE=1`). Safe mode stops project config from running code: tasks, `exec()` templates, hooks, plugin installs and project `[settings]` are refused or ignored [M-SEC].
  - Without safe mode, a self-hosted admin must allowlist `mise` in `allowedUnsafeExecutions`. If neither holds, Renovate skips the lock file with a warning (`artifacts.ts`) [RN-MISE].
  - Native dependency sidecars (`.mise/locks/…`) are committed with the lock file [RN-MISE].
- **Two pinning styles both work** [RN-MISE]:
  - **Exact versions in `mise.toml`** (`gh = "2.102.0"`). Renovate edits `mise.toml`, then refreshes `mise.lock`. `updatePinnedDependencies: false` would freeze these.
  - **Fuzzy selectors** (`latest`, `"2"`). Renovate updates `mise.lock` only (`rangeStrategy: "update-lockfile"`). Under `latest` the request is unbounded, and a major-prefix request stays within its major.
- **Both styles respect `minimumReleaseAge`.**
  - A lock-only bump keeps its `major`/`minor`/`patch` update type and only gains an `isLockfileUpdate` flag (`generate.ts`). The age filter skips only the `lockFileMaintenance`, `lockfileUpdate`, `bump`, `pin`, `replacement` and `rollback` update types (`filter-checks.ts`) [RN-CHK]. This is read from the source, not tested.
  - **`lockFileMaintenance` bypasses the age check** [RN-MRA][RN-CHK], so leave it off. That is the default [RN-OPT].

**Recipes.**

- **Bumping version and digest together.**
  - A `customManagers` entry with `customType: "regex"` captures `currentValue` and `depName` and sets a `datasource` [RN-OPT][RN-REGEX].
  - Capturing `currentDigest` too, with the `github-release-attachments` datasource, makes Renovate fetch a new digest for every update ("update digest for all", `lookup/index.ts`) [RN-GRA].
  - With `matchStringsStrategy: "combination"`, the captures can sit on different lines, at one dependency per file [RN-OPT]. That fits one recipe per file.
- **How the datasource finds the new digest** (`getDigest` in [RN-GRA]):
  1. It finds the asset that `currentDigest` pins in the current release. It first reads small (< 5 KiB) assets as checksum files, then falls back to downloading and hashing assets.
  2. It maps that asset's file name to the new release by replacing the old version string with the new one.
  3. It reads the new digest from the new release's checksum file, or downloads and hashes the new asset.

  So the bot's new digest is at best what upstream claims. CI has to recompute it, and does (below).
- **Assets need a version in their names.** The asset name must contain the version, or the mapping fails and the digest is not updated [RN-GRA]. Tools whose asset names carry no version, and non-GitHub sources, need a hand-written datasource or our own script.
- **`postUpgradeTasks` cannot fill the gap on the hosted app.** It can run arbitrary scripts after an update, but the Mend-hosted app blocks them on the free plan [RN-OPT][RN-MEND]. Only self-hosted Renovate can allowlist them.

Sketch (untested, for an invented recipe format `recipes/<tool>.toml` with `repo`, `version`, `asset`, `sha256` lines):

```json5
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "minimumReleaseAge": "7 days",
  "minimumReleaseAgeBehaviour": "timestamp-required",
  "internalChecksFilter": "strict",
  "dependencyDashboard": true,
  "automerge": false,
  "lockFileMaintenance": { "enabled": false },
  "customManagers": [{
    "customType": "regex",
    "managerFilePatterns": ["/^recipes/[^/]+\\.toml$/"],
    "matchStringsStrategy": "combination",
    "matchStrings": [
      "repo\\s*=\\s*\"(?<depName>[^\"]+)\"",
      "version\\s*=\\s*\"(?<currentValue>[^\"]+)\"",
      "sha256\\s*=\\s*\"(?<currentDigest>[0-9a-f]{64})\""
    ],
    "datasourceTemplate": "github-release-attachments"
  }],
  "packageRules": [
    { "matchManagers": ["mise", "custom.regex"], "groupName": "pinned tools", "schedule": ["* 0-6 * * 1"] }
  ]
}
```

### Dependabot

- **No ecosystem fits.** The supported `package-ecosystem` values are a closed list: bun, bundler, cargo, composer, docker, github-actions, gomod, npm, pip, pre-commit, uv and others. There is no `mise` and no generic or regex ecosystem [DB-OPT], and `dependabot-core` has no mise directory.
- **mise support isn't coming soon.** The mise request is open. A maintainer declined the mise PR in April 2026 "since the Mise team isn't able to take that on right now" [DB-MISE].
- **Its cooldown is real but only for its own ecosystems.** The `cooldown` option has `default-days`, `semver-*-days` and `include`/`exclude`, with a 3-day default for version updates [DB-OPT]. It would apply only to ecosystems Dependabot has.

Dependabot can't do this job. Its one use here would be keeping our CI workflows' own Actions pinned (`github-actions`), which Renovate also does.

### Our own GitHub Action

- **mise.** A scheduled workflow runs `MISE_SAFE=1 mise lock --bump --minimum-release-age 7d --json`. That is the bot recipe mise's own docs give: run it on a schedule, open a PR when the lockfile changes, and set `MISE_SAFE=1` [M-LOCK][M-SEC].
  - `--json` lists `old_versions`/`new_versions` per tool, ready for a PR body [M-LOCK].
  - `--bump` re-resolves only non-exact requests ("Exact pins resolve to themselves"), so this style needs fuzzy selectors in `mise.toml` [M-LOCK][M-CLI].
  - **Pass the age as a flag.** Safe mode ignores project `[settings]`, so a `minimum_release_age` set in the repo's `mise.toml` would be silently dropped [M-SEC]. The `--minimum-release-age` flag overrides the setting and the tool option [M-CLI]. (Inference from the two docs; not tested.)
- **Recipes.** A script reads each recipe and lists the repo's releases. It skips drafts and pre-releases, and anything whose `published_at` is younger than the delay [API]. Then it downloads the asset and computes the sha256 itself. For a verified tool it runs the same verification CI runs (below) before writing the recipe. That checks the release before the PR exists, which Renovate does not do for recipes.
- **Opening the PR.**
  - With `GITHUB_TOKEN`: the repo setting "Allow GitHub Actions to create and approve pull requests" must be on. The PR's `pull_request` runs then start in an "approval-required" state until someone with write access approves them [GH-TOKEN][RN-ACT].
  - With a GitHub App token (`actions/create-github-app-token`): CI runs normally [RN-ACT]. The App needs Contents and Pull requests write.
- **Cost.** We own the release walking, the asset matching and the age logic. Renovate already has all three, tested.

## Holding a release back

| Mechanism | Unit | Timestamp source | Missing timestamp | Applies to |
| --- | --- | --- | --- | --- |
| Renovate `minimumReleaseAge` | each version separately; a pending version gets a `renovate/stability-days` check, and with `internalChecksFilter: strict` no branch at all | the datasource's, never the publisher's; `github-releases` uses `publishedAt` [RN-MRA][RN-GHR] | held back (`timestamp-required`, default since Renovate 42) [RN-MRA] | major/minor/patch and lock-only bumps; not `lockFileMaintenance` [RN-CHK] |
| Dependabot `cooldown` | per dependency, by semver level | Dependabot's | not documented | version updates only; never security updates [DB-OPT] |
| mise `minimum_release_age` / `--minimum-release-age` | when mise picks a version for a non-exact request | the backend's release date; "Versions without a release date are not filtered" [M-SEC] | **not filtered** [M-SEC] | never a version already in `mise.lock`, nor an exact pin [M-SEC][M-LOCK] |
| Our own check | per release | `published_at` from the Releases API [API] | our choice; fail closed | whatever the script walks |

Points that bear on the choice:

- **Security fixes skip the delay.** That holds in Renovate ("Security updates bypass any `minimumReleaseAge` checks") and in Dependabot [RN-MRA][DB-OPT]. For GitHub-release tools there is usually no advisory feed, so in practice a fix waits like any bump. The ADR accepts this ("A security fix … waits for its bump PR to be merged") [ADR-PIN].
- **Renovate's GitHub timestamps can't be faked through tag pushes.** `github-releases` ages a version by its `publishedAt`. Force-pushing a tag doesn't reset `github-tags`' timestamp [RN-MRA], so recipes should use releases, not tags.
- **Run frequency limits the delay's precision.** The Mend-hosted app runs active repos every 4 hours and onboarded but inactive ones daily [RN-MEND]. A 7-day delay therefore lands within hours of the mark.
- **Values in the sources**:
  - Renovate's `security:minimumReleaseAge*` presets use 3 days for npm, crates and PyPI [RN-CHK].
  - Renovate's concept page uses 14 days as its example, "plenty of time to allow security researchers and automated security tools to catch malicious intent" [RN-MRA].
  - Dependabot's default is 3 days [DB-OPT].
  - mise defaults to 24h, and its docs' example raises it to 7 days [M-SEC].
  - omadeb sets pnpm's age to 7200 minutes, 5 days (per [Research: Apps and dev tools from omadeb and Omarchy](https://github.com/iamivanhx/debian-setup/issues/46)).

  **7 days** is a reasonable middle. It is longer than every default, and short enough that the weekly batch below never waits more than about two weeks.

## Verification in the bump PR's CI

The ADR requires verification "at bump time and again at install time, and a missing proof fails the check" [ADR-PIN]. Renovate checks nothing about a recipe. mise checks provenance when it locks, but only opportunistically (below). So a required CI workflow on every PR that touches `mise.lock` or `recipes/` carries the bump-time check, whichever bot opened it.

**Recipes, verified tier.** For each recipe changed against the merge base:

1. **Load the identity from `main`.** Load the recipe's identity and tier from `main`, not from the PR head. Fail if the PR changes the identity, the issuer, the key, or moves the tool from verified to exception. Such a change needs a human-authored PR, and its review is a separate decision. Without this rule a compromised release plus a bot PR that also edits the identity would verify itself. The rule is our inference from the ADR's "identity committed in the repo".
2. **Download and hash.** Download the asset from the recipe's URL and compare its sha256 with the PR's value.
3. **Verify, failing closed.**
   - **GitHub attestation:** `gh attestation verify <file> --repo <owner/repo> --signer-workflow <owner/repo/.github/workflows/release.yml>`, with `--cert-oidc-issuer` defaulting to GitHub's, and `--deny-self-hosted-runners` where it applies. With no attestation it exits non-zero ("✗ No attestations found") [GH-ATT]. `gh` needs a token in CI (`GH_TOKEN`).
   - **cosign keyless:** `cosign verify-blob --bundle <bundle> --certificate-identity <id> --certificate-oidc-issuer <issuer> <file>`. For keyless flows, an identity or identity regexp is mandatory [COSIGN].
   - **minisign:** `minisign -Vm <file> -P <pubkey>` [MINISIGN].
   - **Immutable-release attestation**, where a project publishes immutable releases: `gh release verify <tag>` and `gh release verify-asset <tag> <file>` prove the asset is the one published with that release [GH-IMM]. This shows only that the asset is unchanged since publication, not who built it, so on its own it doesn't meet the **verified** bar.
4. **Re-check the age.** Fail if the release's `published_at` is younger than the delay. This guards against a misconfigured bot or a manual "force" from the dashboard [RN-MRA].

**Recipes, exception tier.**

- Steps 1, 2 and 4 apply, with no signature step. CI recomputes the digest rather than trusting the bot's, which may have come from upstream's checksum file [RN-GRA].
- **Keeping the new digest visible.** The PR diff already shows the `sha256` line changing. CI should also write a job summary, or post a PR comment, per exception. It names the tool, the reason the recipe records, the old and new version and digest, GitHub's per-asset `digest` for the new file (match or mismatch), and the release's `immutable` flag [API][GH-IMM].
- **What the digest proves.** The pinned digest is what the review accepts. GitHub's own digest only proves the file is uncorrupted [ADR-PIN]. If the asset is replaced after review, the install's sha256 check fails.

**`mise.lock`.**

- **mise's check at lock time is opportunistic.**
  - `aqua:` tools are checked as the aqua registry declares, whether checksum, cosign, minisign, SLSA or attestation [M-SEC].
  - `github:` tools are checked for attestations only "when a github.com release publishes them". SLSA is checked only when `slsa_signer_identity` and `slsa_signer_issuer` are set [M-GH].
  - A release with no attestation therefore locks with no `provenance`, and no error [M-SEC][M-GH]. That doesn't meet "a missing proof fails" on its own.
- **What the CI job adds** (inference; the commands are from the docs, the composition is untested):
  - (a) **A diff rule.** Fail if any `mise.lock` entry for a tool the repo lists as verified lacks a `provenance` field, or if a bump removed one.
  - (b) **A fresh reinstall.** Run `MISE_LOCKED_VERIFY_PROVENANCE=1 mise install --locked` (or `MISE_PARANOID=1`) with an empty data directory, for the changed tools. That re-downloads every artifact, checks the recorded checksum, and repeats the provenance check [M-LOCK][M-SEC].
  - Paranoid mode also asks GitHub to confirm a "no attestations" answer from mise's version host before accepting it [M-SEC].
  - A lockfile that records `github-attestations` makes a later install fail if that check is turned off [M-GH]. The recorded field is enforced at install time too.
- **Where the identity lives.**
  - For `github:` tools, the identity is the repository in the tool's backend ID. mise requires the attestation to name that repository [M-SEC], and that ID is committed in `mise.toml`.
  - `slsa_signer_identity` adds the workflow [M-GH].
  - For `aqua:` tools, the expected signer comes from the aqua registry, not from this repo [M-SEC]. Whether that counts as "an identity committed in the repo" is the call in [Shell and dev-tool modules](https://github.com/iamivanhx/debian-setup/issues/57).
  - The new `packslip:` backend records "the signer the project committed to" in `mise.lock` itself [M-LOCK][M-PS], but Renovate doesn't support it [RN-MISE].
- **Lock entries for the SER8.** The lock file must have a `linux-x64` entry for each tool. `mise lock` refreshes the platforms already in the file [M-LOCK].

**Making the check binding.**

- Add it as a required status check in a ruleset on `main`, with **GitHub Actions selected as the expected source**. Without that, any integration with `statuses: write` can set a check's state [GH-RULES], and Renovate's app holds that permission [RN-SEC].
- Give the workflow `permissions: contents: read` and no secrets beyond a read token.

## Batching frequent releasers

- **Renovate.**
  - `groupName` puts every update that shares it into one branch and PR [RN-OPT].
  - A `schedule` with cron syntax, such as `* 0-6 * * 1`, lets branches be created only in that window. The docs advise a window of at least 3 to 4 hours, since the hosted app runs only every few hours [RN-OPT][RN-MEND].
  - `minimumGroupSize` can hold a group until N updates are waiting [RN-OPT].
  - Within a PR, a newer version that passes the age replaces the older one, so a tool that releases daily rolls forward in one PR instead of opening several [RN-MRA].
  - `dependencyDashboardApproval` can make chosen tools wait for a dashboard tick [RN-OPT].
  - Renovate's own guidance: "Do _not_ use `minimumReleaseAge` to slow down fast releasing project updates. Instead setup a custom `schedule`" [RN-OPT].
- **Our own Action.** One PR per scheduled run, holding every eligible bump, is the natural shape. A weekly cron batches by itself.

A reasonable starting shape is a weekly window with one group for routine tools. Fast releasers such as Claude Code can sit in their own group, so one bad release doesn't block the rest.

## What each option needs on the repo

| Option | Credentials and permissions | Config files | Where it runs |
| --- | --- | --- | --- |
| **Renovate, Mend-hosted app** | Install the app on this repo. App permissions: Code, Pull requests, Issues, Checks, Commit statuses, Workflows read/write; Administration, Dependabot alerts, Metadata read [RN-SEC] | `renovate.json` (or `.github/renovate.json`, `renovate.json5`, …); onboarding PR first ([Configuration location](https://github.com/renovatebot/renovate/blob/dfbf52d31a7330279213cec6400f3120353092d9/docs/usage/getting-started/installing-onboarding.md#configuration-location)) | Mend's infrastructure, which runs `mise lock` in safe mode. Free plan: no `postUpgradeTasks` [RN-MEND] |
| **Renovate, self-hosted Action** | A GitHub App (preferred) or a PAT, stored as secrets. With plain `GITHUB_TOKEN`, PR CI runs need manual approval [RN-ACT] | Workflow file plus `renovate.json`; global config for `allowedCommands` and `allowedUnsafeExecutions` if used | Our Actions minutes; full control of `postUpgradeTasks` |
| **Our own Action** | A GitHub App with Contents and Pull requests write (preferred), or `GITHUB_TOKEN` plus the "Allow GitHub Actions to create … pull requests" setting and approve-to-run CI [GH-TOKEN] | Workflow file plus the script | Our Actions minutes |
| **Dependabot** | Built in | `.github/dependabot.yml` | Cannot bump mise or recipes [DB-OPT] |

Whatever the bot, the repo also needs the verification workflow and a ruleset on `main` that does three things:

- require a PR;
- require the verification check, with GitHub Actions as its source;
- block force pushes.

The bot must be on no bypass list [GH-RULES].

## Do bot commits change the trust boundary?

The settled boundary is "the protected `main` (changes only through PRs) plus the preview", and commit signatures aren't checked because "GitHub's merge commits and the bump bot's commits don't carry Ivan's key" [ADR-UPD]. The research finds no reason to change that in kind. It does find five conditions the boundary depends on:

- **`main` is not protected today.** It has no branch protection and no ruleset [API]. The boundary in the ADR doesn't exist yet. It has to be created before a bot gets write access.
- **The bot can write branches, not `main`.** Renovate's app has Code write to create branches [RN-SEC]. A ruleset that requires a PR, with no bypass for the app, keeps it off `main` [GH-RULES]. `automerge` stays `false`, which is Renovate's default [RN-OPT]. Merging stays Ivan's act, and it is the review [ADR-PIN].
- **Approvals.** GitHub bars a PR's author from approving it [GH-RULES]. A rule requiring one approval would therefore let Ivan approve bot PRs, but block his own PRs unless he bypasses. Requiring a PR without required approvals avoids that. Whether to require approvals is a policy call for Ivan.
- **The bot must not grade its own homework.** Pin the required check's source to GitHub Actions [GH-RULES]. Verify against `main`'s identities, not the PR's (see [Recipes, verified tier](#verification-in-the-bump-prs-ci)). The bot's own config (`renovate.json`) and the verification workflow are ordinary files on `main`, so changing them is itself a reviewed PR.
- **Execution surface.** On the hosted app, Renovate runs `mise lock` on Mend's machines against our config. Safe mode limits what that config can make mise do [M-SEC][RN-MISE]. Nothing the bot produces runs on the SER8 before Ivan merges and confirms an update's preview [ADR-UPD]. If the hosted bot were compromised, it could open a malicious PR, but it could not merge one.

Signed bot commits are available: Renovate's `platformCommit` on a GitHub App makes GitHub sign them [RN-OPT]. They add nothing to this boundary, because nothing checks signatures [ADR-UPD].

## Options side by side

| | Renovate (hosted) | Our own Action | Dependabot |
| --- | --- | --- | --- |
| Bumps `mise.lock` | yes, `mise lock <tool>` in safe mode [RN-MISE] | yes, `mise lock --bump` in safe mode [M-LOCK] | no [DB-OPT] |
| Bumps recipe version and sha256 | yes, regex manager plus `github-release-attachments`, when asset names carry the version [RN-REGEX][RN-GRA] | yes, any shape | no |
| Release delay | `minimumReleaseAge`, per version, fails closed on a missing timestamp [RN-MRA] | `--minimum-release-age` for mise; `published_at` check in the script | `cooldown`, own ecosystems only [DB-OPT] |
| Verifies before the PR exists | mise tools only, via mise's lock-time checks [M-LOCK]; recipes no | yes, if the script runs the same checks | n/a |
| Batching | `groupName`, `schedule`, `minimumGroupSize`, dashboard [RN-OPT] | one PR per run | n/a |
| Third party with write access | yes (Mend) | no | n/a |
| Code we own | config only | script and workflow | n/a |

**Recommendation, for Ivan to decide:**

- **The bot.** Renovate via the hosted app, with the mise manager and one regex custom manager for recipes. Set `minimumReleaseAge: "7 days"`, `internalChecksFilter: "strict"`, `minimumReleaseAgeBehaviour: "timestamp-required"`, `lockFileMaintenance` off and `automerge` off, with a weekly grouped schedule.
- **The checks.** Our own required verification workflow, in every case.
- **The fallback.** Our own Action, if Ivan prefers no third-party app with write access, or if recipes outgrow what a regex and `github-release-attachments` can express (non-GitHub sources, version-less asset names).
- **Dependabot.** Ruled out.

## Open, or not verified here

- **Nothing was run.** The configs and commands above are untested. Two claims come from reading source only:
  - Renovate's lock-only mise bumps keep their major/minor/patch update type, so the age check applies.
  - `--minimum-release-age` is honoured under `MISE_SAFE=1`.
- **Where the repo's mise config lives.**
  - If the machine symlinks a repo file to `~/.config/mise/config.toml`, mise treats it as global config, and its lockfile follows the global rules (`mise lock --global`) [M-LOCK].
  - Renovate runs `mise lock` with the config file's directory as the working directory [RN-MISE]. A file stored as, say, `templates/home/.config/mise/config.toml` might not be found as project config there.
  - The layout chosen in [Shell and dev-tool modules](https://github.com/iamivanhx/debian-setup/issues/57) should be tried with Renovate before relying on it.
- **Which `mise` the hosted app runs.** Renovate detects the version at runtime and needs ≥ 2026.7.12 for safe mode [RN-MISE]. Which version the hosted app actually installs was not checked. A `constraints.mise` entry in `renovate.json` can pin it.
- **Whether mise's provenance counts as verified** is decided in [Shell and dev-tool modules](https://github.com/iamivanhx/debian-setup/issues/57). The diff rule in [Verification](#verification-in-the-bump-prs-ci) enforces whichever answer it gives.
- **Dependabot's handling of a missing timestamp under `cooldown`** isn't documented [DB-OPT]. It's moot, since Dependabot can't bump these files.
- **Which upstream tools publish immutable releases** was not surveyed. `cli/cli` and `jdx/mise` do [API].
