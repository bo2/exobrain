# Feed

The feed is the **changelog** of exobrain improvements — dated pattern-cards. It lives **only in the canonical seed** (`seed/feed/`): the seed publishes one dated card per durable framework pattern here, and instances read the cards they haven't adopted yet (via `exobrain-evolve`, from the seed cache) and apply each — **copying** the seed's files where undiverged, **re-synthesizing** where they've diverged in names or structure. An instance never carries its own copy of the feed. Background: [`../../knowledge/exobrain/propagation.md`](../../knowledge/exobrain/propagation.md).

A card describes a **problem and a pattern**, optionally naming the files it touches. Any reference snippet is **illustration**: an instance that diverged adapts the pattern; an instance that didn't can copy the seed's files directly.

**Cards are public and generic.** Never name a downstream instance's org, internal hosts, ticket prefixes, usernames, or private repos — describe the pattern, not its origin. See [`../../knowledge/exobrain/propagation.md`](../../knowledge/exobrain/propagation.md) → Provenance hygiene.

## Card files

One markdown file per card: `NNNN-slug.md`, where `NNNN` is a zero-padded, never-reused stable ID (the provenance key). Structure:

```markdown
---
id: 0007
title: Short imperative title
date: 2026-06-07
tags: [scopes, scripts]        # free-form; helps filtering
touches_invariant: false       # true if it changes security / scope-resolution / validation semantics
optional: false                # true for a pattern the seed offers without recommending (see below)
files: [scripts/connect-agent.sh]   # optional: seed paths this change touches (hint for the copy path)
---

## Problem
What gap or pain this addresses.

## Pattern
The durable idea — described so it survives different names and structures.

## Reference (illustration only)
An optional concrete snippet showing one way to do it. Adapt, don't paste.

## Adapt notes
What to watch when porting to a divergent setup; which invariant (if any) to preserve.
```

## Optional cards

Most cards are recommended: `exobrain-evolve` proposes them by default and the instance vetoes the ones that don't fit. A card marked `optional: true` is a pattern the seed **offers without recommending** — a preference that some instances hold and others deliberately don't, such as a hook that rewrites commit messages. Evolve sorts it under its **Optional** category, which is confirmed card by card unless the instance says otherwise. Its Problem names whose preference it serves, so the instance can decide on its own terms. Optionality is about the instance's stance, not the card's size: a small recommended fix stays recommended.

## Adoption ledger

Each downstream exobrain records which cards it has settled in its own `adopted-feed.md` **at its repo root** (not in the meta-domain — the ledger is mutable instance state, kept out of the seed-synced concept docs) — card ID, date, and a one-line note on the outcome: how it was applied (copied / rewired / already-present), or declined and why. A declined card stays out of the next run's list, so a preference the instance settled once is not asked again. Its header also records the **seed repository URL** that instance updates from, so `exobrain-evolve` knows where to pull the cache (`src/exobrain-seed/`) — the seed address is instance data, committed in that instance, not a per-machine setting. `exobrain-evolve` diffs this feed's card IDs against that ledger to show only what's new. The ledger answers *"am I current? did I get the fix for X?"* in a world with no shared code. (This canonical seed publishes the feed and keeps no ledger of its own.)
