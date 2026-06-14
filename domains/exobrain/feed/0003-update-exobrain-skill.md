---
id: 0003
title: update-exobrain — read the changelog, copy or rewire, record
date: 2026-06-07
tags: [update, propagation, skills]
touches_invariant: false
files: [skills/update-exobrain/, domains/exobrain/propagation.md, domains/exobrain/feed/README.md]
---

## Problem

Instances had no first-class way to pull framework fixes and features after
creation. The feed-borrow flow lived in a separate skill, and "what changed since I
last updated" was only implicit in card IDs.

## Pattern

Treat the feed as a **changelog**, and ship a single `update-exobrain` skill *in*
every instance. It fetches the seed, diffs the feed against the instance's adoption
ledger, and applies each new card **permissively** — *copying* the seed's files
where the instance is undiverged, *re-synthesizing* where it diverged — then records
the adopted IDs. This folds in the old separate feed-borrow flow: one "bring me up
to date" entry point.

## Reference (illustration only)

The procedure is `skills/update-exobrain/SKILL.md` in the seed.

## Adapt notes

Ship `update-exobrain` in the instance (`create-exobrain` copies it); keep
`create-exobrain` in the seed only. Seed the instance's adoption ledger with every
card present at creation, so `update-exobrain` only processes cards published later.
No invariant is touched — this adds a mechanism, it doesn't change resolution,
security, or validation.
