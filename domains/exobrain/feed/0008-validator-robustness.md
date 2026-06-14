---
id: 0008
title: Validator robustness — prune big dirs in find; degrade when unconfigured
date: 2026-06-13
tags: [scripts, validation, performance]
touches_invariant: false
files: [scripts/validate-exobrain.sh, scripts/skills-validate.sh]
---

## Problem

Two ways the validators misbehaved on real checkouts. First, every `find` filtered
with `-not -path`, which still *descends* into the excluded tree — so a large
clone dir or worktree under the repo made the validator (and the pre-push hook
that runs it) take minutes. Second, `skills-validate.sh` reads the gitignored
`.exobrain.json` for per-user scope resolution; a fresh clone, a hand-made
worktree, or CI has none — and a validator must not block a push over absent local
state.

## Pattern

- **Prune, don't filter.** A single `find_repo` helper that `-prune`s the
  clone/generated/vendor dirs (`.git`, `.claude`, `src`/`.src`, worktree and
  agent-runtime dirs, `node_modules`, `tmp`, `__pycache__`) so `find` never walks
  into them, then applies the caller's match expression. DRYs the repeated exclude
  chains into one place and turns a minutes-long walk sub-second.
- **Degrade, don't fail.** When `.exobrain.json` is absent, skip only the
  per-user scope resolution and still run the registry-integrity and orphan
  checks, printing one explanatory note to stderr.

## Reference (illustration only)

The `find_repo()` helper at the top of `scripts/validate-exobrain.sh`, replacing
each `find … -not -path …` call site; and the `else` branch on the
`.exobrain.json` existence check in `scripts/skills-validate.sh`.

## Adapt notes

No invariant weakened — the **validation contract is preserved**: convert
traversal only, keeping every rule body at each call site; the degrade path drops
no check, it skips an input that isn't there. Match the prune list to your own
gitignored/generated dirs. (If you adopt the per-tool-doc tools model in card
0006, the tools.json validator branch is gone independently of this change.)
