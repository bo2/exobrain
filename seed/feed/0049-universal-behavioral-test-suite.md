---
id: 0049
title: Ship the behavioral test suite as a universal, instance-portable skill
date: 2026-06-20
tags: [tests, skills, scripts]
touches_invariant: false
files: [skills/exobrain-tests/]
---

## Problem

The behavioral harness was seed-local and could build its test instance only by
running `create-instance` from the seed. So it couldn't test a real, already-built
instance, and a deployed instance couldn't self-test its own agent behavior after
an edit or a seed adoption.

## Pattern

Package the suite as a **global skill** (`exobrain-tests`) — it ships into every
instance — with a generic provisioner that knows nothing about the seed:

- `--self` (default): copy the current repo at HEAD via `git archive` (tracked
  files only, no `.git`/`src`/`tmp` bloat) into a throwaway template.
- `--instance <dir>`: copy an already-built instance (e.g. one a seed-only wrapper
  built from the seed).

The template is then validated, committed onto a `main` base branch, hook-
neutralized, and refused if it has a github origin. Cases **self-seed their
fixtures** (each `setup.sh` scaffolds the scopes/domains it needs), so they're
portable to any instance. The from-seed build moves out to a seed-only wrapper that
just builds an instance and runs this suite with `--instance`.

## Reference (illustration only)

```sh
provision_self() { git -C "$REPO_DIR" archive HEAD | tar -x -C "$1"; }
# then: git init (archive has no .git), validate, commit on main, hooks off, no-origin check
```

## Adapt notes

Cases must not assume seed-specific structure — seed fixtures in `setup.sh`. The
suite consumes real agent usage (one session per case-run) and must never run
automatically; it's invoked explicitly. Keep the LLM-judge on a single agent for
consistent verdicts.
