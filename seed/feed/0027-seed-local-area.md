---
id: 0027
title: Quarantine seed-local tooling under seed/ — never propagated to instances
date: 2026-06-17
tags: [seed, propagation, skills, structure]
touches_invariant: false
files: [seed/, seed/skills/create-instance/SKILL.md, skills.json, scripts/skills-validate.sh, README.md]
---

## Problem

A canonical seed carries tooling that operates on **itself**, not on the instances
it generates: the instance generator, and a behavioral test harness that boots a
throwaway instance to check it. These don't belong in a rendered instance — an
instance has nothing to generate and nothing to test against the seed. Scattered at
the top level, each such tool needs its own "don't copy this" carve-out in the
generator, and each is one oversight away from leaking into instances.

## Pattern

Give seed-local content a single home: a top-level `seed/` directory. Everything
under it operates on the seed itself and is **never copied into an instance**, so
the exclusion collapses to one rule — *the generator never copies `seed/`* — instead
of a per-tool denylist. Put the generator at `seed/skills/<generator>/` and the test
harness at `seed/tests/`, with a `seed/README.md` stating the boundary.

Because `seed/` is outside what propagates, seed-local skills sit **outside the
skills registry**: no `skills.json` entry, and the registry validator excludes
`seed/` from its declaration and orphan scans. They aren't surfaced through the
agent's skill tool; they're invoked by reading their `SKILL.md` directly (the public
bootstrap prompt points a fresh agent straight at the generator's `SKILL.md`). This
is the right trade — the generator runs from an *empty* directory at bootstrap, not
from within the seed, so registry discovery never mattered for it.

## Reference (illustration only)

`seed/README.md`, `seed/skills/create-instance/` (the generator), `seed/tests/` (the
harness). The generator's scaffold step says "never copy `$SRC/seed/`". `skills.json`
drops the generator entry; `skills-validate` adds `seed/` to its prune list. The
instance-shape test asserts no `seed/` appears in a generated instance.

## Adapt notes

No invariant touched. Keep your own generator and harness names. The point is the
boundary: one excluded directory beats N scattered carve-outs, and "is this copied
into instances?" becomes a path check. If you rename the generator out of `skills/`,
update the bootstrap prompt/README that names its path, and remember that anything
auto-loaded into instances (e.g. `AGENTS.md`) must not reference `seed/`, which
instances don't have.
