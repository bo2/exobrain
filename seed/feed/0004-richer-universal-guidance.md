---
id: 0004
title: Richer universal authoring + workspace guidance
date: 2026-06-08
tags: [agents-md, workspaces, conventions, docs]
touches_invariant: false
files: [AGENTS.md, workspaces/README.md]
---

## Problem

When the seed was first extracted, the auto-loaded spec was trimmed hard for
leanness — which also dropped genuinely universal working discipline, and left
`workspaces/README.md` a thin stub. Useful, agent-agnostic guidance that any
exobrain benefits from was missing.

## Pattern

Carry the *universal* slices of that guidance — scrubbed of any host-specific or
org-specific process — while keeping `AGENTS.md` tight:

- **AGENTS.md** gains: *Testing* (fix every failure; re-run before pushing),
  *Audit the surface area of every change* (grep what else references the thing you
  touched), a fuller *File naming* convention (the allowed-UPPERCASE list, `_raw/`
  exemption), *Keep auto-loaded specs tight*, and *verify a script before running it*.
- **workspaces/README.md** becomes a full methodology: naming, the `README.md` +
  frontmatter, **workstreams** (numbered sub-efforts), lifecycle, opt-in timeline
  tracking, optional patterns, and workspaces-vs-`tmp/`.

## Reference (illustration only)

See `AGENTS.md` and `workspaces/README.md` in the seed at or after this card's date.

## Adapt notes

Bring only what's universal; leave behind anything tied to a specific git host,
PR/review flow, or toolchain. Keep your `AGENTS.md` lean — if a rule is depth
rather than a must-follow, push it into `domains/exobrain/` instead. No invariant
is touched.
