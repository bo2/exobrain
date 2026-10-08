---
id: 0161
title: Working copies die with the work, and the healthcheck names stale scratch
date: 2026-10-08
tags: [security, healthcheck, raw-data]
touches_invariant: false
files: [AGENTS.md, scripts/exobrain-healthcheck.sh, knowledge/exobrain/security.md, skills/exobrain-tests/unit/test-scratch-retention.sh, skills/exobrain-tests/unit/run.sh]
---

## Problem

A working copy in `tmp/` or a `_cache/` — a database dump, a scanned identity
document, a mail export — is as exposed as the machine it sits on, and nothing
said when it should go. Months of such copies accumulated under gitignored
paths no review ever reached.

## Pattern

One clause on the existing "working copies stay local" rule: they die with the
work — deleted when the session that needed them ends. The healthcheck names
every `tmp/` entry and every `_cache/` directory under `knowledge/` and
`workspaces/` in the main checkout with no file touched in 30 days
(`EXOBRAIN_SCRATCH_DAYS`), with its age and size, capped at ten; one fresh
file clears a directory, empty directories are skipped, and it deletes nothing.
The depth is a posture bullet in `security.md`: holding less on disk is the
same posture as holding narrow credentials.
