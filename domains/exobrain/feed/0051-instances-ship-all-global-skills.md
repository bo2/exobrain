---
id: 0051
title: Instances ship every global skill, with a correct force-based skills.json
date: 2026-06-20
tags: [skills, bootstrap, scripts]
touches_invariant: false
files: [seed/skills/create-instance/SKILL.md, domains/exobrain/skills.md]
---

## Problem

The instance generator registered the skills it copied with an invalid `scope`
field and **no `force`** — so in a fresh instance those global skills resolved to
*off* (a global declaration reaches a person only via `force: true` or an
owner-match, and the owner was blank). It also copied only a subset, omitting
several global skills — including the self-test suite — so an instance couldn't do
what the seed ships the capability for.

## Pattern

Register each copied global skill as a declaration with `force: true` and **no
`scope` field** (the home scope is wherever the `skills.json` lives). Copy the full
set of global skills so an instance has the same capabilities the seed ships —
update/pull (`exobrain-evolve`), save (`exobrain-persist`), authoring
(`exobrain-reader-lens`), domains (`exobrain-domains`), context A/B
(`exobrain-ab`), tools (`exobrain-tools`), and self-test (`exobrain-tests`). Keep
the copied skill dirs and the `skills.json` entries in lock-step.

## Reference (illustration only)

```json
{ "$schema": "./skills.schema.json", "skills": [
  { "name": "exobrain-evolve", "owner": "", "tier": "optional", "force": true },
  { "name": "exobrain-tests",  "owner": "", "tier": "optional", "force": true }
] }
```

## Adapt notes

A global skill needs `force: true` to reach a person whose handle isn't its
`owner`; without it the skill ships on disk but never surfaces. If your instance
curates a narrower skill set, that's fine — just keep the registered names matched
to the copied dirs, and use the `force`-based shape (no `scope`).
