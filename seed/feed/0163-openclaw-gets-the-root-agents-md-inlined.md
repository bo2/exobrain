---
id: 0163
title: OpenClaw gets the root AGENTS.md inlined — the chat agent never loaded it
date: 2026-10-08
tags: [openclaw, connector, agents]
touches_invariant: false
files: [scripts/connect-agent.sh, OPENCLAW.md, knowledge/exobrain/agents.md, skills/exobrain-tests/unit/test-connect-agent.sh]
---

## Problem

The OpenClaw connector inlined the root sidecar and the deeper scopes into
`USER.md` and relied on the runtime's native pickup of the root `AGENTS.md`.
OpenClaw's sessions start in its own workspace, whose `AGENTS.md` is the
runtime's conventions file; the exobrain's root spec was never on its path, so
the chat agent ran without the global scope — the security rules included.

## Pattern

The connector copies the root `AGENTS.md` into the `USER.md` marker block
ahead of the root sidecar and the deeper scopes (`<!-- scope: root -->`), the
same way Codex's self-contained `AGENTS.override.md` carries it. The bootstrap
budget floors rise to hold the larger block (80000 / 160000 characters). The
harness asserts the root block is present and comes first.
