---
id: 0158
title: A land that removes a file from a mount passes the gates, and more registries count as machinery
date: 2026-10-08
tags: [mounts, persist, validation]
touches_invariant: false
files: [scripts/mount-isolation.py, scripts/persist.sh, skills/exobrain-persist/SKILL.md, skills/exobrain-tests/unit/test-mounts.sh]
---

## Problem

The isolation gate judged every changed path, so a land that deleted a
framework file or an out-of-charter domain from a mount was refused as
carrying one. The verification gate asked for a behavioral run covering every
changed spec and the author's word for every changed script, removed ones
included — and no run can cover a spec that is gone.

Separately, a mount charter, a per-scope `crons.json` or `skills.json`, and
Claude's committed `.claude/settings.json` shape what agents do, yet persist
treated them as content.

## Pattern

- The isolation gate skips a path the land removes; adding or editing one
  still blocks.
- In a worktree of a mount, a path the land removes is left out of the
  verification gate: this instance never loaded it. In the instance's own
  worktree a removal is still judged, since the sweep must not land an
  unreviewed deletion of a spec.
- `MACHINERY_RE` covers `mounts.json` and its schema, any `crons.json` or
  `skills.json` at any scope, and `.claude/settings.json`, so a change to them
  needs `--machinery-verified`.
