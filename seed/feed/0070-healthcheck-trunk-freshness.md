---
id: 0070
title: Trunk-freshness advisory in the session-start healthcheck
date: 2026-07-12
tags: [healthcheck, git, scripts]
touches_invariant: false
files: [scripts/exobrain-healthcheck.sh]
---

## Problem

The session-start healthcheck verifies connection and link integrity but not
whether the main checkout's trunk is behind its upstream, so an agent (or
human) starts work on a stale trunk without notice — and worktree-first
branching then forks off outdated history.

## Pattern

An inform-only freshness check in the healthcheck: when the main checkout is
behind its upstream, print an advisory suggesting `git pull --ff-only` — never
pull (session start stays read-only; pulling is the human's move, and a pull
also fires the relink hook). Two guards keep startup fast on a bad network:
the `git fetch` is throttled (skipped when `FETCH_HEAD` is younger than 5
minutes) and bounded by a watchdog that kills it after 6 seconds, so a slow or
absent network degrades to silence instead of blocking the session. The
behind-count still computes from the last known remote state even when the
fetch was skipped or killed.

## Adapt notes

- Keep the check advisory and the script's always-exit-0 contract — a
  session-start hook that can fail blocks sessions.
- `stat -f %m || stat -c %Y` covers both BSD/macOS and GNU for the
  `FETCH_HEAD` age.
- Resolve the main checkout via the shared git common dir so the advisory is
  correct from inside a worktree.
