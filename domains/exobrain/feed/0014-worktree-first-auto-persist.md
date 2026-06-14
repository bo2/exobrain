---
id: 0014
title: Worktree-first auto-persist as the default git flow
date: 2026-06-13
tags: [git, workflow, skills, propagation]
touches_invariant: false
files: [AGENTS.md, skills/exobrain-persist/SKILL.md, scripts/create-worktree.sh]
---

## Problem

The persist flow (card 0012) was framed as an *explicit* act — the agent committed
and integrated only when the user said "persist", because the standing posture was
"commit or push only when asked". That leaves completed work uncommitted until
someone remembers to ask, and lets a quick fix land straight on the default branch
with no worktree. The git discipline existed but wasn't the *default*.

## Pattern

Adopt a worktree-first, PR-based git flow as the default, and drop the "commit or push
only when asked" gate entirely:

- **Start from current trunk.** Fast-forward the default branch before branching, so
  work builds on current state, not a stale base.
- **Worktree-first, always.** Every logical change gets its own branch + worktree
  (`create-worktree.sh`); never commit on the default branch directly, even for a
  quick fix.
- **Auto-persist each completed logical change.** Standing authorization to commit,
  push, and merge without being asked — commit (one per logical change) → push → PR →
  squash-merge → update the main copy → remove the worktree. `exobrain-persist` is the
  procedure.
- **Never force-push** or rewrite pushed history.

This supersedes card 0012's "persist is the explicit save request" posture: persist
is now the default behavior, still invokable by name.

## Reference (illustration only)

`AGENTS.md` § Git workflow rewritten to the rules above; `skills/exobrain-persist/SKILL.md`
reframed from explicit-request to default flow; `create-worktree.sh` usage examples
genericized (generic branch names, no ticket/username).

## Adapt notes

No invariant touched. The durable idea: completed work auto-persists end-to-end —
commit → push → PR → squash-merge → update the main copy — with no prompt; only
`--force` and rewriting pushed history stay off-limits. Default is the PR flow; a purely local instance with no remote
or review collapses
steps 4–7 into a fast-forward merge into the default branch. Keep your own
default-branch name and worktree helper. If you don't have the worktree helper or
`exobrain-persist` (card 0012) yet, adopt those first, or this collapses to
"auto-commit at each completed logical change".
