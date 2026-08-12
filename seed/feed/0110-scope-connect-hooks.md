---
id: 0110
title: Let a connected scope extend the connect with a hook of its own
date: 2026-08-12
tags: [scopes, agents, scripts]
touches_invariant: false
files: [scripts/connect-agent.sh, knowledge/exobrain/agents.md, knowledge/exobrain/machinery.md, AGENTS.md]
---

## Problem

The connector wires an agent from what the framework knows about: scopes, skills,
tools, indexes. A scope sometimes needs one thing more — registering a session
hook, linking a file the framework has no concept of, preparing a local directory.
There is nowhere to put that, so it ends up as a manual step nobody re-runs, and
it silently rots the first time someone relinks.

The validator already had the shape of the answer: a connected scope may carry its
own `scripts/validate-exobrain.sh` and the shared validator runs it. The connect
side had no counterpart.

Worth naming separately: this framework *documented* the connect-hook step for
some time while the connector never implemented it. A documented step that no code
executes is worse than an absent one — a scope author writes the hook, sees no
error, and reasonably believes their setup ran.

## Pattern

Give each scope in the resolved chain a place to extend the connect, and run them
in the order the chain already implies:

- `<scope>/scripts/connect-agent.sh` — every agent
- `<scope>/scripts/connect-agent.<agent>.sh` — that agent alone

Run shallow→deep so a deeper scope acts after the scopes it inherits from; when
both files exist, universal first. Pass the hook what it cannot look up:
`<hook> <agent> <target-dir> <scope-dir>`.

Three rules keep it from becoming a footgun:

- **Skip the global scope.** Its `scripts/connect-agent.sh` *is* the connector, so
  running it as a hook recurses. Any convention where a scope-level path collides
  with a framework path needs this exclusion.
- **A failing hook is reported, not fatal.** One scope's extra must never cost the
  human their wiring. Print the exit status and the hook's own output, then carry
  on.
- **Hooks run below the side-effect-free cutoff.** A render mode that promises no
  writes outside the target dir cannot run arbitrary code from a scope; put the
  hook call after that early exit, alongside the other real-write steps.

## Adapt notes

Extends the wiring contract; preserves scope resolution — hooks follow the chain
order, they don't alter it. State the new write surface wherever the spec warns
what running the connector touches: a hook is arbitrary code, so "this script
writes git hooks and per-agent config" becomes "…and whatever each connected
scope's hook writes."

An instance whose connector is restructured should key the hook lookup off its own
resolved chain rather than re-deriving the scope list.
