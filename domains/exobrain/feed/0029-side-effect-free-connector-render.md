---
id: 0029
title: Add a side-effect-free render mode to the agent connector
date: 2026-06-18
tags: [connect-agent, setup, testing]
touches_invariant: false
files: [scripts/connect-agent.sh]
---

## Problem

The connector wires a checkout for an agent — scope specs, skills, the per-agent context surface — but in the *same* run it also writes **outside** the repo: a shell-profile PATH edit, sibling-repo clones, git hooks, the connect marker. That bundling means you can't reuse the connector to wire a *throwaway copy* (a test sandbox, a CI checkout, a preview) without scribbling into global state. So anything that needs a faithfully-wired copy ends up reimplementing the connector's per-agent rendering by hand — which silently drifts when the connector changes.

## Pattern

Add a flag that runs **only** the part that builds the in-repo context surface — scope-chain discovery, scope/skill linking, the optional-skills index, and the per-agent injection into the target dir — then **stops before any write outside that dir**. Because the connector derives the repo root from its own location, running a copy's *own* connector with the flag wires *that copy's* (possibly modified) files, pointing at the copy. Any throwaway copy can then be wired exactly like a real checkout with zero global side effects — by delegating to the connector instead of mirroring its output — for every agent the connector already supports.

## Reference (illustration only)

A boolean flag (`--render-specs-only`); after the per-agent injection block, an early `exit 0` placed *before* the sections that write the connect marker and install git hooks. Resolve config like `--relink` (a copy with no config renders as guest; never prompt or write config). Steps that write *inside* the target dir (e.g. disabling the agent's native memory) stay on the near side of the exit.

## Adapt notes

The early-exit must sit after the context-surface injection but before the first out-of-dir write — audit the connector's tail sections to place it. For an agent whose config lives in a global location, honor a HOME-style override (e.g. `CODEX_HOME` / `OPENCLAW_WORKSPACE`) so the render lands in the copy, not the user's real config; for an agent that wires via a gitignored marker *file* at the repo root, a `cp`-based copy can carry a stale marker — clear stale markers first (a `git archive` copy never has them). Preserve the invariant that the render produces the same surface a full connect would — it's a truncation of the connect path, not a parallel one. Pairs with a behavioral test/eval harness that needs hermetic, faithfully-wired sandboxes.
