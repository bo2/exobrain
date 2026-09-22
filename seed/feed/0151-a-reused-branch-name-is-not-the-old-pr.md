---
id: 0151
title: A PR from an earlier branch of the same name is not this change's
date: 2026-09-22
tags: [persist, git, scripts]
touches_invariant: false
files: [scripts/persist.sh, skills/exobrain-tests/unit/test-persist.sh]
---

## Problem

`persist.sh` looked up the branch's PR by head name and took the newest match.
A branch name reused after its PR merged found that old PR, read "already
merged", skipped the push and merge, and removed the worktree — with the commit
unlanded and dangling, recoverable only from `git fsck`.

## Pattern

Identify a PR by the commits it carried, not by its branch name. An open PR for
the head is this change's; a merged or closed one counts only when its head
commit (`headRefOid`) is an ancestor of the branch's HEAD. The harness seeds the
forge with a merged PR under the same name at an unrelated commit and asserts a
new PR carries the change.
