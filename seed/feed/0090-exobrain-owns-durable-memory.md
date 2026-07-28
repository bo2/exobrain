---
id: 0090
title: Give an agent whose native memory stays on a memory-ownership rule
date: 2026-07-28
tags: [agents, memory, sidecars]
touches_invariant: false
files: [OPENCLAW.md]
---

## Problem

Agents ship their own persistent memory. Where the connector can turn it off it does,
so the exobrain is the single home for durable truth. But not every agent offers that
switch, and one that doesn't will quietly build a second knowledge base beside the
first: a fact learned in conversation lands in the agent's memory file, the domain that
owns it never hears about it, and the two drift. The failure is silent — both stores
look healthy, and the agent answers from whichever it happens to read.

## Pattern

For any agent whose native memory can't be disabled, its sidecar carries an explicit
**ownership rule**: durable knowledge belongs to the exobrain, native memory holds
session scratch and short-lived continuity. Name the memory file so the boundary is
concrete rather than abstract.

Then make the agent's routine memory-consolidation pass an *exobrain review*, since that
pass is the moment the two stores are open side by side. Two rules carry it, and neither
is already covered by the shared spec:

- **Reconcile rather than append.** An agent that only files produces a memory store
  accumulating every version of a fact. The promotion has to correct what it
  contradicts, not extend it.
- **No second copy.** Once something is promoted, the synthesis doesn't stay behind in
  native memory too — that's how the drift starts.

Resist adding the rest of the routing (read the domain first, promote durable findings,
workspaces hold time-bound efforts). Those already live in the shared spec the agent
loads in the same session; restating them in a sidecar buys nothing and drifts.

## Adapt notes

- This belongs in the **agent sidecar**, not in `AGENTS.md`: it applies only under the
  agent that has the memory, and the shared spec stays free of per-agent mechanics.
- State the rule, not the reasoning — a sidecar is auto-loaded and pays a token cost
  every session.
- An agent whose memory the connector disables needs none of this; check what your
  connector already does before adding a rule that no longer applies.
