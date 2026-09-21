---
id: 0130
title: The sweep names a worktree that is rotting, and doesn't fail on one that is merely waiting
date: 2026-09-21
tags: [persist, scripts, automation]
touches_invariant: false
files: [scripts/persist.sh, skills/exobrain-persist/SKILL.md, skills/exobrain-tests/unit/test-persist.sh]
---

## Problem

A scheduled `--sweep` skipped a dirty worktree silently on every pass, so the
orphan of a dead session could hold uncommitted work for weeks unseen. In the
other direction, a worktree whose machinery diff awaited an agent's behavioral
verification made the sweep *fail* on every pass — an alert every few hours for
work that was legitimately waiting.

## Pattern

Separate **waiting** from **rotting**. A dirty worktree, and a machinery worktree
whose claim carries no verification assertion, are left alone and counted on
their own (`skipped`, `awaiting verification`) without failing the sweep. Either
one that has waited `PERSIST_STALE_DAYS` (default 2) is reported as `stale` with
its path and what to do, and *that* fails the sweep so the scheduled job's alert
names it. Dirty age is the newest uncommitted file's mtime; machinery age is the
last commit's.

## Adapt notes

- A claim made with `--machinery-verified` still lands from the sweep.
- The summary line's shape changed; anything parsing it needs the new counters.
