---
id: 0131
title: Repair recorded findings one isolated session per PR, with the session's handover in the PR body
date: 2026-09-21
tags: [persist, skills, automation, authoring]
touches_invariant: false
files: [skills/exobrain-repair-findings/, scripts/persist.sh, skills.json, knowledge/exobrain/landing.md, skills/exobrain-tests/unit/run.sh]
---

## Problem

Findings an unattended land records in a PR body (card 0129) accumulate: nobody
acts on a merged PR. And a later fixer sees only the diff — not what the person
asked for, which file the session decided owns a fact, or what it was unsure of —
which is often exactly what a "this fact lives in two places" finding turns on.

## Pattern

- **A detector, with the forge as the system of record.** `findings-pending.sh`
  lists merged PRs whose body carries the findings heading and that lack a
  `findings-repaired` label, oldest first. The search only narrows; the heading
  is verified per body, because prose *about* the mechanism matches the search.
- **A repair skill that takes exactly one PR per session**, applies only what
  each finding prescribes, changes wording and placement but never a recorded
  claim, lands in the foreground so the review blocks, and labels the source PR.
  A host that lands unattended schedules it in its `crons.json`.
- **`persist.sh --context <file>`** copies a session-written handover from the
  worktree's gitignored `tmp/` into the PR body — the one thing that survives the
  worktree's removal.
- `knowledge/exobrain/landing.md` is the person-facing account of all of it.

## Adapt notes

- The skill is declared `unlisted`: invocable by name and by a scheduled job,
  absent from every index. Its detector and that detector's harness live in the
  skill's own directory, which is also the committed proof a new shared skill
  needs.
