---
id: 0104
title: Run a renamed-artifact sweep before the generator's writes
date: 2026-07-31
tags: [connector, compat, scripts]
touches_invariant: false
files: [scripts/connect-agent.sh]
---

## Problem

A sweep that reaps a generated file's pre-rename copy (card 0096) keys on the
generated heading, so a human's same-named file survives it. That key cannot
tell a *stale* generated file from a *live* one: in a connector that still
writes the artifact under the old name — the sweep carried in without the
rename it cleans up after — the live file matches by construction.

Placed after the generator's writes, the sweep then deletes exactly what was
just written, on every relink, and the surface never heals: the generated
entry point imports a file that is gone by the time a session reads it.

## Pattern

Order the sweep **before** the writes. Where the rename is complete, the sweep
and the writes touch different names and the order changes nothing. Where it
isn't, the order converts the failure into a harmless sweep-then-regenerate:
the old-named file is removed, then written fresh, and the surface stays
healthy on every relink. The safe order costs nothing in the clean case and
self-heals the broken one.

The general shape: when a destructive cleanup and a generator share one
surface, run the cleanup first, so anything it wrongly matches is something
the generator is about to rewrite.

## Adapt notes

The ordering is a guard, not a fix: a sweep colliding with a live artifact
means the rename it serves was never completed — finish the rename (card 0103)
or drop the sweep. Keep the guard anyway; it is what makes that state
survivable instead of self-destructive.
