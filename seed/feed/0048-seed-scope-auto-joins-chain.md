---
id: 0048
title: Make the canonical seed's seed/ a scope that auto-joins the chain
date: 2026-06-20
tags: [scopes, scripts, seed]
touches_invariant: true
files: [seed/AGENTS.md, scripts/skills-registry.sh, AGENTS.md, scripts/validate-exobrain.sh]
---

## Problem

The canonical seed's own seed-local tooling (the instance generator, the behavioral
harness) had no scope of its own, so seed-local skills/specs couldn't resolve as a
scope — and there was no clean, structural signal for *"this checkout is the seed,
not a rendered instance."* Separately, the `AGENTS.md` placement rule was *described*
as a whitelist of scope names (root/group/person/host) though the validator only
ever rejected content-tree placement.

## Pattern

Mark the seed with `seed/AGENTS.md` (the scope flag), and have the scope-chain
builder **auto-include `seed` whenever `seed/AGENTS.md` exists**. Because `seed/` is
present only in the canonical seed (never copied into a rendered instance), the seed
scope is active there — for every consumer that walks the chain (connector,
skills/owner/tools resolution, status) — and dormant everywhere else, with no
explicit connection step. Align the docs to the rule the validator actually
enforces: an `AGENTS.md` makes *any* directory a scope; it's forbidden only inside
content trees (`domains/`, `workspaces/`).

## Reference (illustration only)

In `build_scope_chain`, alongside the implicit global root:

```sh
printf '0\tglobal\n'
[[ -f "$repo_dir/seed/AGENTS.md" ]] && printf '1\tseed\n'   # seed-only; dormant in instances
```

## Adapt notes

The chain-builder change is inert in a rendered instance (no `seed/AGENTS.md`), so
adopting it is safe even though it touches scope resolution — the auto-include fires
only in the canonical seed. If your instance has no separate seed-local tooling, you
need only the doc clarification (placement is a content-tree denylist, not a
name whitelist), not the seed scope itself.
