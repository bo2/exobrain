---
id: 0106
title: Keep connector writes out of user-global agent config
date: 2026-08-04
tags: [connect-agent, codex, agents]
touches_invariant: false
files: [scripts/connect-agent.sh, CODEX.md, skills/exobrain-tests/unit/test-connect-agent.sh]
---

## Problem

Card 0002 had the connector disable each agent's native memory so the exobrain
stays the single context source. For Codex that meant appending
`use_memories = false` to the **user-level** `~/.codex/config.toml` — a write
whose blast radius is every repo the agent touches, made by a tool whose job is
wiring one repo. Codex's memory is off by default, so the write defends against
nothing until the human explicitly opts in — and then it argues with them.

## Pattern

**A connector's writes stay scoped to the repo it wires and the agent's per-repo
surface.** User-global config belongs to the human; a repo-scoped tool doesn't
reach into it, even idempotently and even for a defensible setting. If an agent's
native feature conflicts with the exobrain model, disable it where the setting can
live per-repo (Claude Code's `autoMemoryEnabled: false` lands in the checkout's
gitignored `.claude/settings.local.json`, so it stays); where the agent only
offers a user-global switch, leave the default alone and let the human flip it.

This supersedes the Codex branch of card 0002; the Claude branch stands.

## Reference (illustration only)

Remove the `config.toml` append from the connector's codex arm. Nothing replaces
it: memory off is Codex's shipped default.

## Adapt notes

- Sweep what asserted or documented the write: the render-only guard's message
  (the codex arm survives only for the legacy home-dir cleanup shims), the agent
  sidecar's "what lands under ~/.codex" note, and any test asserting
  `config.toml` appears in `CODEX_HOME`.
- If your instance adopted card 0002 and the connector wrote the line, deleting
  it from `~/.codex/config.toml` is the human's call — the connector doesn't
  clean it up either.
