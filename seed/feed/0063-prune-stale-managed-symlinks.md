---
id: 0063
title: Prune stale managed symlinks on relink, not just broken ones
date: 2026-06-14
tags: [connect-agent, scopes]
touches_invariant: false
files: [scripts/connect-agent.sh]
---

## Problem

`connect-agent` links per-scope specs and skills as suffixed symlinks and, on relink,
deletes only *broken* ones. When the suffix scheme changes — a scope-path rename, or a
migration of the suffix format itself (e.g. a single-segment `name.engineering` →
nested `name.teams__engineering`) — the old links still point at valid targets, so they
survive the broken-link sweep. The agent surface then holds both the old and the new
link, and the generated import file loads every scope — and registers every skill —
twice.

## Pattern

While linking, track the set of symlink basenames the current run *expects* to create.
After linking, prune any managed symlink not in that set — not just the broken ones.
Scope the prune to symlinks only, so real files (the generated import file) and
externally-fetched real directories are never swept. Steady-state relinks stay
idempotent: every current link is expected, so nothing is pruned.

## Reference (illustration only)

```sh
declare -A EXPECT=()
# while linking each scope spec / skill: EXPECT["$(basename "$dst")"]=1
for f in "$TARGET"/AGENTS.*.md "$TARGET"/skills/*; do
    [ -L "$f" ] || continue
    [ -n "${EXPECT[$(basename "$f")]:-}" ] || rm "$f"
done
```

## Adapt notes

The broken-link-only sweep carries this latent bug the moment any suffix scheme
changes, so a divergent instance has it too. No invariant is touched — this only makes
the cleanup complete. Keep the prune symlink-only: an import file, or a fetched external
skill materialized as a real directory, must not be swept.
