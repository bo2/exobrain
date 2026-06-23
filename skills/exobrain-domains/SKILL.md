---
name: exobrain-domains
description: "Build and maintain exobrain domains — one skill, four modes. create: scaffold a new domain from a broad sweep of your sources plus a code walk, when the knowledge is scattered and no corpus exists. distill: turn an already-collected corpus or workspace into a domain through a grill interview, with alignment verification (--wip for a parallel-build WIP domain — sets a definition altitude and grills only at/above it plus collision-critical questions). curate: interactive upkeep with the curator present — fold one new artifact (doc, transcript, thread, decision) into the right files, or work the open-questions backlog, asking only what targeted lookups can't settle. update: autonomous periodic refresh from the domain's sources.json — sweeps recent activity in the domain's connected sources, filters by the horizon test, never asks, never deletes. Use when asked to create/build/scaffold a domain, distill/promote a workspace into a domain, bootstrap or ingest an area into a WIP domain, fold something into a domain, resolve a domain's open questions, refresh/update a domain, or ask what changed since the last synthesis."
---

# Exobrain Domains

Build and maintain exobrain domains. One skill, four modes — pick by what already exists (a domain? a collected corpus?) and whether a human is in the loop.

| Situation | Mode |
|---|---|
| No domain yet; knowledge scattered across sources and code | [`create`](create.md) |
| Knowledge already collected (typically a workspace); the risk is misunderstanding, not missing sources | [`distill`](distill.md) |
| Parallel-build sync (a WIP domain) — bootstrapping it or ingesting one area | [`distill --wip`](distill.md) |
| Domain exists; fold in one new artifact, or resolve open questions; human reachable | [`curate`](curate.md) |
| Domain exists; periodic refresh from recent activity; no human present | [`update`](update.md) |

`distill` and `curate` run the shared interview discipline — [`../../domains/exobrain/grill.md`](../../domains/exobrain/grill.md). WIP domains — what they are, why they stay durable, the `.wip` convention — are defined in [`domains/exobrain/domains.md`](../../domains/exobrain/domains.md) → "WIP domains"; the mode you reach for here is the mechanism that builds and maintains them.

## Shared foundation (every mode)

Read this once; each mode's file adds only its own procedure on top.

1. **Read `domains/<domain>/README.md`** — frontmatter (`type`, `curator`, `summary`, `timeline`), scope boundaries, and the file index. The README is the map: it says which file owns which concern. Scope design is curator-defined ([`domains/exobrain/domains.md`](../../domains/exobrain/domains.md) "Breaking a domain into sections") — read the actual layout, never assume a fixed file set.
2. **Set and keep the README `summary:` current** — the one-line frontmatter field stating the domain's scope. It's pulled verbatim into the auto-loaded **domains index** ([`domains/exobrain/domains.md`](../../domains/exobrain/domains.md) → "The README `summary:` and the domains index"), so every mode owns it: `create`/`distill` write it when scaffolding; `curate`/`update` refresh it whenever a pass changes what the domain covers. One line — let the body's TL;DR elaborate.
3. **Locate the meta files** — `_meta/open-questions.md` and `_meta/sources.md` (WIP domains keep them at the domain root).
4. **Create a worktree before touching files** — `scripts/create-worktree.sh domain-<mode>-<name>` from the exobrain repo root, then `cd` into the path it prints.
5. **Apply [`domains/exobrain/authoring.md`](../../domains/exobrain/authoring.md) to every write** — horizon test, current-state-only, synthesize-don't-transcribe, don't-transcribe-what-the-source-already-holds, order-of-magnitude framing for drift-prone values, dated citations, gaps-and-conflicts handling, no-duplication-of-drift-prone-facts. Those rules are the canonical source of truth for any writing into a domain; each mode adds only its own flow.
6. **Bookkeeping** — close what's answered and add new gaps to `open-questions.md`; record inputs and resolved conflicts (which source is canonical, and why) in `sources.md`; if the README frontmatter has `timeline: true`, append one `TIMELINE.md` row for the whole pass (`| YYYY-MM-DD | <author> | <summary> |`, newest at the bottom, append-only). The `Last synthesis:` marker tracks sweep coverage — `update` sets it; the interactive modes leave it untouched.
7. **Land the change** — persist via the repo's standard git workflow (the [`exobrain-persist`](../exobrain-persist/SKILL.md) skill): commit (`Domain <mode> <name>: <short description>`), push, open a PR, squash-merge, update the main copy, clean up the worktree. The PR body covers: summary (domain, mode, what was ingested/swept), profile changes (one line per file, in terms of what the reader now knows), conflicts (resolved how, or flagged), and the open-questions delta.

## Modes

- **[`create.md`](create.md)** — scaffold + breadth collection + code walk + synthesis, from scratch.
- **[`distill.md`](distill.md)** — corpus → domain via the grill, with read-back + quiz verification; `--wip` for parallel-build domains (definition altitude + collision gate + streams).
- **[`curate.md`](curate.md)** — interactive upkeep: fold one input or work the open-questions backlog, asking only what lookups can't settle.
- **[`update.md`](update.md)** — autonomous sweep from `sources.json`, no human present: collect, filter by significance, write additively, flag uncertainty.
