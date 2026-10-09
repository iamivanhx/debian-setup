# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- **`GLOSSARY.md`** at the repo root, or
- **`GLOSSARY-MAP.md`** at the repo root if it exists: it points at one `GLOSSARY.md` per context. Read each one relevant to the topic.
- **The ADR directory** (named under [ADR conventions](#adr-conventions) below; `docs/adr/` by default): read ADRs that touch the area you're about to work in. In multi-context repos, also check each context's own ADR directory (`src/<context>/docs/adr/` by default) for context-scoped decisions.

If any of these files don't exist, treat them as empty and carry on. The `/domain-modeling` skill creates them lazily when terms or decisions actually get resolved.

## File structure

Single-context repo (most repos):

```
/
├── GLOSSARY.md
├── docs/adr/
│   ├── 20260728-event-sourced-orders.md
│   └── 20260803-postgres-for-write-model.md
└── src/
```

Multi-context repo (presence of `GLOSSARY-MAP.md` at the root):

```
/
├── GLOSSARY-MAP.md
├── docs/adr/                          ← system-wide decisions
└── src/
    ├── ordering/
    │   ├── GLOSSARY.md
    │   └── docs/adr/                  ← context-specific decisions
    └── billing/
        ├── GLOSSARY.md
        └── docs/adr/
```

## ADR conventions

`/domain-modeling` resolves where ADRs live and how they are named from this section first, then from `GLOSSARY-MAP.md`, then from the convention the existing ADRs already follow. The fallback (root `docs/adr/`, `YYYYMMDD-slug.md` dated the day each ADR is written) applies only when none of those decides. Edit the lines below when this repo differs from the fallback; leave them as written when it doesn't.

- **Directory:** `docs/adr/` for system-wide decisions. Multi-context repos: `src/<context>/docs/adr/` for decisions scoped to one context.
- **File naming:** `YYYYMMDD-slug.md`, dated the day the ADR is written (`20260728-event-sourced-orders.md`), and referred to by its file stem (`ADR-20260728-event-sourced-orders`). An existing ADR is never renamed or renumbered.
- **Status and supersession:** no status frontmatter until the first ADR in a directory carries one, after which every new ADR there does. A superseded ADR is marked `superseded by ADR-YYYYMMDD-slug` and its body left as written; ADRs are never deleted. The full lifecycle is in the `domain-modeling` skill's `ADR-FORMAT.md`.

Editing these lines changes where new ADRs are written and where skills look for existing ones. It moves or renames nothing: an existing ADR directory is the source of truth, so describe what is on disk here rather than a layout you intend to migrate to.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `GLOSSARY.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-20260728-event-sourced-orders, but worth reopening because…_
