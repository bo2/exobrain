---
id: 0035
title: Ship a behavioral A/B-eval skill for context changes
date: 2026-06-18
tags: [skills, testing, agents, connect-agent]
touches_invariant: false
files: [skills/exobrain-ab/, skills.json]
---

## Problem

Most changes to an exobrain's auto-loaded context — an `AGENTS.md` line, a skill tweak, a tool-doc edit — ship on intuition: *"this will help the agent."* Often it doesn't, or helps far less, or only on one model. There's no cheap way to check whether a context change actually moves agent behavior *before* committing to it, so the framework accretes well-meant lines that don't earn their token cost.

## Pattern

A **framework skill** (propagated to every instance, not seed-local QA) that A/B-tests a context change by content: build a **control** sandbox (trunk) and a **treatment** sandbox (trunk + the one change), wire each via *the sandbox's own* connector render mode (so it loads context exactly as a real session, side-effect-free), then run a real headless agent on a task N times in each arm and **measure the decision, not the outcome** — which tool/command the agent reaches for, captured by PATH-shadow stubs that log the invocation and return canned output. Report control-vs-treatment pass rates.

Make it trustworthy with three rules: a **discriminator constraint** (a task only measures the change if its target tool is reachable *only* via the change and is a bare command a stub can shadow); **dev + held-out tasks with negatives** (the single best task always overstates; held-out + no-tool tasks catch overfitting and over-triggering); and **run the production model** (effects are strongly model-dependent).

## Reference (illustration only)

`skills/exobrain-ab/` with `SKILL.md` + `scripts/{run.sh,run_one.sh,stubs/,tasks.example.sh}`. `run.sh` derives trunk and origin from the repo (instance-portable), builds the two sandboxes with `git archive` (+ `git apply` for treatment), renders each with `connect-agent.sh <agent> --render-specs-only`, and runs an N×(task×arm) matrix; `run_one.sh` grades one run by regex over the stub log. Sandboxes and results land under the gitignored `tmp/`. Register it in `skills.json` at global/optional tier.

## Adapt notes

Depends on the connector's side-effect-free render mode (feed card for "side-effect-free connector render") — the skill delegates context-wiring to it rather than reimplementing it. Sandboxes render **guest** (global scope only), which covers most framework changes; deeper-scope changes need a connected leaf wired into the sandbox. The stubs are the agent-neutral measurement layer — ship a template stub and one example task; real use adds a stub per measured tool. Tools invoked via MCP or by full path aren't stub-gradable (they need a transcript capture this harness doesn't have) — note that limit rather than silently miss them. Copy the skill cleanly where undiverged; re-synthesize `run.sh`'s connector invocation if your render flag or sandbox-config model differs.
