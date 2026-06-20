---
id: 0039
title: Split declaring a skill from enabling it — opt-in by default, force to share
date: 2026-06-18
tags: [skills, scopes, registry, resolution]
touches_invariant: true
files: [scripts/skills-registry.sh, skills.schema.json, scripts/skills-promote.sh, scripts/skills-status.sh, scripts/skills-validate.sh, skills.json]
---

## Problem

When a skill registry resolves by inheritance — a skill registered at a shared scope auto-loads for everyone under that scope — every skill someone drops into a shared folder lands in all their teammates' context. Shared scopes fill with narrow, one-person skills nobody else wants, and the only escape is an explicit opt-out. Placement and audience are conflated: putting a skill "where it might help" forces it on everyone there.

## Pattern

Split **declaring** a skill (it exists here, by this owner, at this recommended tier) from **enabling** it (turning it on for a scope). Two record kinds in each scope's registry:

- **Declaration** — lives in the skill's home folder; the folder *is* its scope, so it carries no scope field. Holds `owner` (who added it — who to ask; pure metadata), a recommended `tier`, and a `force` flag (default off).
- **Override** — references a skill declared elsewhere (`from` = its home scope) and sets a tier for the referencing scope; an `off` tier opts out.

Resolution: a declaration contributes its tier **only if `force` is true or the connecting user is its `owner`**; an override always contributes; the deepest scope wins; a skill with no contribution is **off**. Placement now expresses only *potential* audience — a skill dropped in a shared folder reaches just its owner until someone sets `force`, a deliberate reviewed act (the loud flag name is the social gate). Everyone else discovers it through a catalog command and opts in; a person can still `off` a forced skill.

This frees `owner` to mean "who to ask," because a skill's identity is now its location, not an owner key. And "registered but not enabled" resolves to off, so an undeclared skill directory is simply available-but-unused, never an error.

## Reference (illustration only)

```jsonc
// declaration (in the skill's home folder): owner-only unless forced
{ "name": "analytics", "owner": "ada", "tier": "optional", "force": true }
// override (in any scope): opt in, or opt out with "off"
{ "name": "analytics", "from": "groups/acme", "tier": "always" }
```

Resolution per skill: `contributes = isOverride || force || owner == connectingUser`; deepest contribution wins; none ⇒ off. **Framework/shared baseline skills carry `force: true`** so they reach every connected user regardless of owner; a fresh user copying the registry still gets them.

## Adapt notes

This changes resolution semantics — preserve the invariant that a deeper override beats a shallower declaration (so `force` stays overridable) and that absence means off. The moment non-forced skills become invisible to non-owners, add a discovery surface (a "list every declared skill" command) or useful skills go unfound. Keep the force flag changeable only through review — its whole value is governance, not mechanism. The connecting user's identity for owner-match comes from their own connected person-scope leaf basenames. Keep the resolver's **output contract** (the TSV columns the linker/index/validator read) unchanged so downstream consumers don't move when the resolution rule does.
