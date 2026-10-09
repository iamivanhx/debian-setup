# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the label strings that already exist in this repo's issue tracker.

| Canonical role    | Label in this tracker | Meaning                                  |
| ----------------- | --------------------- | ---------------------------------------- |
| `needs-triage`    | `needs-triage`        | Maintainer needs to evaluate this issue  |
| `needs-info`      | `needs-info`          | Waiting on reporter for more information |
| `ready-for-agent` | `ready-for-agent`     | Fully specified, ready for an AFK agent  |
| `ready-for-human` | `ready-for-human`     | Requires human implementation            |
| `wontfix`         | `wontfix`             | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the label string from the right-hand column.

## Editing the mapping

- **The tracker is the source of truth for labels; this table is a lookup.** Editing a right-hand cell repoints a role at a label that already exists in the tracker. It creates, renames, and migrates nothing. To adopt a new label name, create or rename the label in the tracker first (`gh label create` / `gh label edit --name`), relabel existing issues if you want history to follow, then update the cell.
- **The left-hand column is fixed.** The five roles are what the skills know how to act on, so the table always has exactly these five rows. A label with no canonical role goes in the section below.

## Tracker-local labels

Labels this tracker uses beyond the five roles (for example the `bug`/`enhancement` category labels, area or priority labels, `wayfinder:*`) are recorded here as plain strings, so agents recognise them without treating them as roles. A skill acts on such a label only when that skill's own instructions name it.

- `wayfinder:map`, `wayfinder:research`, `wayfinder:grilling`, `wayfinder:prototype`, `wayfinder:task`, `wayfinder:waiting`: wayfinder maps and tickets
- `AFK`, `HITL`: whether an issue is worked by an agent alone or with a human (from the original plan)
- `Phase 0: Pre-flight`, `Phase 1: Foundation`, `Phase 2: Workstation`, `Phase 3: Lab + Backup + Drill`: phases of the original ser8-dev-setup plan
- `bug`, `documentation`, `duplicate`, `enhancement`, `help wanted`, `good first issue`, `invalid`, `question`: GitHub's default category labels

## Lifecycle

- **Labels persist on closed issues.** The state role present at closure (typically `wontfix`, or `ready-for-human`/`ready-for-agent` on an issue closed by a merged PR) is the record of how the issue ended. Closing leaves labels in place, and skills add or swap roles rather than stripping them at close.
- **Actionable queues combine a role with open state.** Because closed issues keep their labels, a label alone also selects history. Every "what's ready" query pairs the label with open state, e.g. on GitHub `gh issue list --state open --label ready-for-agent`; on the local-markdown tracker, an issue file whose `Status:` line is the role (not terminal `done`).
