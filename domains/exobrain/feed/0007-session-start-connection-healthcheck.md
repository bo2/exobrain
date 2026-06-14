---
id: 0007
title: Session-start connection healthcheck + relink-safety rule
date: 2026-06-13
tags: [scripts, agents-md, claude, hooks, connect-agent]
touches_invariant: false
files: [scripts/exobrain-healthcheck.sh, .claude/settings.json, AGENTS.md]
---

## Problem

An agent can run for a whole session in a checkout where exobrain was never
connected, or where a `skills.json`/scope change left the generated links stale —
and silently miss its scoped context. Nothing surfaced the gap, and the fix
(`connect-agent.sh`) writes outside the tracked tree, so the agent shouldn't run
it unprompted.

## Pattern

A read-only, advisory healthcheck the session can run at start. It resolves the
**main checkout** from a worktree (via the shared git dir), reports two failure
modes — not connected, and stale/dangling links — and *suggests* the exact
`connect-agent.sh <agent>` / `--relink` command without ever running it. It always
exits 0, so it's safe to wire into a session-start hook where a non-zero exit
would block the session. Pair it with an AGENTS.md rule: **relay** the warning and
let the human run the fix; `connect-agent.sh` writes outside the tracked tree
(git hooks; per-agent config under `~`), so it runs only on explicit request.

## Reference (illustration only)

`scripts/exobrain-healthcheck.sh` plus a committed `.claude/settings.json` with a
`SessionStart` hook calling it. The script keys connection on the generated proof
each connector leaves (`.claude/CLAUDE.md`, `.codex`, `.openclaw`) — distinct from
the committed settings file present in every checkout.

## Adapt notes

No invariant touched — it's read-only and human-driven (preserves the
"relink is human-driven" posture). The `SessionStart` hook is Claude-specific;
Codex/OpenClaw run the script manually. Keep the committed `settings.json`
(shared hook) separate from the gitignored `settings.local.json` the connector
writes per machine — and make sure `.gitignore` exempts the committed one
(`.claude/*` + `!.claude/settings.json`). The script's `connected()` cases must
match the marker files your `connect-agent.sh` actually produces.
