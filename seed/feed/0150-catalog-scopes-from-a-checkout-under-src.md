---
id: 0150
title: Catalog skills from a checkout that itself sits under a src/ directory
date: 2026-09-22
tags: [skills, scripts, portability]
touches_invariant: false
files: [scripts/skills-status.sh, skills/exobrain-tests/unit/test-skills-status.sh]
---

## Problem

`skills-status.sh --all` hid clones and worktrees with `find -not -path '*/src/*'`.
The pattern is unanchored, so a checkout living at `~/src/<instance>` matched it
in full and the catalog came out empty — and a path filter walks everything it
hides anyway.

## Pattern

Prune the walk by directory *name* below the starting point (`-name src -prune`,
likewise `.git`, `node_modules`, `tmp`, `_cache`, and the seed directory by path)
rather than filtering absolute paths, so only the tree under the checkout is
judged. The harness builds the fixture under a `src/` parent and declares a skill
in every excluded directory, asserting the ordinary scope is catalogued and none
of the hidden ones is.
