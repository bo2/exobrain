---
id: 0132
title: Fail validation when a changed shell script does not parse or changed Python does not compile
date: 2026-09-21
tags: [validation, scripts]
touches_invariant: true
files: [scripts/validate-exobrain.sh, skills/exobrain-tests/unit/test-script-syntax.sh]
---

## Problem

A script with a syntax error fails only when something runs it — for a rarely-run
script, a hook, or a test stub, long after the change that broke it landed.

## Pattern

Two diff-scoped gates in the deterministic validator: `bash -n` over each changed
shell script, and one `python3` process that `compile()`s every changed Python
file (no bytecode written; also catches what a bare parse lets through). A file
is recognised by extension **or shebang**, so an extensionless command stub is
covered, and a file whose shebang names another shell is left alone rather than
misjudged. `_raw/` and `tmp/` are exempt; without `python3` the Python gate
degrades open.

## Adapt notes

- Extends the validation contract (additive). Diff-scoping is what keeps a
  process-per-file check off the whole tree.
- Python compiles under the machine's own `python3`: syntax newer than that fails
  here, as the script would when run here.
