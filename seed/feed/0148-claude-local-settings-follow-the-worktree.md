---
id: 0148
title: Claude's per-machine settings follow the worktree
date: 2026-09-22
tags: [worktrees, claude, scripts]
touches_invariant: false
files: [scripts/link-worktree-context.sh, skills/exobrain-tests/unit/test-connect-agent.sh, knowledge/exobrain/agents.md, knowledge/exobrain/machinery.md]
---

## Problem

`.claude/settings.local.json` holds a machine's permission allowlist and is
gitignored, so a fresh worktree had none of it: every session there re-prompted
for the commands the main checkout had long since allowed.

## Pattern

`link-worktree-context.sh` links the main checkout's `.claude/settings.local.json`
into the worktree beside the generated markdown, preserving a file the worktree
already owns.
