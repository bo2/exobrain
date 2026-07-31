---
id: 0100
title: State how to choose a skill's placement, tier, and force
date: 2026-07-31
tags: [skills, authoring]
touches_invariant: false
files: [knowledge/exobrain/skills.md]
---

## Problem

The skills registry has three settings that look related but aren't: which scope's
`skills/` the skill sits in, its `tier`, and `force`. The concept doc defined what
each *does* — placement is potential audience, tiers have behaviors, `force` shares
scope-wide — without ever saying how to **pick** them.

So the reader inferred, and inferred badly in a predictable direction: treating
placement as the sharing decision. That leads to hoarding skills in a person scope
to avoid imposing on anyone, when placement imposes nothing on its own and `force`
is the knob that does. The reverse error — declaring `always` because the skill
seems important — quietly taxes every session.

## Pattern

Name them as **three independent knobs** and give each a default:

- **Placement** — the *shallowest* scope the skill might ever serve. Placing
  optimistically is free, because a declaration reaches only its owner until forced.
- **`tier`** — `optional` by default. Reserve `always` for the rare skill earning
  its keep in a large share of sessions; `unlisted` for misfire-risk or name-only.
- **`force`** — off by default; on only for what the whole scope genuinely needs.

The one-line rule that resolves the common confusion: **placement is potential
audience, `force` is actual audience.** Until a skill is forced it imposes on no one,
and others opt in by discovering it in the catalog.

Keep this separate from the tier *behavior* table — the decision guidance and the
mechanics answer different questions, and merging them is why the guidance was
missing in the first place.

## Adapt notes

- Cross-reference rather than restate: if your concept doc already explains that a
  declaration reaches only its owner, the new section should add only the heuristics.
- Name your own scope vocabulary in the placement bullet (group, team, whatever your
  collections are called) — the heuristic is "shallowest scope that might serve it",
  not a fixed list of folders.
- If your registry gates shared declarations behind committed proof, point at that
  gate from the `force` bullet so the two rules are read together.
