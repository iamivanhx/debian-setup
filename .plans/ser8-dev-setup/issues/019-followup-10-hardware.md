# Follow-up: deferred findings from 10-hardware (#7)

## Type

HITL

## Phase

Phase 1: Foundation

## What to build

Address deferred review findings from the 10-hardware module implementation.

## Context

Follow-up from #7. These findings were identified during self-review (Claude Opus 4.6) and cross-review (GPT-5.4) but deferred as Minor/Observation severity.

## Self-review findings

- **Minor — No `udevadm control --reload-rules` after udev rule deployment.** After deploying `/etc/udev/rules.d/60-nvme-scheduler.rules`, the rule won't take effect until reboot. On re-runs where the rule changed, the old rule stays active. Consider adding `udevadm control --reload-rules && udevadm trigger` after deployment.
- **Minor — Conflicting legacy `60-nvme-ioscheduler.rules` not managed.** The legacy `beelink_debian_post_install.sh` deployed `60-nvme-ioscheduler.rules` with `mq-deadline`. The new `60-nvme-scheduler.rules` supersedes it alphabetically, but the orphan file should be cleaned up.
- **Minor — `smoke_10_hardware` does not verify fwupd is enabled.** The module enables `fwupd.service` but the smoke function only checks `power-profiles-daemon`. Add `guard::service_enabled fwupd` to smoke.
- **Minor — `deploy_template` has no argument validation.** Empty `dest` argument produces a confusing error. Consider adding `[[ -n "${dest}" ]] || error "..."` and `[[ -f "${template}" ]] || error "..."`.
- **Minor — Kernel fallback count is a warning, not a failure.** Acceptance criterion says "at least two kernel packages" but smoke only warns. Decide whether to enforce or document as advisory.
- **Observation — NVMe APST rule kernel match is broad.** `KERNEL=="nvme[0-9]*"` matches both char and block devices; `ATTR{queue/scheduler}` only exists on block devices. A tighter match would be `KERNEL=="nvme[0-9]*n[0-9]*"` for namespace block devices only.
- **Observation — Module-scope variables pollute global namespace.** `_current_profile` and `_missing_hw_packages` persist after module sourcing. Existing `_` prefix convention partially mitigates.

## Acceptance criteria

- [ ] Each finding is either addressed or documented as "won't fix" with rationale
- [ ] All existing tests continue to pass
- [ ] No regressions in `./run.sh 10-hardware` or `smoke_10_hardware`
