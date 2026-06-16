---
id: 0026
title: Run the behavioral harness across agents on an agent-neutral surface
date: 2026-06-16
tags: [testing, harness, agents, codex, claude]
touches_invariant: false
files: [tests/lib/invoke.sh, tests/run.sh, tests/lib/common.sh]
---

## Problem

A behavioral test harness (card 0025) that only drives one agent CLI answers
"does *this* agent follow the specs?" — but an exobrain is meant to be agent-neutral
(claude / codex / openclaw all load the same context). A spec the seed believes is
universal can be honored by one agent and ignored by another, and a single-agent
harness never sees the gap.

## Pattern

The instance under test is **agent-neutral content** — only the *invocation* and the
*permission model* differ per agent. So abstract those and run the same cases across
every agent:

- **One dispatch seam.** A single `invoke_agent <agent> …` maps the shared notion of
  permission profile (read-only / writable) onto each CLI's own model — e.g. a plan
  vs. accept-edits mode with a command allowlist for one engine, a read-only vs.
  workspace-write sandbox for another. Cases stay agent-neutral; only the seam knows
  the flags.
- **Build the fixture once.** The scaffolded instance is identical regardless of who
  will be tested; build it with one builder agent and run every agent against copies.
  Each agent loads its context its own way (a generated per-project dir for one;
  native root-`AGENTS.md` auto-load for another).
- **Skip, don't fail, on a missing agent.** Probe that each requested CLI is not just
  on PATH but actually *runnable* (a CLI can be installed yet broken), and skip an
  unavailable one with a notice rather than failing the run.
- **Fix the judge engine.** When an LLM-judge grades transcripts, pin it to one engine
  for all agents so verdicts are consistent and you're comparing agents, not judges.
- **Report per agent+case.** Key results by `agent/case` so a divergence (one agent
  passes, another fails the same rule) is visible at a glance.

## Reference (illustration only)

`tests/lib/invoke.sh` dispatches on the agent; `tests/run.sh` takes `--agents`,
filters to runnable ones, builds one template via a builder agent, then loops
agents × cases × N and labels the summary `agent/case`.

## Adapt notes

No invariant touched. Builds on card 0025 — keep your own profile→flag mappings and
add a seam per agent you support. The agent-neutrality is the point: if a case needs
agent-specific phrasing to pass, that's a signal the *spec* (not the test) is leaning
on one agent. One fidelity caveat to note where it applies: an agent that only
auto-loads the root `AGENTS.md` won't see per-scope sidecars that another agent gets
through its connect step — fine for root-spec rules, but call it out for
sidecar-specific behavior.
