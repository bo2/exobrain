---
id: 0123
title: Declare scheduled jobs per scope and reconcile them into the runtime's scheduler
date: 2026-09-07
tags: [scripts, automation, scopes, validation, openclaw]
touches_invariant: false
files: [scripts/openclaw-cron-sync.py, scripts/validate-exobrain.sh, scripts/authoring-review.sh, knowledge/exobrain/skills.md, skills/exobrain-tests/unit/test-openclaw-cron-sync.sh]
---

## Problem

An agent runtime with its own scheduler (OpenClaw's cron) holds every recurring
job — schedule, prompt, delivery, failure alert — as state on one machine, edited
by hand through its CLI or chat. Nothing in the repo says what runs where; a job
lost with the machine is gone; a prompt that names a skill drifts from the skill
it names; and a second machine connecting the same exobrain starts with no jobs.
The framework's own runtime-neutral ticker (card 0074) does not help here: it
runs alongside the runtime's scheduler rather than through it, so a job that
needs the runtime's session, delivery channel, or alerting cannot be declared in
the repo at all.

## Pattern

**The repo declares; a per-runtime reconciler applies.** Each scope directory
(any dir carrying `AGENTS.md`, the gitignored `local/` included) may hold a
`crons.json` registry; job names are unique across registries and each entry
carries everything the job needs — a schedule (`cron`+`tz`, `every`, or `at`),
a payload (an `agent` message or a `command` argv), delivery, and an optional
failure alert. `{ROOT}` in messages and argv expands to the repo root at sync
time, so a registry stays machine-neutral and one host's jobs live in its host
scope.

A reconciler owns exactly the runtime jobs it declared — every job whose
declaration key carries the framework prefix (`exobrain.<name>`) — and makes that
set match the registries: missing jobs are added, drifted ones patched, undeclared
ones removed. Jobs without the prefix (the runtime's own, one-shot reminders) are
never touched. Drift is judged only on the fields a registry entry declares, so
runtime defaults never fight the sync. The reconciler refuses to run from a linked
worktree, where `{ROOT}` would expand to a path that does not outlive the land.

The registry has an offline validator (`--check`, reading no runtime and needing
no binary) that the deterministic validation gate delegates to, so a malformed
registry fails the push, not the next sync. A model pin is deliberately not
declarable — routing stays with the runtime's defaults.

## Reference (illustration only)

```json
{"jobs": [{
  "name": "daily-brief",
  "schedule": {"cron": "0 12 * * *", "tz": "Europe/Berlin", "stagger": "5m"},
  "payload": {"kind": "agent", "message": "Work in {ROOT}. Run the daily-brief skill.",
              "thinking": "high", "timeoutSeconds": 900},
  "delivery": {"mode": "announce", "channel": "telegram", "to": "<chat id>"},
  "failureAlert": {"after": 1, "channel": "telegram", "to": "<chat id>", "cooldown": "6h"}
}]}
```

`scripts/openclaw-cron-sync.py` is the OpenClaw reconciler (`sync`, `--dry-run`,
`--check`); its unit harness drives it against a fake `openclaw` binary that
answers `cron list --json` from a fixture and records every call. The proof-gate
signal for a newly shared skill (card 0087) is a `crons.json` registration.

## Adapt notes

- Supersedes card 0074's `scripts/scheduler.py` + `schedule.json`. An instance
  whose runtime has no reconciler keeps the ticker until it writes one; an
  instance that has both retires the ticker and moves its jobs into `crons.json`.
- A reconciler for another runtime keeps the registry shape and the ownership
  rule (a prefix on the declaration key, foreign jobs untouched) and maps the
  payload and delivery fields to that runtime's vocabulary.
- After adopting, rename the proof signal in `authoring-review.sh` and
  `knowledge/exobrain/skills.md` from `schedule.json` to `crons.json`; the
  validator's `--check` delegation is one deterministic addition and changes no
  security or scope-resolution semantics.
- Ship no jobs with the framework — each instance's registries are its own;
  `--check` with no registry anywhere passes.
