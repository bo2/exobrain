---
id: 0152
title: The A/B runner creates the sandbox Codex home before linking auth into it
date: 2026-10-01
tags: [ab, codex, scripts]
touches_invariant: false
files: [skills/exobrain-ab/scripts/run.sh]
---

## Problem

`exobrain-ab`'s codex arm wires each sandbox with `CODEX_HOME` pointed inside it,
then links the machine's Codex `auth.json` into that directory. The connector
writes Codex's surface into the checkout and neither creates nor cleans a Codex
home, so the directory does not exist: the `ln` fails, nothing checks it, and
every codex run starts unauthenticated.

## Pattern

The runner owns the sandbox home it points the agent at, so it creates it
(`mkdir -p`) before linking the credential in. A harness that redirects an
agent's home creates that home itself rather than relying on the wiring step to
leave one behind.
