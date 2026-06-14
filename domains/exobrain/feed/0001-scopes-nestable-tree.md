---
id: 0001
title: Scopes as an AGENTS.md-flagged nestable tree
date: 2026-06-07
tags: [scopes, identity, connect-agent]
touches_invariant: true
---

## Problem

The original scope model was a fixed four-level ladder (`global < team < person < host`) with people physically nested inside teams. A solo or family exobrain had to invent a team to hold a person — pure ceremony — and the ladder couldn't express other shapes (an org with sub-teams, a project scope, a shared household).

## Pattern

Make scopes a **tree discovered from the filesystem**, not a fixed ladder:

- **A scope is any directory containing an `AGENTS.md`** (the scope flag). The repo root is the `global` scope. No registry identifies scopes.
- **Nesting is literal directory containment.** `people/oleg/hosts/laptop/` (no group); `groups/acme/teams/ads/people/oleg/` (deep). Scope *type* is cosmetic — inferred from the parent collection dir, with optional labels in `scopes.json`.
- **Connect a leaf** (in `.exobrain.json` `connected`); wiring resolves that leaf plus every `AGENTS.md`-bearing ancestor, **deepest wins**.

A person can stand at the top level (`people/<id>/`) with no group. The ladder becomes just one possible chain shape.

## Reference (illustration only)

The whole chain algorithm is a filesystem walk:

```sh
build_scope_chain() {            # repo + AGENTS.md-bearing ancestors, depth-sorted
  echo "0	global"
  for leaf in "$@"; do
    prefix=""; depth=0
    IFS=/ read -ra segs <<< "$leaf"
    for seg in "${segs[@]}"; do
      prefix="${prefix:+$prefix/}$seg"; depth=$((depth+1))
      [ -f "$repo/$prefix/AGENTS.md" ] && printf '%s\t%s\n' "$depth" "$prefix"
    done
  done | sort -t$'\t' -k1,1n -k2,2 -u | cut -f2
}
```

## Adapt notes

**Touches the scope-resolution invariant**: the order (root/shallow → leaf/deep, deeper wins) must be preserved exactly; only the *shape* (fixed ladder → arbitrary tree) changes. Keep `off`-tier shadowing working across the now-variable-length chain. The skill-link suffix must encode the full scope path (`people__oleg`, not just `oleg`) so two scopes with the same leaf id don't collide. An organization can still nest people under teams and call them "teams" — the tree *allows* the flat layout without forcing it.
