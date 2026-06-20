---
id: 0012
title: Persist skill — save local work to the default branch in one shot
date: 2026-06-13
tags: [skills, git, workflow, timeline]
touches_invariant: false
files: [skills/exobrain-persist/SKILL.md, skills.json, skills/exobrain-create/SKILL.md]
---

## Problem

Landing local exobrain changes is a multi-step ritual — branch/worktree, update
any opted-in timelines, commit per logical change, integrate to the default
branch, pull, clean up the worktree. Done by hand it's easy to skip a step (a
stale worktree left behind, a `TIMELINE.md` row forgotten). The steps are stable
enough to capture as one skill.

## Pattern

An `exobrain-persist` skill the user invokes by saying "persist" / "save" / "land" / "ship".
Invoking it *is* the explicit save request, so committing and pushing there is
consistent with a "commit or push only when asked" posture. It runs: get onto a
branch (via the worktree helper) → update timelines for touched workspaces/domains
whose `README.md` has `timeline: true` (append one summary row to `TIMELINE.md`) →
commit one-per-logical-change → integrate to the default branch → pull → remove
the worktree.

## Reference (illustration only)

`skills/exobrain-persist/SKILL.md` in the seed, registered in `skills.json` (tier
`optional`) and added to the set `exobrain-create` ships to a new instance.

## Adapt notes

No invariant touched. Match the integration step to your workflow: a solo
exobrain merges the branch to the default branch directly (no PR ceremony); a
shared instance pushes and squash-merges a PR. Use your own default-branch name
and worktree helper. The timeline step depends on the `timeline: true` /
`TIMELINE.md` convention (card 0010) — drop or gate it if you haven't adopted
that.
