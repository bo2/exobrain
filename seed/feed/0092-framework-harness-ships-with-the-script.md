---
id: 0092
title: A framework script's test ships with the script, not with the generator
date: 2026-07-28
tags: [tests, skills, seed]
touches_invariant: false
files: [skills/exobrain-tests, seed/skills/seed-tests, domains/exobrain/machinery.md, domains/exobrain/skills.md, seed/README.md]
---

## Problem

A repo that both *is* an exobrain and *generates* them has two test skills: one that
ships downstream and tests the instance it's installed in, and one that stays behind
and tests the generator. Deterministic harnesses for the framework scripts — the
connector, the registry, the authoring gate — land in the generator's skill, because
that's where whoever changes those scripts is working.

But those scripts are **framework body**: every instance inherits them, and instances
are expected to diverge them. So the instance inherits the code and not its tests. An
instance that re-synthesizes its connector has no regression coverage and must
re-derive the harness from scratch. Meanwhile the generator-side skill accretes a
section it describes with a tell: "*also* houses…".

## Pattern

**A test lives with the code it covers, not with the person likely to edit it.** If a
script ships downstream, its harness ships downstream too.

That leaves the generator's suite testing the one thing no instance can: that the
generator produces a working instance. Everything downstream of that is the built
instance's own suite, which the generator invokes — so the generator gets the
coverage without owning the tests.

Sort self-test suites by **what's under test**, not by who wrote them:

```
skills/<tests-skill>/
  unit/         # the machinery — fake fixtures in temp dirs, no agent, free
  behavior/     # the agent — does it follow the specs? one session per case-run
  onboarding/   # the environment — fresh machine, real network
```

Cost tracks that axis and decides cadence: the unit suite is free, so it runs on
every machinery change; the others are opt-in. A generator pipeline should run the
built instance's unit suite *before* its agent-driven one — free, and a failure there
explains a behavioral failure that would otherwise look like an agent problem. It
also proves the scripts work in a *rendered* instance, not only in the generator's
own checkout.

Watch for the inverse error too: a harness that reads the generator's real tree
instead of building fixtures isn't portable. Keep every case self-seeding — one that
needs a generator-only directory creates a fake one in a temp dir.

## Adapt notes

Check whether this is even a defect in your setup before moving anything: if the
harness genuinely tests the generator's own bootstrap, it belongs where it is. The
test is whether the script under test ships downstream.

Expect the original placement to have been **correct when it was made**. A single-suite
tests skill offers no home for a deterministic, no-agent harness, so generator-local
is the right call until the skill grows sub-suites — at which point the premise
expires and the decision should be revisited rather than inherited. A resolved
workspace recording that decision is a point-in-time record, not current policy; read
it for the reasoning, not as a constraint.

Moving a harness is mechanical but has surface area: the relative depth from the
script to the repo root changes, and every doc naming the old path moves with it —
the machinery index, its verification recipe, both skills' `SKILL.md`, the generator's
README, and the skills depth doc. Leave prior feed cards alone: their `files:` lists
record what a past change touched and are history, not current paths.

If the generator ships skills by copying whole skill directories, a new sub-suite
propagates with no registry change — no new skill row, no new index entry (card 0077).
