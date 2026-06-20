---
id: 0043
title: Document that any scope is connectable, not only person/host
date: 2026-06-19
tags: [scopes, docs]
touches_invariant: false
files: [AGENTS.md, domains/exobrain/scopes.md]
---

## Problem

The specs framed connection as a single person/host leaf plus its ancestors — one
fixed ladder. But the resolver already supports more: `connected` is a *list*, and
the scope chain is the **union** of each connected leaf's ancestor chain, where a
leaf is *any* `AGENTS.md`-bearing directory. Agents reasoning from the specs
wrongly concluded that a sibling or standalone scope (not a person/host, not on the
person/host branch) couldn't be connected — when in fact it can, joining resolution
at its own depth with deepest-wins intact.

## Pattern

State the capability where the specs describe connection: a connected leaf can be
**any** scope, not only a person/host pinpoint scope or one on a single branch.
Because per-leaf chains are unioned, several leaves on different branches — and a
standalone top-level scope — can be connected together. Note the ergonomics gap so
it isn't mistaken for unsupported: the setup wizard auto-derives only the
person/host leaves; any other scope is added to the connected list directly, and
the resolver honors any leaf with an `AGENTS.md`.

## Reference (illustration only)

In the depth doc, after the chain-union algorithm:

> A connected leaf can be **any** scope — any `AGENTS.md`-bearing dir — not only a
> person/host pinpoint scope or one on a single branch. Because chains are unioned,
> you may list several leaves on different branches and even a standalone top-level
> scope alongside your person/host chain; each joins resolution at its own depth,
> deepest still winning.

## Adapt notes

Pure documentation of existing scope-resolution behavior — changes no semantics.
If your instance renamed the connection key or the collection vocabulary, keep the
wording aligned with your names; the durable idea is "leaves are unioned; any
`AGENTS.md` dir is a valid leaf."
