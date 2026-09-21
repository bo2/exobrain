---
id: 0140
title: Batch the validator's per-file greps and prune skills-validate's walks
date: 2026-09-21
tags: [validation, scripts, performance]
touches_invariant: false
files: [scripts/validate-exobrain.sh, scripts/skills-validate.sh, skills/exobrain-tests/unit/test-validator-checks.sh, skills/exobrain-tests/unit/test-skills-validate.sh]
---

## Problem

The whole-tree checks in `validate-exobrain.sh` spawned one `grep` per file, and
`skills-validate.sh` walked the entire checkout — clones, worktrees, caches — and
filtered the output afterwards. Both costs grow with the tree, and both run on
every push.

## Pattern

- Feed each whole-tree check's file list to `grep` in batches (`xargs`), one
  process per batch, and parse `file:line:` from its output.
- Prune in `find` rather than filter after it, the rule `find_repo` already
  follows (card 0133).
- **Pin the results before changing the mechanism.** A harness builds a fixture
  per check and asserts the *exact set* of violations it raises, so a batched
  check that drops or duplicates a hit fails the suite rather than passing
  quietly.

## Adapt notes

- Filenames with spaces or newlines are the batching hazard; pass them
  NUL-delimited.
