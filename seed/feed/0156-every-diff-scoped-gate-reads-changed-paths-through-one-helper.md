---
id: 0156
title: Every diff-scoped gate reads changed paths through one helper
date: 2026-10-08
tags: [validation, scripts, mounts, persist, authoring-review]
touches_invariant: true
files: [scripts/changed-paths.sh, scripts/validate-exobrain.sh, scripts/authoring-review.sh, scripts/mount-isolation.py, scripts/persist.sh, knowledge/exobrain/machinery.md, skills/exobrain-tests/unit/test-portable-paths.sh, skills/exobrain-tests/unit/test-mounts.sh]
---

## Problem

Git quotes a path holding a byte outside ASCII (`"\320\272…"`) unless
`core.quotePath` is off, and the quoted form names no file in the tree. Every
gate that scoped itself to a change — the validator's diff-scoped checks, the
authoring review, the isolation gate, persist's spec and machinery detection —
read `git diff --name-only` and looked the result up on disk, so a file with a
Cyrillic name skipped all of them. Four scripts, four readings, one hole.

## Pattern

One executable helper, `scripts/changed-paths.sh`, is the only reading of
"which paths does this branch change": committed against a base, uncommitted,
or both; `--added` for additions only; a pathspec after `--`. It runs git with
`core.quotePath=false` and NUL separators, lists a removed path too (the caller
decides whether a removal counts) and a rename by its new name. Bash gates and
the Python gate call the same file, so they read literally the same list.

The helper's absence is a violation, not a skip: the validator records it and
persist dies on it, since a silently missing helper would have every
diff-scoped check pass vacuously.

## Adapt notes

- Extends the validation contract; nothing it gated before passes now.
- Every harness that copies the validator, the review, or persist into a
  fixture copies the helper beside it.
