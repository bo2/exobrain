---
id: 0037
title: Add a machinery index to the meta-domain — one row per script, hook, registry, gate
date: 2026-06-18
tags: [domains, machinery, authoring]
touches_invariant: false
files: [domains/exobrain/machinery.md, domains/exobrain/README.md, AGENTS.md]
---

## Problem

The meta-domain explains each subsystem in depth (scopes, agents, skills, tools, propagation), but nothing lists the concrete moving parts at a glance — which scripts exist, which git and session hooks fire, which registries and quality gates run, and which artifacts are generated vs tracked. An agent auditing the surface area of a change, or onboarding to the repo, has to reconstruct that inventory by grepping. There's also no canonical writeup of how to **verify a connector/wiring change** end to end.

## Pattern

Add a `machinery.md` to the meta-domain: an **index, not a description** — one row per artifact, giving its role and a pointer to the topic file that explains it, grouped by subsystem (connection & linking, git hooks, session hooks, validation & gates, skills, tools, git workflow, agent-agnostic mechanism, propagation). Mark which artifacts are generated vs tracked. Fold in the **verify-a-connector-change runbook**: render a checkout side-effect-free, spot-check each agent's surface (and that every manifest import resolves), then run the deterministic validator. Register the new file in the meta-domain's README table and the root `AGENTS.md` depth list. Keeping it current becomes part of the standing "audit the surface area of a change" discipline.

## Reference (illustration only)

A `## Connection & linking` section, then `## Git hooks`, `## Session hooks`, `## Validation & quality gates`, `## Skills system`, `## Tools`, `## Git workflow`, `## Agent-agnostic mechanism`, `## Propagation`, `## Behavioral rules` — each a short table of `| Artifact | Role |`. The connection section closes with a bold **Verifying a connector/wiring change** paragraph.

## Adapt notes

- It's an **index, not a second copy** of the semantics — keep each row to a role plus a pointer, or it rots into a parallel spec that drifts from the topic files.
- List **only artifacts that exist in your instance** — scripts, hooks, skills, and tools differ across instances; don't carry rows for machinery you don't have.
- No invariant touched.
