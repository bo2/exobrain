---
id: 0023
title: Worktree-first as the first action — close the "move it at persist" loophole
date: 2026-06-15
tags: [git, workflow, worktree, persist]
touches_invariant: false
files: [AGENTS.md, skills/exobrain-persist/SKILL.md]
---

## Problem

Worktree-first was split across two git-workflow bullets — one for
fast-forwarding the trunk, one for creating the worktree "before touching
files" — with each bullet's body spent on mechanics. The *timing* (this is the
literal first action, before any edit) never landed as the headline. Worse, the
persist skill's recovery line ("if work began in-place on the default branch,
move it to the branch first") read as a sanctioned alternative, so an agent
could comfortably edit on the trunk and reach for `git stash` at persist time
instead of registering a rule break. Net effect: uncommitted work sitting on the
default branch — exactly what worktree-first exists to prevent.

## Pattern

Collapse the two rules into one, led by the timing, with the trunk
fast-forward folded in as the first sub-step of one chain: **fast-forward →
create worktree → cd → then edit.** State the prohibition with the loophole named
shut: never edit or commit on the default branch directly — *not even a quick
fix, and not "I'll move it to a branch when I persist."* In the persist
procedure, demote the in-place recovery from an alternative to an exception:
"normally a no-op because you're already in the worktree; recovery only if work
wrongly began on the default branch — and worktree-first means that shouldn't
happen."

## Reference (illustration only)

`AGENTS.md` § Git workflow — the merged worktree-first bullet; and
`skills/exobrain-persist/SKILL.md` step 1, reworded so the stash-based recovery
reads as the exception it is.

## Adapt notes

No invariant touched. Refines the worktree-first / auto-persist conventions
(cards 0014, 0020) — keep your own default-branch name and worktree helper. The
point is editorial: make the *when* unmissable and don't let any recovery path
read as a green-lit way to start on the trunk.
