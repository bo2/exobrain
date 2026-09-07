---
id: 0127
title: Retire the pre-override delivery shims (compat 0001–0004)
date: 2026-09-07
tags: [connect-agent, compat, codex]
touches_invariant: false
files: [scripts/connect-agent.sh, skills/exobrain-tests/unit/test-connect-agent.sh, knowledge/exobrain/compat.md, knowledge/exobrain/agents.md]
---

## Problem

Four shims in the connector healed checkouts crossing the move from home-dir
delivery to the in-repo override: Codex skill symlinks left under the home
config dir (0001), the marker block a prior connector injected into the Codex
home `AGENTS.md` (0002), generated index copies in the home config dir (0003),
and the knowledge index under its former name in `.claude/` (0004). All four
passed their removal dates; the session-start healthcheck named them every
session.

## Pattern

Retire a shim the way the ledger prescribes (card 0097): delete the code site,
the tests that covered it, and the ledger row, in one change. What existed only
because of the shim goes with it — here the `--wire-sandbox` guard for Codex,
which refused to run without `CODEX_HOME` set because the cleanups would
otherwise have touched the real home dir. With the cleanups gone, a Codex sandbox
wiring writes nowhere outside the checkout and needs no override; the OpenClaw
guard stays, since its `USER.md` is still delivered into the workspace dir.

## Adapt notes

- An instance that adopted cards 0093/0097 carries the same rows and markers;
  the validator keeps the two in sync, so removing one side without the other
  fails the push.
- Drop the codex sandbox guard only together with the shims: while any of them
  runs, the guard is what keeps `--wire-sandbox` side-effect-free.
