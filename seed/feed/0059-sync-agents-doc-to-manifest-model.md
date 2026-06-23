---
id: 0059
title: Sync the agents meta-domain doc to the @-import manifest model and the full index set
date: 2026-06-23
tags: [agents, meta-domain, connector, docs]
touches_invariant: false
files: [domains/exobrain/agents.md]
---

## Problem

When the per-agent context surface moved to the **@-import manifest** model — Claude referencing each connected scope's live source specs through a manifest instead of composing them into one generated `AGENTS.override.md` — the connector and the generated entry point were updated, but the meta-domain's `agents.md` was not. Its "Per-agent injection surface" section and the `connect-agent.sh` walkthrough kept describing the superseded composed-file model, and named only the optional-skills index — omitting the tools and domains indexes the connector also generates.

`agents.md` is meta-domain content that ships into every instance, so the doc misdescribes the machinery the instance actually runs: it points at a file the connector now deletes, and undercounts the auto-loaded indexes. This is a surface-area gap from the manifest change, surfacing in the doc layer after the code shipped.

## Pattern

Keep the meta-domain's description of the per-agent surface in step with the connector. Three points to assert:

- **Reference, not copy.** Claude `@-import`s a connected-scopes manifest of `@-import`s to each connected scope's *live* source `AGENTS.md`/sidecar — so a scope edit shows up without a recompose — rather than a single composed override file. Codex/OpenClaw inline the same content via a marker block because they lack an import primitive. Same content, different delivery.
- **Name every generated index**, not just the first. List each index the connector emits (optional-skills, tools, domains, …) wherever the doc enumerates the surface.
- **No phantom artifacts.** Don't describe a generated file the connector no longer writes.

The durable rule underneath: a change to the per-agent surface isn't done until the meta-domain doc that describes it matches — the connector code and `agents.md` are one surface.

## Reference (illustration only)

The corrected shape: a table whose columns are *connected-scope specs* (Claude → a `connected-scopes.md` manifest of live source specs; Codex/OpenClaw → inlined marker block) and *generated indexes* (each `@-import`ed for Claude, inlined for the others), plus a one-line "same content, reference vs. copy" distinction. The end-to-end steps: one "generate the indexes" step listing all of them, and a "compose + inject" step describing the manifest write rather than a composed file.

## Adapt notes

Pure meta-domain doc sync, no machinery — `touches_invariant: false`. The actionable check on your own `agents.md`: does it still mention a single composed override file, or omit an index your connector generates? If so, reconcile it to your connector. If your `agents.md` diverged (renamed surfaces, a different agent set, extra indexes), re-synthesize the description rather than copying. An instance still on the composed-file connector model should skip this — its doc already matches its machinery; adopt it only once you're on the manifest model.
