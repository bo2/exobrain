---
id: 0172
title: The A/B runner gives a sandboxed claude run no MCP servers
date: 2026-10-08
tags: [ab, security, scripts]
touches_invariant: true
files: [skills/exobrain-ab/scripts/run_one.sh, skills/exobrain-ab/SKILL.md]
---

## Problem

`exobrain-ab` runs each sandboxed claude arm with `--permission-mode
bypassPermissions` and no MCP restriction, so the run loads the runner's own
MCP servers — plugins, hosted connectors — with live credentials. The `PATH`
stubs catch bare commands only; an agent reaching for an MCP tool acts on a
real system, ungraded. One such run commented on a real ticket and closed it.

## Pattern

Pass `--strict-mcp-config --mcp-config '{"mcpServers":{}}'` on every sandboxed
claude run, as the behavior suite's security profiles already do, and say so
in the skill beside the sandbox-scope rules. Containment of a bypassed-permissions
agent is only as complete as the set of channels it shadows; MCP is a channel
the shell stubs cannot see.

## Adapt notes

Extends the containment the skill promises; nothing it allowed before is
needed. Codex arms stay isolated by a sandbox-local `CODEX_HOME`.
