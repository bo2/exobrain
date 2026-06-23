---
name: exobrain
type: system
curator: oleg
summary: How this exobrain is structured and how its mechanisms (scopes, skills, tools, propagation) work — the meta-domain, written for an agent.
---

# Exobrain (the repo itself)

> **Not a product.** A meta-domain documenting how an `exobrain` repo is structured and how its mechanisms (scopes, skills, tools, propagation) work — written so an **agent** can read it and either run an existing exobrain or build a new one.

## TL;DR

An exobrain is a knowledge base plus an agent connector. It holds two kinds of content — **domains** (current truth, kept current) and **workspaces** (time-bound efforts that outdate by design) — and connects coding agents (Claude Code, OpenClaw, Codex) to them via `scripts/connect-agent.sh`. Context is organized in scopes that overlay innermost-wins: `global < [group] < person < host`. A person needs no group; groups appear only when more than one person shares context. Skills are the unit of agent capability — directories declared in a scope's `skills.json` and surfaced per tier (`always` / `optional` / `off`).

Crucially, an exobrain is **one implementation of a shared concept, not a fork of shared code.** New capabilities propagate as *patterns an agent re-synthesizes locally*, never as merged code. See [`propagation.md`](propagation.md).

## Index

| File | Covers |
|---|---|
| [`entities.md`](entities.md) | The content types — domains, workspaces, people/groups — and the "promote, don't link" rule |
| [`scopes.md`](scopes.md) | The scope stack (`global < [group] < person < host`), resolution, overrides, top-level person |
| [`agents.md`](agents.md) | Agent-agnostic content — per-agent sidecars, markers, injection surfaces, non-interference |
| [`skills.md`](skills.md) | The skills system — registry, tiers, resolution, linker, fetcher, agent filtering, authoring craft |
| [`tools.md`](tools.md) | External tools — the per-tool-doc catalog under `tools/`, scope overlays/resolution, `.exobrain.json` state |
| [`domains.md`](domains.md) | How to structure a domain — directory layout, scope design, WIP (`.wip`) domains, the `TIMELINE.md` convention |
| [`authoring.md`](authoring.md) | How to write well-formed domains — horizon, current-state, synthesis, citations |
| [`grill.md`](grill.md) | The interview discipline — distilling and curating knowledge through adversarial, one-question-at-a-time interrogation |
| [`propagation.md`](propagation.md) | How exobrains share improvements — the read-target/feed model, the borrow workflow, invariants |
| [`machinery.md`](machinery.md) | Index of the concrete machinery — every script, git/session hook, registry, and quality gate, with the verify-a-connector-change flow |

## For an agent instantiating a new exobrain

Read [`propagation.md`](propagation.md) → *Instantiating*. The short version: these files describe principles, not a rigid layout. Choose names and structure that fit your principal (a different durable-content dir name, with/without groups). Preserve the **invariants** (security, scope-resolution semantics, the validation contract); adapt everything else.
