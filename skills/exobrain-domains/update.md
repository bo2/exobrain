# Domain — update mode

Autonomous periodic refresh of an existing domain from its `sources.json`. **Runs without a human present** — on a schedule or fired ad hoc. It never asks mid-run: everything uncertain is flagged, cited, and left in open-questions; nothing is deleted. The PR is the human gate. For an interactive session (one input, or resolving open questions with the curator), use [`curate`](curate.md).

The goal is a **knowledge base**, not a sprint changelog. Every update must pass the **horizon test**: "Will this still matter in 3 months?" If not, it belongs in `_raw/` only.

Argument: `<domain>` (folder name), or `all` to sweep each domain sequentially.

The [shared foundation](SKILL.md) applies. This file adds the sweep-specific phases. **Headless caveat:** some tools authenticate via browser OAuth; on a cron run a tool's session may be unavailable — treat that as a tool error (log it, continue with the remaining sources, name the gap in the PR).

## Phase 1 — Setup

Determine the last-update date (the README's `Last synthesis:` marker, else the domain's last substantive commit: `git log -1 --format=%cs -- domains/<domain>/`). Read `sources.json`. Search window: **from** last-update minus 3 days (overlap to catch in-flight items) **to** today.

## Phase 2 — Collection

Search every source in `sources.json` — each source names a tool registered in [`tools/`](../../tools/). Paginate — don't accept truncated results. Record all findings in `_raw/update-YYYY-MM-DD.md` (a news feed; filtering is Phase 3). Note the **status** of each item: merged PRs are facts, open PRs are in-progress, draft PRs are exploratory; a resolved issue is shipped, a cancelled one means a plan changed.

**GitHub** — for each repo in a `github` source, using its `cli` (default `gh`):
```bash
<cli> pr list -R <org>/<repo> --state merged --search "merged:>=<from-date>" --limit 100 --json number,title,author,mergedAt,url
<cli> pr list -R <org>/<repo> --state open --json number,title,author,createdAt,url,isDraft
```
Fully-owned repos (`paths: ["."]`) — all PRs are relevant. Shared repos (specific paths) — can't filter PRs by path directly; search by keyword and by team-member author, then verify with `<cli> pr diff <n> -R <org>/<repo> --name-only` and keep only PRs touching owned paths. If a repo returns the 100-limit, paginate by narrowing the date range.

**Other tools** (chat, issue tracker, blog/notes, calendar, email, …) — use each tool's read/search interface as documented in its `tools/<name>.md` doc, scoped to the source's query fields (channels, project, sites, keywords) and the search window. Paginate; deduplicate across keyword searches; follow substantive threads; skip noise — automated notifications, acknowledgements, routine standups. Posts and threads often carry strategic decisions — high-signal for the product/intent files.

## Phase 3 — Editorial filtering

The most important phase. Apply the **horizon test** and significance filter to every finding (worked examples in [`domains/exobrain/authoring.md`](../../domains/exobrain/authoring.md)):

| Level | Criteria | Goes to |
|-------|----------|---------|
| **Strategic** | Changes direction, model, position, or who it serves | Profile files |
| **Structural** | Changes architecture, creates persistent risks, shifts how subsystems connect | Profile files |
| **Operational** | Single task, bug fix, routine maintenance, one-off incident | `_raw/` only |

Produce a structured changeset (working doc, not committed) labelling each finding INCLUDE (file + reason + source) / SKIP (reason) / MAYBE (→ open-questions for human review). **Cluster** related findings into one synthesized update (6 PRs about one migration → one status statement; not six entries).

## Phase 4 — Profile updates

Route each INCLUDE to the file the README's index assigns, in that section's editorial voice. Apply all of [`authoring.md`](../../domains/exobrain/authoring.md). Sweep-specific rules (the no-human posture):

1. **Never delete existing text.** Flag possibly-obsolete content in open-questions under "Possibly obsolete" instead.
2. **Never ask.** A finding needing judgment goes to open-questions ("Needs human judgment"), with the evidence and why it was filtered.
3. **Match the existing file's style.** Read before writing; continue its patterns.
4. **Close what a finding directly answers** (additive and safe). Anything short of a direct answer stays open.

Update `open-questions.md` with a `## Flagged YYYY-MM-DD` section (Possibly obsolete / Needs human judgment / Contradictions / Context gaps / Risks not captured). Set `Last synthesis:` to today; append the `TIMELINE.md` row if `timeline: true`. The PR body adds counts: findings collected, included, filtered to `_raw/`, flagged for review.

## `sources.json` schema

A list of sources, each naming a `tool` registered in [`tools/`](../../tools/); the remaining fields are that tool's query interface (the fields its read/search call takes — keywords, channels, project, sites, paths). `github` is built in below; other tools follow their own doc.

```json
{
  "sources": [
    { "tool": "github", "repos": [ { "cli": "gh", "org": "OrgName", "repo": "repo-name", "paths": ["."] } ] },
    { "tool": "<chat>",         "channels": ["channel-name"], "keywords": ["search term"] },
    { "tool": "<issue-tracker>", "project": "PROJECT_KEY",     "keywords": ["search term"] },
    { "tool": "<blog-or-notes>", "sites": ["site.example.com"], "keywords": ["search term"] }
  ]
}
```
For a `github` source, `paths: ["."]` = fully owned (all PRs relevant); specific paths = shared repo (filter PRs to those touching owned paths).

## Edge cases

- **First run after a long gap** (window > 30 days) — note it in the PR; consider breaking collection into smaller date chunks.
- **No findings** — note it in the raw file; absence of activity is itself a signal.
- **Tool errors** — log and continue; don't abort the run.
