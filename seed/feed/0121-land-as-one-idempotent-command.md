---
id: 0121
title: Land as one idempotent command
date: 2026-09-07
tags: [scripts, git-workflow, persist, gates, testing]
touches_invariant: false
files: [scripts/persist.sh, skills/exobrain-tests/unit/test-persist.sh, skills/exobrain-persist/SKILL.md, knowledge/exobrain/machinery.md]
---

## Problem

The persist flow was an eleven-step procedure the agent walked by hand: timeline
rows, commit, behavioral verification, authoring review, push, PR, squash-merge,
pull the main checkout, remove the worktree, delete the branch. Every step was a
place to stop early, skip a gate, or diverge in wording — and a run interrupted
anywhere (a killed process, a failed pull, a merged PR whose worktree was never
removed) left state that the next attempt had to diagnose before it could
finish. The behavioral-verification gate was prose only: nothing but the agent's
own judgment stood between an unverified machinery change and the default branch.

## Pattern

Split the flow into the **agent-judged head** (what is a logical change; which
behavioral cases a machinery change could move; whether it is meant to alter
behavior) and the **mechanical tail**, and make the tail one script, run from
inside the worktree:

- **Every step checks whether it has already happened** before doing it — a
  timeline row already present, a branch already pushed, a PR already open or
  merged, a main checkout already fast-forwarded. Re-running after an
  interruption therefore resumes instead of repeating or failing; a failed step
  stops with the branch keeping every step already made.
- **The machinery gate is half mechanical.** A diff touching shared machinery
  (root scripts and skills, the registries, the global-scope specs) makes the
  script run the deterministic unit suite itself; the flag the agent passes
  asserts only the half a script cannot run — the behavior suite, and the A/B
  where the change alters behavior. Person and host scopes are exempt. The
  refusal names the flag and says which half is whose.
- **The land claims the worktree first** (a marker in the worktree's git dir that
  survives a kill, carrying the machinery assertion), and a `--sweep` mode lands
  every claimed worktree plus every clean one that is ahead of the default
  branch and quiet for an hour — never a dirty one.
- **Lands serialize** on a lock in the main checkout's git dir, so a chat-turn
  land and the sweep never race on the pull or the worktree table.
- `--dry-run` prints the plan; a repo without a remote collapses push → merge
  into a local fast-forward.

The skill keeps the judgment steps and hands the tail to the script by name.

## Reference (illustration only)

```bash
# from inside the worktree
scripts/persist.sh [-m "<commit message>"] [--timeline "<summary>"] [--machinery-verified]
scripts/persist.sh --sweep      # from any checkout: land what earlier runs left
```

The unit harness builds a bare origin, a main checkout, and worktrees in a temp
dir; the gates are stubs that record being called, and `gh` is a fake on PATH
that keeps PR state in a file and squash-merges into the bare origin the way the
forge would. Cover: the full land, the machinery gate in both halves, timeline
rows, each resume path, conflict handling, the no-remote path, and the sweep's
claimed / quiet / dirty rules.

## Adapt notes

The machinery path set is the skill's own definition of "shapes how other
agents behave"; an instance whose global specs or registries live elsewhere
adjusts the pattern in one place. The script honors the same
`EXOBRAIN_SKIP_AUTHORING_REVIEW=1` opt-out the review script does. Registries
of scheduled jobs are the natural home for the sweep on a host that runs
sessions unattended.
