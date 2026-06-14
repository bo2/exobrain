---
id: 0016
title: Instance-oriented README — describe the live exobrain, not how to make one
date: 2026-06-14
tags: [exobrain-create, readme, propagation, authoring]
touches_invariant: false
files: [skills/exobrain-create/instance-readme.md, skills/exobrain-create/SKILL.md]
---

## Problem

The seed's root `README.md` is the "concept + generator" pitch — *"you don't fork this;
point an agent at it and it builds your own exobrain."* That's right for the canonical
repo and wrong for a generated instance: an instance is already built. The generator
copied framework files but laid down no `README.md`, so an instance had either none or,
if someone copied the seed's, an opening that tells its owner to go create the thing
they're already inside. A reader landing on an instance gets no instance-shaped answer to
"what is this, whose is it, how do I connect an agent here, how do I keep it current?"

## Pattern

A generated instance ships its own `README.md` that describes the **live exobrain**:
whose it is, the domains/workspaces/scopes split (pointing at `domains/exobrain/` for the
model), how to connect an agent on a new machine (`scripts/connect-agent.sh`), and how to
stay current (`exobrain-update`). It does **not** carry the seed's create-your-own pitch.
The template is a generator-owned asset (lowercase kebab, co-located with the generator),
read from the seed at generation time and stamped into the instance — never copied into
the instance as a standing file, since the generator skill itself is left behind.

## Reference (illustration only)

`skills/exobrain-create/instance-readme.md` (the template, with a `{{OWNER}}` placeholder
and a leading "this is a template" comment the generator deletes); a scaffold bullet in
`skills/exobrain-create/SKILL.md` § 2 that stamps it to `$DST/README.md`, plus a line in
§ 5 so a renamed durable-content dir rewrites the README's `domains/` references too.

## Adapt notes

No invariant touched. For an existing instance there's nothing to copy from the
generator (it lives only in the seed) — the takeaway is the *pattern*: replace a missing
or seed-derived root `README.md` with one that describes your own exobrain. Keep
`domains/` literal and let your durable-content dir name flow through; keep the seed's own
README.md unchanged (it stays the concept + generator pitch).
