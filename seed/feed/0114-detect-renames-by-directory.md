---
id: 0114
title: Detect a rename by the whole directory, not its entry-point file
date: 2026-08-12
tags: [skills, validation, git]
touches_invariant: false
files: [scripts/authoring-review.sh, skills/exobrain-tests/unit/test-authoring-review.sh]
---

## Problem

Card 0094 established that a gate keyed on identity strings must resolve renames
before deciding something is new, and did it the obvious way: ask git for renames
over the entry-point file — for a skill, its `SKILL.md`.

That works for a rename that changes only the name. It fails for the common case
of a rename that *also* rewrites the thing being renamed. Git decides a rename by
content similarity, so a substantially reworded document falls below the threshold
and is reported as a delete plus an addition. The single file that would have
proved the rename is precisely the one that no longer pairs — and the gate demands
proof for a skill whose reach did not change by one reader.

The failure is inverted: the more thoroughly you improve something while renaming
it, the more likely the tooling treats it as brand new.

## Pattern

Rename detection over a *directory-shaped* thing should consider every file in it,
not one designated file. Any file carried from the old directory to the new one is
equally good evidence that this is the same thing under a new name — a reference
doc, a test fixture, a script.

```bash
git diff --name-status --find-renames "$BASE...HEAD" -- '*skills/*'
```

Map each `R`-status pair to the directory segment that names the thing, and dedupe.
Then consult that map from **every** path that decides newness — including the one
that handles freshly-added entry-point files, since a reworded rename arrives there
as an addition and would otherwise slip past the map entirely.

Keep whatever scoping made the original gate honest: here, inheritance is granted
per registry, so a skill *moved* from a person scope to a shared one — a path
rename that does widen reach — still faces the gate.

## Adapt notes

Extends the gate from card 0094; preserves its semantics. Adopt 0094 first.

Write the test so the fixture asserts its own premise — that the entry-point file
genuinely fails to pair — or a later change to git's similarity heuristics turns
the test green for the wrong reason:

```bash
assert_eq "A" "$(git diff --name-status --find-renames base...HEAD -- '*SKILL.md' \
    | awk '$2 ~ /new-name/ {print substr($1,1,1)}')" "fixture is honest"
```
