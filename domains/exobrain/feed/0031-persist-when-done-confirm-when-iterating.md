---
id: 0031
title: Persist when work is done; confirm when more edits are likely
date: 2026-06-18
tags: [git, workflow, persist]
touches_invariant: false
files: [AGENTS.md, skills/exobrain-persist/SKILL.md]
---

## Problem

Auto-persist-as-default — standing authorization to commit → push → PR → squash-merge each completed logical change without being asked — lands work the moment a logical change *looks* done. But "looks done" and "the user is finished" aren't the same. When the user is mid-iteration or about to correct the work, auto-landing each step creates churn: PRs that immediately need follow-ups, merged commits superseded minutes later, and a default-branch history of half-steps.

## Pattern

Qualify the auto-persist default with a single guard: land without being asked only when the work is genuinely finished and no further edits or corrections are expected. When more changes are likely — mid-task, or the user is still iterating — hold and confirm before landing. The standing authorization still removes the "ask every time" friction for finished work; it just doesn't fire while the work is still moving.

## Reference (illustration only)

The git-workflow rule's "auto-persist each completed logical change" gains a clause: "fire when the change is genuinely done; when more edits or a correction are likely — mid-task, or the user is still iterating — hold and confirm first." The persist skill's opening mirrors it.

## Adapt notes

No invariant touched, and this is *not* a return to "commit only when explicitly asked" — that loses the friction win for finished work. The only addition is the still-iterating guard. The signal for "more edits likely" is judgment: a correction just arrived, the user is reviewing wording, or the task is one of several in flight.
