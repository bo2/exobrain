---
id: 0085
title: Healthcheck scans Codex skills where they actually live (.agents/skills)
date: 2026-07-19
tags: [scripts, healthcheck, codex]
touches_invariant: false
files: [scripts/exobrain-healthcheck.sh]
---

## Problem

The session-start healthcheck's stale-link scan looked for dangling skill symlinks
under `<target_dir>/skills` for every agent. Codex, though, links its skills into
the repo-local `.agents/skills`, not `~/.codex/skills` — so stale Codex skill links
were never detected and the "relink" advisory never fired for them.

## Pattern

Split "where skills live" from "where sidecars live". A `skills_dir()` helper
returns the repo-local `.agents/skills` for Codex and `<target_dir>/skills` for the
others; the stale-link scan uses it. `target_dir()` still governs sidecar/link
placement.

## Adapt notes

- Mirror your connector: `skills_dir` must point wherever `connect-agent.sh`
  actually links each agent's skills.
