---
id: 0056
title: Behaviorally verify shared-machinery changes at the persist gate
date: 2026-06-22
tags: [tests, persist, validation, skills, scripts]
touches_invariant: true
files: [skills/exobrain-persist/SKILL.md]
---

## Problem

A change to shared machinery — `scripts/`, the registries, a global skill, or a global-scope spec — shapes how *every* agent in the instance behaves, yet the persist flow gated it only with the deterministic validator (naming / JSON / registry shape) and the LLM authoring review (prose smells). Neither answers the question that matters for these changes: *does the agent still behave the way the specs say, and — for a change meant to alter behavior — did anything actually move?* A reworded rule that quietly breaks worktree-first, or a spec edit that changes nothing, lands unnoticed.

## Pattern

Attach a **behavioral** check to the deliberate land, alongside the existing prose and syntax gates. When the change touches shared machinery (scripts, registries, any skill, global-scope specs), run the behavioral suite before pushing; for a change *intended* to alter behavior, also run an A/B check (control = trunk, treatment = trunk + change) to confirm it moves what it claims to. Exempt pure docs and personal person/host-scope changes — they can't shift another user's agent.

Keep it **agent-run, not a script hard-gate.** Which cases a change could move, and whether the change is even behavior-altering, are judgment calls; and the suite spends real agent sessions, so firing it blindly on every persist is wasteful. The agent decides relevance and runs the relevant subset — the flow names the gate and the trigger, the agent applies judgment.

Order matters: a suite that snapshots the committed tree (HEAD) must run *after* the persist commit, so the change under test is actually in the snapshot.

## Reference (illustration only)

Add a persist step between **Commit** and the authoring review: if the change touches shared machinery, run the behavioral suite over the cases it could move and fix/amend on any failure; for behavior-altering edits, also run the A/B harness. Word it as agent-judged ("you decide which cases are relevant"), not a script invocation.

## Adapt notes

**Adds to the land contract** without weakening any existing gate — the deterministic validator still gates every push, the authoring review still fires at persist. Two knobs are instance-local: (1) where the line sits between "shared machinery" and "exempt" depends on your scope layout (global/team vs person/host); (2) whether the gate is agent-run or script-enforced is a trade-off — an instance that prefers determinism can wire the behavioral run into its persist/review script instead of trusting agent judgment, at the cost of running real agent sessions on every qualifying land. If your suite tests the working tree rather than a committed snapshot, the commit-first ordering relaxes.
