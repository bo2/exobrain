---
id: 0119
title: Sort content by what survives replacing the runtime
date: 2026-08-13
tags: [agents, scopes, authoring]
touches_invariant: false
files: [OPENCLAW.md]
---

## Problem

An agent runtime with a memory of its own — a workspace file, a daily note, a
session store — competes with the exobrain for the same material. "Durable
knowledge here, session scratch there" sounds like a rule but decides nothing at
the moment it is needed: is a cron definition durable? A chat id? A preference the
runtime learned yesterday? Everything feels durable to whoever just wrote it.

Left unsorted, it fails in both directions. Facts settle in the runtime's memory
where no other agent can see them, and the runtime's own operational state gets
mirrored into the exobrain, where it goes stale silently.

## Pattern

Sort by a question with an answer: **would it survive replacing this runtime with a
different one?**

What survives belongs in the exobrain — knowledge, preferences, skills, tool docs.
What dies with the runtime stays in its workspace — schedules, chat ids, ports,
session policy, daily memory. The runtime is the system of record for its own
operational state, so the exobrain doesn't mirror it.

Two clauses cover where the line looks blurry:

- **Procedure is portable; wiring is not.** A scheduled job's prompt names the
  skill it runs instead of restating the procedure, so the procedure stays in one
  place and the schedule stays in the runtime.
- **The runtime is also a tool.** What any agent needs in order to drive that
  machine belongs in the runtime's own tool doc; what only the runtime needs to
  know about itself stays in its memory file.

This belongs in the agent's sidecar, where the runtime's own agent reads it —
stated as the sorting question, not as a list of what goes where, so it decides
cases nobody enumerated.

## Adapt notes

Written for a runtime with its own memory store; an agent that keeps no state of
its own needs none of it. The clause about scheduled jobs assumes the runtime owns
scheduling — drop it where it doesn't.

Keep it short. This lands in an auto-loaded sidecar and is paid for on every
session, so it states the question and its two edge clauses, and pushes nothing
else into the reader.
