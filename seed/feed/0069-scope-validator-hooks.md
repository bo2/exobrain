---
id: 0069
title: Scope validator hooks — scopes extend the deterministic gate
date: 2026-07-11
tags: [validation, scopes, scripts]
touches_invariant: false
files: [scripts/validate-exobrain.sh]
---

## Problem

Card 0066 wired one scope-specific check (a private denylist scan) directly
into the shared validator, with a hardcoded path. Every further scope-local
check — a group's naming policy, a host's path rules — would mean another
hardcoded branch in the global script, and gitignored-scope checks would keep
special-casing their own file locations.

## Pattern

Scopes extend validation the way they already contribute specs, skills, and
tool overlays: by carrying a same-named hook, `<scope>/scripts/validate-exobrain.sh`.
The shared validator resolves the connected chain (leaves from the per-machine
config, plus their scope ancestors and the auto-joined seed scope — the same
chain builder the skills registry uses) and runs each scope's hook with the
checkout under validation as `$1`; a non-zero exit turns the hook's output
into violations, prefixed with the scope. Gitignored scopes exist only in the
main checkout (resolved via the shared git common dir), and a worktree carries
neither their scope flag nor their hook — so the chain is the union of both
roots' chains, and hook paths fall back to the main checkout. No config, no
registry, or no hooks → nothing runs (degrades open). The 0066 denylist scan becomes the gitignored local scope's hook,
reading a `denylist.txt` beside it — no private paths left in the shared
script.

## Adapt notes

- Supersedes the **wiring** of card 0066; the denylist *pattern* (private
  term list gating tracked content, outgoing messages, branch names) is
  unchanged — it just moves into the local scope's hook.
- Skip the scope named `global`: the global hook is the shared validator
  itself, and running it from itself recurses.
- A hook runs with the *validated checkout* as `$1`, which may differ from
  the directory the hook lives in — hooks must resolve their own data files
  relative to `$0`, not `$1` or the cwd.
- Tracked scope hooks execute on every contributor's push; they're code
  review surface like any other script in the repo.
