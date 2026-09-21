---
id: 0133
title: Prune gitignored bulk directories from the validator's tree walk
date: 2026-09-21
tags: [validation, scripts, performance]
touches_invariant: false
files: [scripts/validate-exobrain.sh, .gitignore, skills/exobrain-tests/unit/test-validator-scan.sh]
---

## Problem

Workspaces cache exports under `_cache/` by convention. The validator's
`find_repo` pruned clones and worktrees but walked every `_cache/`, once per
whole-tree check — with a large export the validator, and the pre-push hook that
runs it, took minutes.

## Pattern

Prune `_cache` by name at any depth in `find_repo`, and ignore `_cache/` in
`.gitignore` so the two agree. State the two rules that keep the validator fast
at the top of the script: a check that spends a process per file stays
diff-scoped, and a bulk directory `.gitignore` excludes gets pruned. The harness
asserts a similar-looking name (`my_cache`, `_cached`) is still scanned.
