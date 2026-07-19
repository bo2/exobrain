---
id: 0079
title: Provision the behavioral suite from the working tree, not only HEAD
date: 2026-07-19
tags: [skills, testing, exobrain-tests]
touches_invariant: false
files: [skills/exobrain-tests/behavior/lib/provision.sh, skills/exobrain-tests/behavior/run.sh, skills/exobrain-tests/SKILL.md]
---

## Problem

The behavioral suite snapshots the instance at HEAD, so it can only test committed
state. A spec/skill/connector change has to be committed before it can be verified —
inverting the natural order (verify, then persist) and forcing throwaway commits to
test a work-in-progress.

## Pattern

Add a `--working-tree` provisioning mode that snapshots the *live* working tree —
committed plus uncommitted (new, modified, deleted, renamed), honoring `.gitignore`.
Build it by staging the working tree into a TEMPORARY git index (`GIT_INDEX_FILE`
pointed at a scratch path) and archiving the resulting tree, so the user's real
staging area is never touched. HEAD stays the default; `--working-tree` is the opt-in
for pre-persist verification.

## Reference (illustration only)

`provision_working_tree` runs `GIT_INDEX_FILE=<tmp> git add -A` then `git write-tree`,
and `git archive <tree> | tar -x` into the template dir. `run.sh` gains the flag and
branches the one provisioning call on it.

## Adapt notes

- The temp-index trick is what keeps it side-effect-free — never `git add -A` against
  the real index to build a test snapshot.
- Pairs naturally with the persist flow's shared-machinery behavioral gate: a change
  can be tested with `--working-tree` before the commit exists.
