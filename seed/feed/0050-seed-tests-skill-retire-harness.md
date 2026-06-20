---
id: 0050
title: Seed-only seed-tests skill; retire the seed-local test harness
date: 2026-06-20
tags: [tests, skills, seed]
touches_invariant: false
files: [seed/skills/seed-tests/, seed/skills.json, seed/README.md, domains/exobrain/machinery.md]
---

## Problem

After the universal behavioral suite became a global skill, the seed still needed a
home for the parts that *are* seed-specific: the from-seed bootstrap test (does
`create-instance` produce a valid instance?) and the deterministic connector/
registry harness. They were sitting in a bare `seed/tests/` directory, outside the
skill and scope model.

## Pattern

Package them as a **seed-scoped skill** (`seed-tests`), declared in `seed/skills.json`
and owned by the seed scope — so it resolves only in the seed (where the seed scope
is active) and never ships into an instance. Its runner builds an instance from the
seed via `create-instance` (a builder agent), runs the `create-valid` static
bootstrap checks, then **delegates the behavioral cases** to the universal suite with
`exobrain-tests --instance <built>`. The deterministic connector harness moves in
beside it (its paths point at `<repo>/scripts/`). Retire the old `seed/tests/`.

## Reference (illustration only)

```sh
build_raw_instance "$BUILD" "$BUILDER"                 # clone seed + create-instance via agent
bash cases/create-valid/check.sh "$BUILD"             # static bootstrap verification
exec "$ETESTS/run.sh" --instance "$BUILD" "$@"        # behavioral suite against the build
```

## Adapt notes

`seed-tests` is seed-only by construction — it lives under `seed/` and is declared in
`seed/skills.json`, so it resolves only where the seed scope joins the chain.
`create-instance` stays *outside* the registry (it bootstraps from an empty dir before
any registry exists). If your instance has no seed-local tooling, you need neither
skill — only the global `exobrain-tests`.
