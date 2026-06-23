---
id: 0057
title: Name the principle and its heavy tool distinctly — the lens stays the lens, the skill is an audit
date: 2026-06-22
tags: [skills, authoring, naming]
touches_invariant: false
files: [skills/exobrain-authoring-audit/SKILL.md, skills.json, AGENTS.md, domains/exobrain/machinery.md, scripts/authoring-review.sh, skills/exobrain-evolve/SKILL.md]
---

## Problem

The skill that operationalizes the always-on "Reader Lens" authoring principle was named after the principle itself (`exobrain-reader-lens`). That conflates two different things: the **lens** is a principle every piece of writing passes through in-head; the **skill** is a heavy, on-demand audit you reach for on a substantial or contested doc. One name for both blurs when to invoke the tool versus when to just apply the principle, and undersells what the skill actually is — a deliberate authoring audit.

## Pattern

Give the principle and its tool **distinct names**, each describing its own role. Keep the principle named for the lens it is ("Reader Lens"); name the skill for the work it does — an authoring audit (`exobrain-authoring-audit`). The skill's method (predict readers blind to the draft, derive required scope, trace each contested fact to a real reader need) is an audit; the name should say so, leaving "reader lens" to mean the principle. A reader scanning the skill registry then sees a tool named for its job, not an echo of the principle.

## Reference (illustration only)

Rename the skill directory and its `SKILL.md` frontmatter `name`, update the registry entry, and sweep every live reference (root spec, machinery index, the authoring-review script's pointer, any sibling skill that lists skill dirs). Leave historical changelog/feed entries on the old name — they record what was true when published.

## Adapt notes

Pure rename, no semantics — `touches_invariant: false`. The work is the surface-area sweep, not the move: a global skill is referenced by the registry, the auto-loaded specs, instance-scaffolding that copies skills by name, and the generated optional-skills index. Update the registry and references; the per-agent index regenerates on the next relink. An instance whose authoring skill already carries a broader, differently-named audit can skip this outright — it's a naming-clarity fix, not new capability.
