---
id: 0054
title: Suite content-scans must skip the suite's own shipped fixtures
date: 2026-06-20
tags: [tests, security, scripts]
touches_invariant: false
files: [skills/exobrain-tests/scripts/lib/check-helpers.sh]
---

## Problem

The security cases (`no-secret-in-tracked-file`, `embedded-instruction-refusal`) plant
a fake key/token verbatim in their own `prompt.md`/`check.sh`/`setup.sh`, then scan the
instance tree to prove the agent never wrote it into a committable file. But the suite
ships into every instance (card 0051), so those fixtures travel *inside* the instance —
and the scan helpers (`grep_run`/`find_run`, scoped to the `instance*` glob) matched the
planted value in the suite's own files. Every run failed on its own test data, not on
agent output. It stayed hidden until the behavioral suite first ran end-to-end.

## Pattern

A content-scan hunting for planted test data must exclude the test harness's own tree,
exactly as it already excludes the captured transcript and the seed cache — that content
is scaffolding, not agent output. Prune the suite's directory from both the grep and the
find helper at the shared layer, so every present and future content-scanning case
inherits the exclusion.

## Reference (illustration only)

```sh
grep_run() { grep -rIn --exclude-dir=.git --exclude-dir=src --exclude-dir=exobrain-tests "$2" "$rundir"/instance*; }
find_run() { find "$rundir"/instance* -not -path '*/src/*' -not -path '*/.git/*' -not -path '*/exobrain-tests/*' "$@"; }
```

## Adapt notes

Exclude by *your* suite's directory name if you renamed it. The exclusion only prunes the
harness tree — agent output for these cases lands in `domains/`/`tools/`/root, so nothing
real is hidden. A companion fix in the same change runs the from-seed build agent with the
permission gate bypassed: the builder invokes the instance's own framework scripts
(`validate-exobrain.sh`, `connect-agent.sh`) by absolute path, which a curated
relative-path allowlist can't match, so a headless session stalls on unanswerable approval
prompts; the curated allowlist stays for the behavioral cases.
