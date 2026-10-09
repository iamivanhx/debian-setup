# Issue tracker: GitHub

Issues for this repo live as GitHub issues; specs live as repo files behind pointer issues (see **Spec files**). Use the `gh` CLI for all operations.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue** (the canonical read; every "fetch" below routes here):

  ```sh
  gh issue view <number> --json number,title,body,state,labels,comments \
    --jq '{number, title, state, body, labels: [.labels[].name], comments: [.comments[] | {author: .author.login, body}]}'
  ```

  `--json` returns the body and every comment in one deterministic document; an issue with no comments has `comments: []`. `--jq` is only meaningful together with `--json`. Gotcha: in a non-interactive shell, `gh issue view <number> --comments` prints the comment list and drops the body, so it is a display command, not a read.

- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters. `comments` is the list of comment objects (bodies included), not a count.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`. Labels must already exist in the tracker; `triage-labels.md` maps roles to them.
- **Close with an explanation**: comment first, then close, as two commands:

  ```sh
  gh issue comment <number> --body "..."
  gh issue close <number>
  ```

  This is the only closure sequence. `gh issue close --comment` checks state before posting: on an issue that is already closed (including one auto-closed by a merged PR whose description says `Closes #<number>`) it prints "already closed", exits 0, and never posts the comment. Closing leaves the issue's labels in place (see `triage-labels.md`).

Infer the repo from `git remote -v`; `gh` does this automatically when run inside a clone. In `gh api` endpoints, `{owner}` and `{repo}` are literal placeholders that `gh` fills from the current clone.

## Resolving a bare `#42`

GitHub shares one number space across issues and PRs, so `#42` may be either. The REST issues endpoint returns both kinds and marks a PR with a `pull_request` key:

```sh
gh api repos/{owner}/{repo}/issues/42 --jq 'if .pull_request then "pr" else "issue" end'
```

Then run the matching read command (**Read an issue** above, or **Read a PR** below).

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

When set to `yes`, PRs run through the same labels and states as issues, using the `gh pr` equivalents:

- **Read a PR**: the JSON form of the canonical read, plus `gh pr diff <number>` for the diff:

  ```sh
  gh pr view <number> --json number,title,body,state,labels,author,comments,reviews \
    --jq '{number, title, state, body, author: .author.login, labels: [.labels[].name], comments: [.comments[] | {author: .author.login, body}], reviews: [.reviews[] | {author: .author.login, state, body}]}'
  ```

- **List external PRs for triage**: `gh pr list --json` exposes no author-association field, so discovery goes through the REST pulls endpoint, whose items carry `author_association` (snake_case):

  ```sh
  gh api --paginate 'repos/{owner}/{repo}/pulls?state=open&per_page=100' \
    --jq '.[] | select(.author_association | IN("CONTRIBUTOR", "FIRST_TIME_CONTRIBUTOR", "FIRST_TIMER", "NONE")) | {number, title, author: .user.login, association: .author_association}'
  ```

  `--paginate` walks every page; the filter runs per page and streams one JSON object per external PR. Those four values are the external set. `OWNER`, `MEMBER`, and `COLLABORATOR` are the maintainers' own in-flight work and stay out of the queue (as does the import placeholder `MANNEQUIN`). Read each surviving PR with **Read a PR**.

- **Comment / label**: `gh pr comment <number> --body "..."`, `gh pr edit <number> --add-label "..."`/`--remove-label "..."`.
- **Close with an explanation**: `gh pr comment <number> --body "..."` then `gh pr close <number>`, the same comment-first sequence as issues (`gh pr close --comment` has the same already-closed gap).

## Spec files

**Spec directory: `docs/specs/`.** _(Chosen during setup; `/to-spec` writes every spec here.)_

A spec's full text lives in the repo, one file per spec named `<feature-slug>.md` in the spec directory, committed before its issue exists. The spec's issue is a **pointer issue**: a short gist plus links to the file at that commit, so the issue body never meets GitHub's size limit.

- **Permalink**: `<repo URL>/blob/<full-sha>/<spec directory>/<feature-slug>.md`, with the repo URL from `gh repo view --json url --jq .url`. Pinned to a SHA, it keeps showing that commit's text after the file changes.
- **Section link**: the permalink plus the heading's anchor: the heading lowercased, punctuation other than hyphens dropped, spaces as hyphens (`## Acceptance Criteria` → `#acceptance-criteria`).
- **Reading a pointer**: a pointer issue's body opens with a `**Spec file:**` line linking the permalink. Read the spec file at that commit with `git show <full-sha>:<path>`, both taken from the permalink (the segments after `/blob/`), running `git fetch` first when the commit isn't local. The criteria are the ones in that file, never the pointer's gist.
- **The pointer's commit is the locked text**: an amendment edits the pointer's permalink to the amending commit. A permalink elsewhere to an earlier commit of the same file (a ticket's **Parent**, an older comment) shows the spec before that amendment: read the commit the pointer links now, and treat the older text as history, never as a second spec that conflicts with it.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run **Read an issue** from Conventions. For a bare number, resolve it first (see **Resolving a bare `#42`**) and use **Read a PR** when it is a PR.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body. `gh issue create --label wayfinder:map`.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue: `gh api --method POST repos/{owner}/{repo}/issues/<map>/sub_issues -F sub_issue_id=<child-db-id>`, with the child's numeric database id as in **Blocking**. Where sub-issues aren't enabled, add the child to a task list in the map body and put `Part of #<map>` at the top of the child body. Labels: `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`).
- **Blocking**: GitHub's **native issue dependencies**, the canonical, UI-visible representation. Add an edge with `gh api --method POST repos/{owner}/{repo}/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, where `<blocker-db-id>` is the blocker's numeric **database id** (`gh api repos/{owner}/{repo}/issues/<n> --jq .id`, _not_ the `#number` or `node_id`). GitHub reports `issue_dependencies_summary.blocked_by` (open blockers only, the live gate). Where dependencies aren't available, fall back to a `Blocked by: #<n>, #<n>` line at the top of the child body. A ticket is unblocked when every blocker is closed.
- **Block**: add the edge to the existing ticket as in **Blocking**, which the dependencies endpoint takes at any time. On the fallback, add the blocker to the `Blocked by` line of a fresh body from **Read an issue**, creating the line when there is none, and write it with `gh issue edit <n> --body-file <file>`. Then the block comment.
- **Frontier query**: list the map's open children (`gh issue list --state open`, scoped to the map's sub-issues / task list), drop any with an open blocker (`issue_dependencies_summary.blocked_by > 0`, or an open issue in the `Blocked by` line), the `wayfinder:waiting` label, an assignee, or a live claim comment (a `Claim [...]` comment not yet ended; the wayfinder skill's Session states define live). Either signal alone marks a ticket claimed. From what remains, take the ticket whose resolution unblocks the most open tickets or graduates the most fog (a patch of the map's Not yet specified that hangs on its answer), as the wayfinder skill's Work through the map counts them; map order is the tiebreak only. A ticket unblocks each open ticket it is the last open blocker of: `gh api repos/{owner}/{repo}/issues/<n>/dependencies/blocking --jq '[.[] | select(.state == "open" and .issue_dependencies_summary.blocked_by == 1)] | length'`, plus each open child whose `Blocked by` line has it as the only open issue.
- **Claim**: two parts. Assign (`gh issue edit <n> --add-assignee @me`, the session's first write), then post the claim comment carrying the session identity, `gh issue comment <n> --body "Claim [<hostname> <tool> <ISO timestamp>]"`. Two sessions of one dev share the assignee, so only the comment tells them apart.
- **Release**: `gh issue edit <n> --remove-assignee @me` (skipped while another live claim shares your account), then the release comment.
- **Reclaim**: the claim comment naming the stale claim's identity, then `gh issue edit <n> --add-assignee @me`, adding `--remove-assignee <stale login>` when the stale claim is another account's.
- **Waiting**: the `wayfinder:waiting` label (create it once with `gh label create wayfinder:waiting` where the repo lacks it) plus the wayfinder skill's `## Waiting` block in the child body, naming the external party, the awaited event, and the chase owner. A waiting ticket has no assignee, and the frontier query drops it.
- **Wait**: `gh issue edit <n> --body-file <file> --add-label wayfinder:waiting --remove-assignee @me`, where `<file>` is the body from a fresh **Read an issue** with the `## Waiting` block added above `## Question`; then the wait comment.
- **Resume**: the resume comment recording the event, then `gh issue edit <n> --body-file <file> --remove-label wayfinder:waiting`, where `<file>` is a fresh body with the `## Waiting` block removed.
- **Claim age**: **Read an issue** drops comment times. Read them with `gh issue view <n> --json comments --jq '[.comments[] | {createdAt, author: .author.login, body}]'`; the wayfinder skill's stale state reads these times.
- **Resolve**: the comment-first closure from Conventions: `gh issue comment <n> --body "<answer>"`, then `gh issue close <n>`, then append a context pointer (gist + link) to the map's Decisions-so-far.

### Map size

GitHub keeps the map in one issue body and its children as sub-issues, and caps both:

- **Limits**: an issue body holds at most 65,536 characters. GitHub's documentation pages don't state this cap; the figure comes from [GitHub's own docs repository](https://github.com/github/docs/blob/90b9608d97646e302f555f3183e36708bad7a3fb/.github/workflows/link-check-internal.yml#L277-L279), whose workflows trim the issue bodies they post to fit it. Past the cap a write fails with a 422 or lands truncated with no error. A parent issue holds at most 100 sub-issues ([Adding sub-issues](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/adding-sub-issues)).
- **Entry length**: a Decisions-so-far line is at most 300 characters, link included. A gist that needs more is detail its ticket already holds.
- **Size check**: before each map write, assemble the new body in a file (the fresh body from `gh issue view <map> --json body --jq .body > map.md`, with your entry changed) and count it with `wc -c < map.md`; bytes are never fewer than characters, so the count errs safe. At or under 50,000, write it with `gh issue edit <map> --body-file map.md`. Over 50,000, run **Archive** first. An archive's body takes the same check.
- **Archive**: move the oldest Decisions-so-far lines (and, on a task-list map, the closed children's task-list items) out of the map until its body is at or under 40,000:
  1. The archive is the issue the map's pointer line links. With no pointer yet, or when the move would take that archive over 50,000, create a new one titled `<map title>: archive <n>`, its body opening with `Archive of #<map>` and, from the second archive on, a line linking the previous one; then close it. An archive is a record, never a child of the map, so frontier queries never meet it.
  2. Append the moved lines to the archive under the headings they had in the map, oldest first, and re-read it: every moved line must be there.
  3. Only then remove them from the map body, and keep one pointer line at the top of its Decisions so far, replacing any older one: `- Earlier decisions: [<archive title>](<url>)`.

  If the map body is still over 50,000 with every Decisions-so-far line moved, stop and tell the human which section has outgrown the map. A later edit to an archived line (marking it superseded) is made in the archive.
- **Sub-issue cap**: when the map holds 100 sub-issues and a **create** needs another, move closed children, oldest first, to the newest archive until the map has room: `gh api --method POST repos/{owner}/{repo}/issues/<archive>/sub_issues -F sub_issue_id=<child-db-id> -F replace_parent=true`, with the child's database id as in **Blocking**. An archive holding 100 sub-issues takes no more: create the next one as in **Archive**.

Every closed child stays enumerable from the map: it is a sub-issue (or task-list item) of the map or of an archive on the chain the map's pointer line starts.
