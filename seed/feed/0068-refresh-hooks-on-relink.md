---
id: 0068
title: Refresh git hooks on every relink
date: 2026-07-11
tags: [connector, hooks, scripts]
touches_invariant: false
files: [scripts/connect-agent.sh]
---

## Problem

The connector generates git hooks from inline templates but installed them
only on first connect. When a template evolves — a gate added to or removed
from `pre-push` — every already-connected checkout keeps executing the stale
hook forever, silently diverging from the documented gate set. The docs
already promised "refreshed idempotently on every relink"; the code didn't.

## Pattern

Run the (idempotent) hook installation on every connect *and* relink, keeping
only true first-run side effects (the connect marker) behind the first-run
guard. Because the post-merge hook itself triggers a relink, hook-template
fixes then propagate to every connected checkout automatically on its next
`git pull`. Write each hook tmp-then-`mv` so a running hook may safely rewrite
its own file (the rename swaps the inode; the executing shell keeps reading
the old one).

## Adapt notes

- Keep non-idempotent or user-visible first-run actions (markers, config
  writes, prompts) out of the every-run path; only deterministic template
  writes belong there.
- If a checkout intentionally carries a hand-edited hook, this pattern
  overwrites it on the next pull — hand edits belong in the template.
