---
id: 0019
title: Publish a feed card from the persist flow when a change is framework-general
date: 2026-06-14
tags: [persist, propagation, feed]
touches_invariant: false
files: [skills/exobrain-persist/SKILL.md]
---

## Problem

The propagation feed only works if framework improvements actually get recorded as
pattern-cards. Left to memory, "publish a card" is forgotten exactly when it matters —
the moment a generalizable fix lands — so the feed drifts behind the framework it is
meant to mirror.

## Pattern

Make the persist (land-to-trunk) flow auto-detect framework-general changes and publish
a feed card *per durable pattern*, in the same PR. "Framework-general" = an improvement
another instance — personal, family, company — could adopt: the shared machinery and the
framework's own meta-docs and skills. It excludes instance-specific content (a knowledge
domain, a workspace, a person/group/host scope, a tool doc tied to one setup). One PR
may warrant zero, one, or several cards (one per pattern, not per PR).

## Reference (illustration only)

A conditional step right after the timeline-update step: if the persisted diff touches
the shared framework surface and contains a generalizable pattern, add a dated card under
the feed dir (next never-reused id) per the feed's own format, committed alongside the
change.

## Adapt notes

The trigger is path + judgment: detect the framework surface cheaply by path, then keep
only changes that generalize. Keep the card schema in the feed's own `README.md`; the
persist step references it rather than restating it (no drift-prone duplication).
