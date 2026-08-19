---
id: 0120
title: Ship a harness-engineering doctrine domain and gate harness work on it
date: 2026-08-19
tags: [knowledge, doctrine, testing, gates]
touches_invariant: false
files: [knowledge/harness-engineering/, AGENTS.md, skills/exobrain-ab/SKILL.md, skills/exobrain-tests/SKILL.md]
---

## Problem

The framework ships serious harness machinery — a behavioral A/B skill, a
three-suite self-test skill, a layered validation gate — but the engineering
doctrine behind that machinery lived nowhere. An agent asked to build an eval
loop, design a gate, structure multi-agent work, or change auto-loaded context
started from scratch each time, re-deriving (or missing) disciplines the
machinery already embodies: held-out hygiene, blind protocols, adversarial
verification, negative controls, containment by construction.

## Pattern

A framework knowledge domain, `knowledge/harness-engineering/`, holding the
application-agnostic doctrine of engineering with LLM agents: `principles.md`
plus topic docs for eval loops, blind protocols, adversarial verification,
behavioral testing, gates and proof, orchestration, and failure modes. Doctrine
lives there; mechanics stay in the machinery and the meta-domain — each topic
doc points at its resident implementation (`exobrain-ab`, `exobrain-tests`, the
gate stack) instead of restating it, and the two skills point back at the
doctrine. Content held to a grounding bar: every pattern was audited against
the practice that produced it, unproven material was removed rather than
hedged, and claims were reworded to what the evidence supports.

Root `AGENTS.md` gains a read trigger beside the meta-domain's: before starting
harness work — designing or changing anything an agent auto-loads or invokes (a
spec, skill, gate, eval, standing automation, or multi-agent structure) — read
the domain, and check new designs against its `failure-modes.md`.

## Adapt notes

The domain is framework body, so instances receive it whole; the knowledge
index picks it up on relink. If your instance renamed the A/B or test skills,
re-point the resident-implementation lines. Keep the doctrine/mechanics split
when extending it — a new pattern earns its place with evidence, and machinery
details belong beside the machinery, not in the domain.
