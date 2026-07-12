---
id: 0074
title: One scheduler entry point for per-scope periodic jobs
date: 2026-07-12
tags: [scripts, automation, scopes]
touches_invariant: false
files: [scripts/scheduler.py]
---

## Problem

Periodic agent jobs (moderation sweeps, domain refreshes, monitors) accrete as
ad-hoc cron lines and tmux one-offs per machine — no shared registry of what
runs where, no overlap protection when a run outlives its period, and no way
for a scope (a group's jobs, a person's private jobs) to own its own schedule.

## Pattern

One `scripts/scheduler.py` entry point over declarative per-scope registries:
each scope directory (any dir carrying `AGENTS.md`, the gitignored `local/`
included) may hold a `schedule.json` listing jobs (`name`, `every`, argv
`command`, `timeout`, `enabled`); names are unique across registries.
Scheduling is period-based, not wall-clock: a tick starts a job when
`now − last start ≥ every`. Due jobs run in parallel (thread per job,
subprocess per run, cwd = repo root); a per-job flock makes runs of the same
job mutually exclusive, so a long run is skipped, not doubled. Four modes:
`tick` (cron entry point), `loop` (tmux; takes a host-wide lock and re-reads
the registries each tick so schedule edits deploy without a restart),
`run <job>` (manual), `status`. State and logs live under gitignored
`tmp/scheduler/` — per-machine by design.

## Adapt notes

- Ship no jobs with the framework; each instance's registries are its own.
  With no `schedule.json` anywhere the script exits with a clear message.
- Registry discovery prunes content trees and generated/clone dirs; if your
  instance renamed those, mirror your validator's prune list.
- Job commands run from the repo root; use `{ROOT}` for absolute-path args.
