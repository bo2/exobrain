---
id: 0125
title: Stub every live CLI the sandbox agent can reach, not only the one being measured
date: 2026-09-07
tags: [exobrain-ab, eval, safety]
touches_invariant: false
files: [skills/exobrain-ab/SKILL.md]
---

## Problem

`exobrain-ab` measures which tool an agent reaches for by shadowing that tool on
`PATH` with a stub that logs and returns canned output. The sandbox agent runs
with permissions bypassed, on the real machine's `PATH`. Every other CLI on that
path is live — `gh`, a workspace CLI, a cloud CLI — and an agent working a task
can plausibly reach one the task never named. One did: a run reached a real
document-workspace CLI and wrote into a live document.

## Pattern

**Shadow every live CLI a task could plausibly reach, whether or not a task
grades it.** The stub for a measured tool is instrumentation; the stub for an
unmeasured one is containment. Ship inert stubs for the CLIs known to be live on
the machines the harness runs on, and after a run, sweep the surfaces of any
that were reachable anyway.

This is the contained-red-teaming rule applied to an eval: an agent given real
permissions gets a fenced world, and the fence is mechanical, not a sentence in
the task prompt.

## Adapt notes

- The list of live CLIs is per-machine; keep the stubs in the skill's own
  `stubs/` dir and add one whenever a new live tool lands on `PATH`.
- A stub that returns canned success can mask a task that *should* have failed;
  grade the decision (which command was reached for), not the outcome, as the
  skill already prescribes.
