---
id: 0077
title: One self-test skill with sub-suites, not one skill per suite
date: 2026-07-12
tags: [tests, skills]
touches_invariant: false
files: [skills/exobrain-tests, skills.json]
---

## Problem

Instance self-testing had grown to two sibling skills — `exobrain-tests`
(hermetic behavioral) and `instance-tests` (real-environment onboarding) — with
a third suite likely someday. Each suite costs a skill registration and an
always-loaded index row, the names encoded neither the hermetic/real split nor
the subject (`instance-tests` misled: the behavioral suite also tests the
instance), and cross-suite helpers reached into a sibling skill's internals.

## Pattern

One `exobrain-tests` skill, sub-suites as subfolders — the "one skill, several
modes" shape (cf. `exobrain-domains`):

```
skills/exobrain-tests/
  SKILL.md          # umbrella: what each sub-suite verifies, when to run which
  behavior/         # hermetic behavioral suite (was scripts/)
  onboarding/       # real-environment suite (was instance-tests/scripts/)
```

Sub-suite names carry the subject; the skill name carries the family. Each
sub-suite keeps its own runner, cases, and requirements model — there is
deliberately no combined "run everything" entry point, so the hermetic suite's
no-network/no-creds contract survives consolidation intact and a non-hermetic
run stays an explicit choice. A future suite is a new subfolder, not a new
skill: no registry row, no new index entry, one SKILL.md section.

## Adapt notes

- Anything that invoked the suites by path moves: `skills/exobrain-tests/scripts/run.sh`
  → `behavior/run.sh`, `skills/instance-tests/scripts/run.sh` → `onboarding/run.sh`.
  On the seed, `seed-tests` hardcodes the first — update it in the same change.
- Drop the `instance-tests` row from `skills.json`; relink regenerates the
  agent's optional-skills index.
- Runner path resolution is depth-neutral (a sub-suite dir sits exactly where
  `scripts/` did), so only comments and log tags need renaming inside the
  suites.
