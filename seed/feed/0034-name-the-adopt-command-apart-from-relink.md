---
id: 0034
title: Name the seed-consume command apart from the relink op; split propagation / adoption / publishing
date: 2026-06-18
tags: [propagation, naming, skills, docs]
touches_invariant: false
files: [skills/exobrain-evolve/SKILL.md, skills.json, domains/exobrain/propagation.md, README.md, domains/exobrain/feed/README.md]
---

## Problem

The framework has two distinct operations that both attract the name **"update"**: the connect/relink op that refreshes the agent's wiring, and the skill that consumes framework changes from the seed (shipped as `exobrain-update`). Naming both "update" invites collision — "update my exobrain" is ambiguous — and the propagation docs compound it by drifting across loose synonyms (*absorb*, *consume*, *adopt*) for the same act, so the model never reads as one crisp vocabulary.

## Pattern

Give three concepts three distinct, non-overlapping names:

- **Propagation** — the whole process of changes moving between seed and instances (both directions).
- **Adoption** (verb: *adopt*) — the seed→instance direction: an instance taking in the seed's changes.
- **Publishing** — the reverse: an instance contributing a pattern back as a feed card.

Name the **command** an instance runs to perform an adoption with a verb that is **not** "update", so it never collides with the connect/relink op. Then sweep the framework docs so the loose synonyms collapse into *adopt* / *publish*, and the command name is used only for the command.

## Reference (illustration only)

Rename the skill `exobrain-update` → `exobrain-evolve` ("evolve" is one choice — any distinct verb works), updating its `SKILL.md` (name, heading, self-references), the `skills.json` registry entry, and every doc reference. The relink op keeps "update", mirroring `apt update` (refresh wiring) vs `apt upgrade` (take the newer version). The propagation doc gains a one-line vocabulary anchor and its "update workflow" becomes "the adoption workflow". Historical feed cards that named the old skill stay as-is — they're a dated changelog, not current state.

## Adapt notes

No invariant touched. The specific command verb is aesthetic — what matters is that it differs from the connect/relink op's name and that propagation / adoption / publishing stay three separate words. An instance that kept the seed's `exobrain-update` naming carries the latent collision; rename on adoption and align the prose in the same pass. Keep the skill's user-facing trigger phrases ("update", "sync", "pull latest") — those are how a user asks for it, distinct from the command's registered name.
