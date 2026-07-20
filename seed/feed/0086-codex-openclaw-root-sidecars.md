---
id: 0086
title: Ship root CODEX.md / OPENCLAW.md sidecars to match CLAUDE.md
date: 2026-07-19
tags: [agents, connect-agent, codex, openclaw]
touches_invariant: false
files: [CODEX.md, OPENCLAW.md]
---

## Problem

`connect-agent.sh` composes a per-agent root sidecar into each agent's context
surface (`CLAUDE.md` via `@`-import, `CODEX.md` into `AGENTS.override.md`,
`OPENCLAW.md` into `USER.md`), but only `CLAUDE.md` existed. Codex and OpenClaw
users had no home doc, and the connector's sidecar hook silently composed nothing
for them.

## Pattern

Ship root `CODEX.md` and `OPENCLAW.md` alongside `CLAUDE.md` — the same sections
(tooling primitives, git-history hygiene, auto-loading) written for each agent's
actual delivery mechanism. Codex reads its sidecar inlined into the natively-read
`AGENTS.override.md`; OpenClaw reads its sidecar inlined into `USER.md` between
markers; Claude reads `CLAUDE.md` natively via `@`-import.

## Adapt notes

- Describe each sidecar's delivery accurately for *your* connector — a sidecar
  inlined into a composed file is not "not injected". Verify against
  `connect-agent.sh` before stating a mechanism.
- The tooling-primitive sections are skeletons; fill them as each agent's tool
  names get documented.
