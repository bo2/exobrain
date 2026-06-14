---
id: 0020
title: Persist via an auto-merged pull request
date: 2026-06-14
tags: [git, persist, workflow]
touches_invariant: false
files: [skills/exobrain-persist/SKILL.md]
---

## Problem

A persist flow that merges the branch straight into the local default branch and pushes
is fast, but it leaves no reviewable record, no place for CI to gate a change, and no
uniform path once more than one person writes to the exobrain. A "no PR ceremony"
shortcut and a real collaborative flow can't both be the default — the shortcut wins by
inertia and the history stays unreviewable.

## Pattern

Always land a completed change through a pull request, even when one agent both opens and
merges it. Push the branch, open a PR against the default branch, and — under the same
standing authorization that would have covered a direct push — squash-merge it
immediately, without waiting for human review. The PR is not a human gate; it's a durable
record and a hook point for CI. After the merge lands on the remote default branch,
fast-forward the local checkout and remove the worktree.

Keeping the merge automatic preserves the frictionless auto-persist contract; routing it
through a PR makes history reviewable and turns "add a real review gate later" into a
one-line policy change rather than a workflow rewrite.

## Reference (illustration only)

```
git push -u origin <branch>
gh pr create --base <default-branch> --fill
gh pr merge --squash                       # no --delete-branch from a worktree (see below)
git -C <main-checkout> pull --ff-only
git worktree remove <path> && git branch -D <branch> && git push origin --delete <branch>
```

## Adapt notes

Squash keeps the default branch linear and matches "one commit per logical change"; an
instance that wants full branch history merges instead. No invariant changes — it's the
same standing authorization, re-routed through a PR. An instance that genuinely wants a
human merge gate flips the "squash-merge immediately" step to "open the PR and stop"; the
rest is unchanged. Needs a PR host (e.g. `gh`); an instance without one keeps the direct
merge-and-push path.

When persisting from a git worktree (worktree-first flow: each change on its own branch +
worktree), don't let the merge tool delete the branch — `gh pr merge --delete-branch`
fails trying to check out the default branch, which the main checkout already holds. Merge
without it, then delete the branch by hand after removing the worktree.
