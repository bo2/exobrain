---
id: 0168
title: Tool clients write .env through one atomic, locked module
date: 2026-10-08
tags: [tools, security, scripts]
touches_invariant: false
files: [scripts/envfile.py, tools/README.md, .gitignore, skills/exobrain-tests/unit/test-envfile.sh, skills/exobrain-tests/unit/run.sh]
---

## Problem

A tool client that rotates a token rewrites `.env` in place: a kill mid-write
leaves it truncated, two clients rotating at once lose each other's line, and
in a worktree — where `.env` is a symlink to the main checkout's — writing
through the link path swaps the link for a plain file and leaves the main
checkout's token stale. Each client carried its own copy of the same
`load_env`/`save_env`.

## Pattern

`scripts/envfile.py`, stdlib only, imported as a sibling by any script under
`scripts/`: `load()` returns the `KEY=VALUE` pairs; `save(key, value)` takes
an exclusive lock on `.env.lock` beside the real file, re-reads under it,
writes a temporary file beside it (same mode, fsynced) and `os.replace()`s it
over `.env`. Other lines, comments and order are kept; a symlinked `.env` is
resolved to the real file first; nothing prints a value. `.env.lock` is
gitignored. The harness covers the replace, the lock under concurrent writers,
and the symlink.
