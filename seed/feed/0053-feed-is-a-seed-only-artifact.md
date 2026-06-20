---
id: 0053
title: Make the change feed a seed-only artifact; instances keep one root ledger
date: 2026-06-20
tags: [propagation, feed, seed, persist]
touches_invariant: false
files: [seed/feed/, seed/AGENTS.md, skills/exobrain-persist/SKILL.md, skills/exobrain-evolve/SKILL.md, domains/exobrain/propagation.md, adopted-feed.md]
---

## Problem

The change feed was modeled as a peer-to-peer artifact: every instance carried a
full copy of the seed's cards (frozen at creation, never read by `evolve`, which
reads from the seed cache), the shared `persist` flow told every instance to publish
cards, and the adoption ledger lived inside the seed-synced meta-domain. In practice
propagation is hub-and-spoke — the seed publishes, instances adopt — and almost no
instance back-propagates. The symmetry cost real clutter: dead card copies, a
publish-judgment on every instance persist, provenance-leak risk from instance-
authored cards, and mutable state mixed into otherwise static concept docs.

## Pattern

Make the feed a **seed-only** artifact and split the two directions cleanly:

- **Cards live only on the seed**, under the seed-local area (a `feed/` beside the
  seed scope flag). They are never copied into an instance; the exclusion falls out
  of the existing "seed-local area is never rendered into an instance" rule, so the
  generator needs no special-case for the feed.
- **Publishing is seed-only.** The trigger to publish a card lives in the seed
  scope's own spec, not in the shared persist flow — so it is structurally absent
  from instances (no disable flag, just scope absence). The shared persist skill
  carries no publish step. An instance with a generalizable pattern contributes by
  adding a card in the seed repo directly — a deliberate, rare act that also forces
  the manual provenance-stripping such a contribution needs.
- **Adoption is the only instance-side concern**, recorded in a single ledger file
  (`adopted-feed.md`) at the **instance root** — mutable instance state, kept out of
  the seed-synced concept docs. `evolve` reads cards from the seed cache and diffs
  their IDs against this ledger.

## Reference (illustration only)

Move the card directory into the seed-local area; point the updater's card-read path
and the generator's ledger-seeding at it; relocate the publish-a-card instruction
into the seed scope's `AGENTS.md`; create the ledger at the repo root and drop the
"don't copy the ledger" special-case (it is no longer inside the copied tree).

## Adapt notes

If your instance diverged the durable-content dir name or the seed-local area name,
map the paths accordingly — the pattern is the *split* (feed + publishing on the
seed; one root ledger for adoption), not the literal directory names. No invariant
is touched: scope-resolution, security, and the validation contract are unchanged.
</content>
</invoke>
