---
id: 0084
title: Workspace working habits — make one for non-trivial work, default to saving
date: 2026-07-19
tags: [agents-md, workspaces, workflow]
touches_invariant: false
files: [AGENTS.md]
---

## Problem

The spec defined what a workspace is but not the *habits* around it, so
non-trivial work (scripts, queries, analysis) piled up loose in the repo or in
scratch dirs, and useful session output got discarded because saving was never the
default.

## Pattern

State two defaults in the always-loaded spec: create a workspace for any
non-trivial work session and keep its artifacts there; and default to saving the
workspace at session end unless it's clearly throwaway — institutional memory is
cheap, redoing lost work is expensive.

## Adapt notes

- Keep it to the two habits; the "what a workspace is", tmp/-for-scratch, and
  promote-don't-link rules already live elsewhere in the spec — don't restate them.
