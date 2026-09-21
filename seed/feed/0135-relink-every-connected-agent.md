---
id: 0135
title: Relink every connected agent when --relink names none
date: 2026-09-21
tags: [connector, scripts]
touches_invariant: false
files: [scripts/connect-agent.sh, AGENTS.md, knowledge/exobrain/agents.md, skills/exobrain-tests/unit/test-connect-agent.sh]
---

## Problem

"Relink" was per agent, so every hint that ended in "then relink" had to guess
which agents were connected — from a config list that can miss one — or make the
human run the command once per agent.

## Pattern

`connect-agent.sh --relink` with no agent runs the relink once per agent whose
marker exists in the checkout — the loop the post-merge hook already runs. With
nothing connected it says so and exits 0; combined with any other flag it is a
usage error. The marker paths move into one `agent_marker` function shared by
both paths. The hook keeps its explicit per-agent loop, so a checkout whose
connector predates the form still relinks after a pull.

The same change retires compat shim 0005 (the `--render-specs-only` alias), past
its date.
