# Workspaces

Time-bound efforts — a trip, a renovation, a job search, an investigation. A workspace captures what was true during its window; once the effort ends it's a historical record and outdates by design. Durable findings get **promoted** into a `domains/` area, not linked from one (see `domains/exobrain/entities.md`).

## Naming

```
workspaces/YYYY/MM/DD-<slug>/
```

- **Date** is when the effort started (not when you created the folder).
- **Slug** is lowercase-hyphenated and descriptive (e.g. `kitchen-reno`, `job-search-2026`).

## The `README.md`

Single entry point — both the human-facing intro and the agent-facing context. Open with a short summary so anyone browsing can tell what the workspace is, then continue with whatever the effort needs (scope, files, findings, open questions, method). The body shape isn't prescribed; pick what serves the work.

A small YAML frontmatter at the top is useful:

```yaml
---
status: active        # active | paused | resolved | archived
created: YYYY-MM-DD
owner: <id>
participants: [<ids>] # optional, for shared workspaces
related: ["<links to docs, threads, domains>"]  # optional
---
```

## Lifecycle

- **active** — work is happening.
- **paused** — blocked or deprioritized.
- **resolved** — conclusions reached, no more work expected.
- **archived** — moved out of active view (rarely needed; the year/month nesting handles this).

Most go `active → resolved`. Update the `status` when the state changes. **Resolved workspaces stay in the repo** as the record of how you got somewhere — don't delete them; promote anything durable into `domains/` and leave the workspace as provenance.

## Workstreams

A workspace can hold many sub-efforts as **workstreams**, each in its own folder:

```
<workspace>/workstreams/<NNN-slug>/README.md
```

- **Prefix** — a 3-digit zero-padded sequence (`001-`, `002-`, …), assigned at creation, scoped to the workspace; it orders the workstreams.
- **Required file** — `README.md` describing the workstream's scope, status, and findings. Everything else is content-driven.
- **Index** — the parent `workstreams/README.md` lists one row per workstream with status and a one-line description.

## Timeline tracking (opt-in)

For multi-participant or long-running efforts, add `timeline: true` to the workspace `README.md` frontmatter. When present, each time you save changes that touch the workspace, append a row to a `TIMELINE.md` next to the `README.md`:

```markdown
# Timeline

| Date | Author | Summary |
|------|--------|---------|
| 2026-06-08 | oleg | Created workspace, initial scope |
```

The timeline is **append-only** — never edit or remove past rows; newest go at the bottom. It's the audit trail of who did what and when, kept out of the `README.md` itself.

## Optional patterns

None required — use whatever serves the effort: `data/` (exports, query results), `charts/`, `logs/`, `hypotheses.md`, `summary.md` (if a separate synthesis file beats inlining), `TIMELINE.md` (above).

## Workspaces vs. `tmp/`

- **Workspaces** (`workspaces/`) — committed; worth preserving. Use when the work has reuse or audit value, or when others might read it.
- **`tmp/`** — gitignored; ephemeral. Use for scratch runs and one-off output. When in doubt, prefer a workspace — institutional memory is cheap; redoing lost work isn't.
