---
id: 0098
title: Name the seed-initiated pull from instances "harvest"
date: 2026-07-31
tags: [propagation, skills, vocabulary]
touches_invariant: false
files: [knowledge/exobrain/propagation.md, knowledge/exobrain/machinery.md, knowledge/exobrain/skills.md]
---

## Problem

Propagation named three things — the whole exchange, the seed→instance direction
(*adoption*), and an instance contributing a card back (*publishing*) — and had no
word for the fourth, which happens anyway: someone notices an instance solved a
framework gap well and moves that solution up into the framework by hand.

Unnamed, that direction has no procedure, so it inherits the failure modes of an
ad-hoc backport. Instances are private and the framework is public, so a hand-carried
change is the most likely path for an org name, internal host, or client detail to
land in a public tree. And each pass re-examines the same long-standing divergences,
because nothing records that a difference was already looked at and judged local.

Calling this direction "adopt" doesn't work: adoption is already pinned to
seed→instance, and one word for both directions makes every sentence about
propagation ambiguous.

## Pattern

Give the seed-initiated pull its own word — **harvest** — and a procedure with two
filters that do all the real work:

- **Universality.** A candidate qualifies only if it would help an exobrain sharing
  *none* of the source's content. Instance knowledge domains, workspaces, person and
  host scopes, per-tool docs, and one-machine workarounds are rejected without being
  proposed. What's left must be a pattern rather than a payload, and must survive
  renaming everything — if it only makes sense with that instance's scope names or
  layout, it isn't universal yet.
- **Genericization.** Re-synthesize into the target's own names and voice; never
  paste across. A pasted hunk carries the source's shape and often its identity. A
  change that can't be described without naming its origin was never harvestable.

Then make it repeatable: record **every candidate presented**, adopted or declined.
Declines are the higher-value rows — without them the same divergences resurface
every run until the list is noise and nobody runs it. Keep the pull **read-only**
toward the sources: an improvement flows up as a re-synthesis, and the source gets it
back later through normal adoption.

Applies to any exobrain with downstream copies of itself, not only the canonical
seed. An instance with no downstream has nothing to harvest and needs none of this.

## Reference (illustration only)

The source list is per-machine and **must not be tracked** — an instance name can
carry an org, client, or person identity. It belongs in the gitignored per-machine
config beside the other machine state:

```json
{ "instances": ["acme/exobrain-alex", "/abs/path/to/a/checkout"] }
```

Entries as either a repo slug (cached into the gitignored `src/<repo>/`, the same
convention the seed cache uses) or an absolute local path (read in place, never
pulled or written). Mechanical scan → agent judgment → checkbox menu → re-synthesis
splits cleanly: a helper reports `differs` / `only-there` / `absent-there` per
source, and the agent decides which of those are universal.

## Adapt notes

- The vocabulary edit is the durable half — a fourth word only pays off if the other
  three stay pinned. Don't let "adopt" drift into meaning both directions.
- Scope the word to your own structure: if you renamed the meta-domain or the
  content tree, map candidates by *role*, not path, since older downstream copies
  lag your renames.
- The public/private asymmetry is what makes the genericization filter load-bearing.
  If your downstream copies and your framework are equally private, keep the filter
  anyway for provenance hygiene, but the leak risk is lower.
- A checkbox menu is one way to ask; any interaction that lets the human decline
  per-candidate works, as long as declines get recorded.
