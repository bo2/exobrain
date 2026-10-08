---
id: 0167
title: A behavior case can bring its own environment and permission mode
date: 2026-10-08
tags: [behavior, tests, security]
touches_invariant: false
files: [skills/exobrain-tests/behavior/run.sh, skills/exobrain-tests/behavior/lib/invoke.sh, skills/exobrain-tests/SKILL.md, skills/exobrain-tests/unit/test-behavior-runner.sh]
---

## Problem

A case that tests a scheduled job — one that reads mail, writes a brief, calls
a chat CLI — needs a fake of that tool on the agent's `PATH` and often a
permission mode the suite's default (`acceptEdits`) does not grant, since the
job runs scripts by paths no allowlist matches. The suite had one `PATH` and
one mode for every case.

## Pattern

- **`env.sh`** in the case directory is sourced in the engine's subshell after
  the security profiles' stub `PATH`, with `CASE_DIR`, `INSTANCE_DIR` and
  `RUN_DIR` exported: the place a case prepends its own fakes and points
  scripts at the run dir. What it exports reaches only that engine.
- **`permission_mode`** in `meta.json` overrides the mode for that case —
  honored only under a security profile, where the stubs and the MCP lockdown
  hold whatever the agent may run; elsewhere it is a harness error.
- Under codex a security profile also sets `allow_login_shell=false`: a login
  shell re-runs the profile, rebuilds `PATH`, and puts the real binaries back
  ahead of the stubs.

## Adapt notes

`bypassPermissions` is for a case whose fakes shadow every real tool the job
can reach and whose fixture values are all canaries.
