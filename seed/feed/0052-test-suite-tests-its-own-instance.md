---
id: 0052
title: The behavioral suite tests its own instance (drop --self/--instance)
date: 2026-06-20
tags: [tests, skills]
touches_invariant: false
files: [skills/exobrain-tests/, seed/skills/seed-tests/]
---

## Problem

The universal suite took `--self` / `--instance <dir>` flags so the seed could point
it at a freshly-built instance (card 0049). But `--self` was redundant (it was the
default), and `--instance` made an instance's own test suite "know" how to be aimed
somewhere else — surface an instance shouldn't carry. An instance shouldn't know
about the seed; it should just test itself.

## Pattern

The suite **always tests the instance it is installed in** — no source flags; it
snapshots the current instance (`git archive HEAD`) into a throwaway copy and runs
the cases. The seed tests an instance the same way every instance does: it builds an
instance from the seed, **commits** it (so it's a normal committed repo — the suite
snapshots `HEAD`), then runs **that built instance's own copy** of the suite. Since
the instance ships the suite (create-instance copies it), this also exercises the
shipped artifact in situ. Refines card 0049.

## Reference (illustration only)

```sh
# seed-tests: build -> verify -> commit -> run the built instance's OWN suite
build_raw_instance "$BUILD" "$BUILDER"
git -C "$BUILD" add -A && git -C "$BUILD" commit -q -m "harness: snapshot"
exec "$BUILD/skills/exobrain-tests/scripts/run.sh" "$@"
```

## Adapt notes

The built instance must ship the suite and be committed before it self-tests (a
fresh scaffold has no commit yet — committing is part of initializing it). Drops the
`provision_from` (`cp -R`) path; one provisioner remains (`provision_self`). No
invariant changes.
