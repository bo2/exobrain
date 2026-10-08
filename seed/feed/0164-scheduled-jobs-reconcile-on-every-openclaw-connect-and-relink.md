---
id: 0164
title: Scheduled jobs reconcile on every OpenClaw connect and relink
date: 2026-10-08
tags: [openclaw, crons, connector]
touches_invariant: false
files: [scripts/connect-agent.sh, scripts/openclaw-cron-sync.py, knowledge/exobrain/agents.md, knowledge/exobrain/machinery.md, skills/exobrain-tests/unit/test-connect-agent.sh, skills/exobrain-tests/unit/test-openclaw-cron-sync.sh]
---

## Problem

`crons.json` registries are the source of truth for the scheduler (card
0123), but applying them was a separate command. A registry change that
arrived with a pull sat unapplied until someone remembered to run the sync.

## Pattern

The connector runs `openclaw-cron-sync.py --scopes <the connected chain>`
after the runtime config step, on connect and relink alike; the pull hooks
already relink, so a registry change takes effect when it arrives. Only the
connected chain's registries count — a machine runs the jobs its own scopes
declare — and only when the chain holds one: a checkout whose chain declares
no jobs never touches the scheduler, so a relink that resolved no scopes cannot
empty it. Never from a sandbox wiring or a linked worktree; a missing CLI or a
failed sync is reported and the connect carries on. `OPENCLAW_BIN` names the
binary, so a harness can point it at a fake.
