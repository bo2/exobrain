---
id: 0071
title: Anchor evolve's triggers to the seed; route bare "update" to git pull
date: 2026-07-12
tags: [skills, routing, tests]
touches_invariant: false
files: [skills/exobrain-evolve/SKILL.md, skills/exobrain-tests/scripts/cases/update-routes-to-pull]
---

## Problem

A skill description is a router: its trigger phrases decide which intents it
claims. exobrain-evolve's description used generic phrases ("update their
exobrain", "pull the latest", "check what's new") with no seed anchor, so a
bare "update exobrain" — which by convention means *fast-forward the local
checkout* — routed into the seed-adoption flow instead of a plain `git pull`.

## Pattern

Anchor every trigger phrase to the skill's actual object ("adopt or borrow
from the seed", "take the seed's latest framework cards", "see what's new in
the seed") and add an explicit negative cue ("Not for refreshing this repo's
own checkout — that's a plain git pull") so the generic intent falls through.
Guard the routing with a behavioral case (`update-routes-to-pull`): prompt is
the bare phrase plus "tell me what you'd run, don't run anything"; a rubric
judge passes only a checkout-update plan. Routing is model-dependent, so the
case is informational (tracked per-agent), not a gate.

## Adapt notes

- Port the description re-anchoring even if you rename the skill; the pattern
  is trigger anchoring, not the specific wording.
- If your instance's convention differs (e.g. "update exobrain" *should* mean
  adoption), flip the rubric rather than skipping the case — the value is
  pinning the routing either way.
