---
id: 0047
title: Separate instance scaffolding from connection
date: 2026-06-20
tags: [scopes, scripts, bootstrap]
touches_invariant: false
files: [seed/skills/create-instance/SKILL.md]
---

## Problem

The instance scaffolder both built the instance *and* wrote `.exobrain.json`
itself, then ran the connector to read it back. Two writers of connection state,
and the scaffolder duplicated identity logic to dodge the connector's interactive
wizard (which assumes a human TTY — absent when an agent runs the scaffold).

## Pattern

Give the scaffolder one job: create content (scope dirs with meaningful stubs,
domains, README). It does **not** write `.exobrain.json`. Its final step calls the
connector with explicit identity flags (`--handle`/`--host`), which establishes the
connection non-interactively — name-matching the scopes the scaffold just created —
and is the sole writer of connection state. One source of truth, no TTY needed, no
duplicated logic.

## Reference (illustration only)

The scaffolder's verify/connect step:

```bash
scripts/validate-exobrain.sh                                          # must be clean
scripts/connect-agent.sh <agent> --handle <handle> --host <machine>   # connects + writes config
```

## Adapt notes

Requires the connector to accept flag-driven, non-interactive identity (see the
name-match + flags card). The scaffolder still creates the person/host scope dirs
(richer stubs survive — the connector's scaffolding is idempotent and won't
overwrite an existing `AGENTS.md`). A separate, config-less clone on a new machine
still connects interactively (no flags) — the wizard name-matches the committed
scopes. No invariant changes.
