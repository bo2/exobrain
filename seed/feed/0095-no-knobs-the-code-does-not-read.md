---
id: 0095
title: Fix the name of a universal singleton instead of offering a knob nothing reads
date: 2026-07-31
tags: [conventions, scripts, propagation, authoring]
touches_invariant: false
files: [seed/skills/create-instance/SKILL.md, seed/skills/create-instance/instance-readme.md, skills/exobrain-evolve/SKILL.md, knowledge/exobrain/propagation.md, knowledge/exobrain/README.md]
---

## Problem

The durable-content directory was presented as an instance choice: the generator
asked which name to use, offered alternatives, and carried a section explaining
which files must move together if you picked a different one. Docs spoke in a
`<durable-content-dir>` placeholder rather than a path, and feed cards carried
"if you renamed it, point the glob there" adapt notes.

Nothing read the value. Every consumer hardcoded the name — the connector's
index glob, the registry resolver, the validator's content-tree check, the
authoring filter, the secret-scanner allowlist. The "choice" was a documented
find-and-replace across the tree, offered at the one moment the user knows least
about the system, and it bought nothing: renaming the directory in the seed
itself got no help from the mechanism at all.

The tell was the sibling. The other content tree — the time-bound one — had
always been one fixed name. Both are universal, both exist in every instance,
both hold one kind of thing. Only one of them was presented as negotiable, and
nothing about the two justified the asymmetry.

An unread knob is not flexibility. It is a rename procedure with a settings
prompt attached, and it taxes every doc that has to speak in placeholders, every
card that has to carry an adapt note, and every reader who has to work out which
name applies here.

## Pattern

**Configure what genuinely varies between instances; fix what doesn't.**

Two questions separate them:

1. *Does anything read the value?* If every consumer hardcodes it, it is not a
   setting — it is a documented rename, and calling it configuration misleads.
2. *Does the variance come from the world or from taste?* Scope collections vary
   because principals differ: a solo user has no group, a household has one, an
   org may call it something else. A singleton every instance has exactly one of,
   holding exactly one kind of content, varies only by preference.

Where both answers say "fix it", use the literal name everywhere — docs, scripts,
generator, cards — and delete the placeholder along with the interview question
and the rename procedure.

Fixing the name does not forbid divergence. An instance that renames anyway is
already covered by the general adoption mechanism, which re-synthesizes into
local names and structure whenever an instance has diverged. That path handles
the rare renamer; a special case in the generator was redundant with it.

## Reference (illustration only)

What went away, in order of what it cost:

- the generator's "which name do you want?" interview question;
- its "if you renamed the durable-content dir" section, listing the files that
  must move together;
- `<durable-content-dir>` placeholders in the generator and the adoption skill,
  now literal paths;
- "if you renamed the durable-content dir" from the adoption skill's path-mapping
  note, which still covers restructured scopes;
- the durable-content dir as the lead example of expected divergence in the
  propagation docs — groups and restructured scripts still make the point.

## Adapt notes

Audit your own tree for the same shape: a name the docs treat as negotiable that
no code reads. Each one is either a real setting (wire it, and have the consumers
read it) or a fixed name (delete the affordance). Leaving it in between is the
only outcome with no upside.

Historical cards that mention adapting to a renamed directory stay as written —
they record what shipped on their date, and an instance that did rename still
reads them correctly.
