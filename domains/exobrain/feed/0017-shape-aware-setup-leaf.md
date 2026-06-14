---
id: 0017
title: Derive the setup leaf from the scope tree, not a hardcoded shape
date: 2026-06-14
tags: [connect-agent, scopes, setup]
touches_invariant: false
files: [scripts/connect-agent.sh, scripts/skills-registry.sh]
---

## Problem

Once the resolver is general — a scope is any dir with an `AGENTS.md`, discovered along
any leaf path — the setup wizard can lag behind it, still emitting one fixed nesting
(e.g. group → person → host). It then can't connect a shape the engine already supports,
like a group-less person leaf: a person directly at the root, or under a different
container scope.

## Pattern

Derive the connectable leaf from the repo's actual structure plus the user's choice,
treating the scope *vocabulary* as data:

- Treat the per-user and per-machine scope types as **pinpoints** — their leaf ids are
  known real values (the handle, the hostname) — so they place automatically.
- **Discover** any existing person-scope dir for the user anywhere in the tree and offer
  to connect it (plus its host level).
- When none exists, offer the real shape choices the tree allows (top-level, or nested
  under each existing container scope), built from the collection vocabulary in
  `scopes.json` rather than a literal path.
- The non-interactive auto-detect path shares the same discovery, and writes nothing.

Leave the resolver untouched; only the setup UX learns the shapes.

## Reference (illustration only)

Two small `scopes.json`-backed helpers carry the vocabulary: one maps a scope *type* to
its collection dir (the inverse of the type-label lookup), another lists the collections
that can *contain* a person (every collection except the person/host pinpoints). A third
helper finds existing `…/<people-collection>/<handle>` dirs across the tree. The wizard
builds its menu from those.

## Adapt notes

The pinpoint idea is the portable core: whichever scope types key off real-world
identifiers can be auto-placed; the rest are user choices over discovered structure.
Preserve the scope-resolution invariant — discovery feeds the same shallow→deep chain,
it does not change how resolution works.
