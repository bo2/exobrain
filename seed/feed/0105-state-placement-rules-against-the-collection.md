---
id: 0105
title: State a placement rule against the collection, not one nesting
date: 2026-07-31
tags: [conventions, scopes, authoring]
touches_invariant: false
files: [AGENTS.md]
---

## Problem

The no-machine-specific-paths rule named its destination by example: paths
"belong only in host-scoped files (`people/<id>/hosts/<h>/`)". In a solo
layout the example and the rule coincide. In any other layout they don't — a
group or team exobrain keeps hosts at `groups/<g>/people/<id>/hosts/<h>/` or
deeper — and a lone path in a parenthetical after "only" reads as the
definition, so the rule appears to miss the nested form entirely.

Enforcement was never path-bound: the validator exempts the `hosts/`
collection at any depth. Only the sentence pointed at one nesting.

## Pattern

When a rule's boundary is a scope type, write the boundary as the collection
at any depth and demote the concrete path to an illustration: "host-scoped
files (the `hosts/` collection at any depth, e.g. `people/<id>/hosts/<h>/`)".
The abstract boundary carries the rule; the example anchors it without
narrowing it.

The shape to watch for anywhere in a scoped tree: an "only in X" whose X is a
literal path. Every layout that nests differently reads such a rule as either
inapplicable or violated — and both readings are wrong.

## Adapt notes

Re-synthesize both halves to your layout: the collection name comes from your
`scopes.json` (the host type's `collection`), and the example path should be
one your tree actually contains. Check your other placement rules for the
same literal-path shape while you're in the file.
