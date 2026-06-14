---
id: 0013
title: Namespace global skills under exobrain-*
date: 2026-06-13
tags: [skills, naming, conventions]
touches_invariant: false
files: [skills.json, skills/exobrain-create/SKILL.md, skills/exobrain-update/SKILL.md, skills/exobrain-reader-lens/SKILL.md, skills/exobrain-persist/SKILL.md, AGENTS.md, README.md, domains/exobrain/propagation.md, domains/exobrain/feed/README.md, scripts/authoring-review.sh]
---

## Problem

The global meta-skills were named inconsistently — `create-exobrain` /
`update-exobrain` (suffix), `reader-lens` and `persist` (no marker). They don't
sort together, a bare name like `reader-lens` reads as if it could be any repo's
skill, and there's no signal that these are the exobrain framework's own skills
rather than user-authored ones.

## Pattern

Give every **global** framework skill the `exobrain-` prefix, so they group under
one namespace and are unmistakably the framework's:

| Before | After |
|---|---|
| `create-exobrain` | `exobrain-create` |
| `update-exobrain` | `exobrain-update` |
| `reader-lens` | `exobrain-reader-lens` |
| `persist` | `exobrain-persist` |

The prefix is a naming convention only — it changes the skill's registry `name`
and directory, nothing about resolution, tiers, or behavior. User/scope-authored
skills don't need it; it's for the global framework set.

## Reference (illustration only)

The renamed directories under `skills/`, their `name:` frontmatter, the
`skills.json` entries, and every live reference (root `README.md`, `AGENTS.md`,
`propagation.md`, `feed/README.md`, the generator's registration JSON + copy list,
the authoring-review escalation message).

## Adapt notes

No invariant touched. This is a wide-but-shallow rename — the work is the audit,
not the edit. Grep for each old name across specs, the generator skill (which
hardcodes the `skills.json` a new instance writes), and any script that names a
skill in user-facing output. **Don't rewrite historical feed cards** — a card
that introduced a skill records the name it had then; this card records the
rename forward, which keeps the feed correctly replayable. If your instance kept
the old names (or never had `reader-lens`/`persist`), adopt only the prefix
convention for the skills you do have.
