---
id: 0149
title: An agent spec lands only on a recorded passing behavior run, at any scope
date: 2026-09-22
tags: [persist, gates, behavior-tests, scopes]
touches_invariant: false
files: [scripts/persist.sh, skills/exobrain-persist/SKILL.md, skills/exobrain-repair-findings/SKILL.md, skills/exobrain-tests/SKILL.md, skills/exobrain-tests/behavior/run.sh, skills/exobrain-tests/behavior/lib/provision.sh, skills/exobrain-tests/behavior/lib/report.sh, skills/exobrain-tests/unit/run.sh, skills/exobrain-tests/unit/test-behavior-runner.sh, skills/exobrain-tests/unit/test-persist.sh, knowledge/exobrain/landing.md, knowledge/exobrain/machinery.md, knowledge/exobrain/scopes.md, knowledge/harness-engineering/gates-and-proof.md]
---

## Problem

The persist gate (card 0130) took the author's word for every behavior-shaping
change: a bare `--machinery-verified` cleared it, with nothing checking that a
behavior run happened, tested the change as it now stands, or loaded the changed
scope. And it exempted person and host scopes, where most of an instance's specs
live — so the rules agents actually load were the ones never gated.

## Pattern

Split the machinery in two. **Agent specs** — `AGENTS.md`, a `CLAUDE.md`/`CODEX.md`
sidecar, a `SKILL.md`, at any scope — land only on evidence: a passing behavior
run recorded under the worktree's `tmp/test-runs` whose `summary.json` says what
it tested. A run qualifies when every case met its threshold with no harness
error, at least one passing case drove an agent and was not the smoke check, no
spec differs between the tree it tested and the worktree's current tree, it wired
the spec's scope (or a scope below it), and for a sidecar it ran that sidecar's
agent. The PR body lists the qualifying runs. **The rest** — root scripts, root
skills' code, the registries, `OPENCLAW.md` sidecars (no harness runs OpenClaw) —
stays on the author's flag, which a sweep never supplies on its own.

The behavior runner records `tree`, `source` (`head` / `working-tree`), `agents`,
`scopes`, each case's `profile`, and `harness_error`, and gains `--scope <leaf>`:
each run copy is wired through the instance's own connector to that leaf and its
ancestors, and the chain's own cases under `<scope>/tests/behavior/` join the
suite, innermost winning by name.

An unattended land (a chat turn, the sweep, the repair job) cannot make a run, so
a spec change made there waits on its branch for an attended session; the reply
says the change is pending, not live.

## Adapt notes

Both halves of the gate read the worktree's working tree, so an uncommitted spec
matches a `--working-tree` run and a committed one a HEAD run. An instance whose
persist script diverged keeps its claim or resume logic and adds the gate's
functions beside it; the harness's `write_run` fixture shows the record shape.
Tool docs and person-scope `skills.json` registries stay ungated.
