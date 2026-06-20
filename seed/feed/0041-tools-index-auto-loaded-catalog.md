---
id: 0041
title: A tools index — auto-load a flat catalog of tool docs so agents discover them
date: 2026-06-18
tags: [tools, discoverability, connector]
touches_invariant: false
files: [scripts/connect-agent.sh, scripts/skills-registry.sh]
---

## Problem

Tool docs — one self-contained doc per external system the agent reads from or acts on — are read on demand, and nothing pulls the agent toward them. Skills had a generated index in the always-loaded context; tools didn't. So the agent didn't know a given tool (or its scope-specific access wrapper) existed and defaulted to the wrong primitive — reaching for a generic command when a documented wrapper was the right call — only finding the doc *after* it already needed what the doc would have told it. The knowledge was correctly written, just one un-prompted read away from where the decision got made.

## Pattern

Generate a **tools index** — a flat table, one row per tool doc resolved across the connected scope chain, with the doc's first-line purpose as the summary — and inject it into each agent's auto-loaded surface exactly the way the skills index is. It's *pointers, not content*: the agent still reads the full doc before using the tool; the index only makes the doc worth reaching for.

Keep it **flat** — no visibility tiers, force, or ownership gating, unlike the skills registry. A tool doc's presence at a scope is its registration, and every connected user should see the whole catalog. Crucially, separate **visibility** (the index — everyone sees all) from **connection/enablement** (whether this machine has set the tool up), which is a per-machine opt-in tracked in local state, not in the index. That separation is what lets the index stay a pure function of committed docs: it regenerates on the same triggers as the skills index and never needs hand-maintaining.

## Reference (illustration only)

Reuse the scope-chain resolver the skills index already uses: walk the connected chain shallow→deep, glob each scope's tool-doc directory, dedupe deepest-scope-wins, emit `name + path + first-line summary`. Compose it into the agent surface alongside the skills index (an `@`-import for an import-capable agent; inlined for one without). Because the summary is the doc's opening line, that line must be a **complete, self-contained one-liner** — a wrapped or buried first line yields a truncated or useless row, so it doubles as an authoring constraint on the docs.

## Adapt notes

The win is trigger precision for tools the agent would otherwise miss — especially access wrappers and host/scope-specific variants that look like a generic command. Resist adding skill-style tiers; the simplicity (everyone sees all, connection tracked separately) is the point. If your tool docs carry structured frontmatter, pull the summary from a dedicated field instead of the first content line; otherwise make "first line = one-sentence purpose" an explicit doc convention so the generated rows stay crisp.
