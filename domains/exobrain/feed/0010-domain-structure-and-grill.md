---
id: 0010
title: Domain-structure manual + the grill interview discipline
date: 2026-06-13
tags: [domains, authoring, grill, meta-domain]
touches_invariant: false
files: [domains/exobrain/domains.md, domains/exobrain/grill.md, domains/exobrain/README.md]
---

## Problem

The meta-domain told you *what* a domain is (`entities.md`) and *how to write*
the prose (`authoring.md`), but not *how to structure* one — directory layout,
when to split into sections, how to handle a domain that's under active parallel
construction, or how to track change over time. And the discipline for turning a
person's understanding into shared, correct knowledge (a real interview, not a
transcription) was nowhere captured, so every knowledge-building effort reinvented
it.

## Pattern

Two on-demand meta-domain docs:

- **`domains.md`** — the structure manual: directory layout; breaking a domain
  into **sections** (internal subdirectories, named to make placement
  predictable — distinct from identity *scopes*); the **WIP domain** convention
  (a `.wip` directory suffix for a durable design-and-intent domain under active
  parallel build, kept current while it runs, distinct from a point-in-time
  workspace); and **timeline tracking** (`timeline: true` frontmatter →
  append-only `TIMELINE.md`).
- **`grill.md`** — the shared interview discipline: explore-before-asking
  (classify each open item as discoverable / conventional / human-judgment, spend
  human questions only on the last), one question at a time, walk the design tree
  (cardinality, lifecycle, ownership…), challenge weak reasoning rather than
  transcribe it, and verify shared understanding with a read-back + spot-check
  before declaring done.

## Reference (illustration only)

`domains/exobrain/domains.md` and `domains/exobrain/grill.md` in the seed, with a
row for each added to the meta-domain `README.md` index.

## Adapt notes

No invariant touched. Use your own terminology where the seed avoided collisions —
the seed says "sections" for within-domain subdirectories because "scope" already
means the identity hierarchy. Strip any org-specific examples and source lists; the
seed ships generic ones (`home`, `vehicle`). `grill.md` descends from Matt
Pocock's `grill-me`; keep the attribution.
