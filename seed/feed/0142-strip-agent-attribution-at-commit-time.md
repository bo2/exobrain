---
id: 0142
title: Strip agent attribution from commits with a commit-msg hook
date: 2026-09-22
tags: [git, hooks, scripts, validation]
touches_invariant: false
optional: true
files: [scripts/strip-agent-attribution.sh, scripts/connect-agent.sh, scripts/validate-exobrain.sh, .claude/settings.json, CLAUDE.md, skills/exobrain-tests/unit/test-agent-attribution.sh, skills/exobrain-tests/unit/test-connect-agent.sh, skills/exobrain-tests/unit/run.sh, knowledge/exobrain/machinery.md]
---

## Problem

For an instance that keeps its history agent-neutral (cards 0024 and 0067), the
spec rule alone does not hold: an agent told by its harness to append a
`Co-Authored-By` trailer sometimes does, and an unattended land then fails the
validator on every sweep until someone amends the commit by hand.

**Optional** because it is a preference: an instance that wants its agents named
in history keeps attribution and skips this card. Declining leaves the spec rule
and the validator check as they are.

## Pattern

Remove the attribution deterministically, at the source and at commit time, and
keep the validator as the backstop:

- `scripts/strip-agent-attribution.sh <message-file>` deletes `Co-Authored-By`
  trailers naming an agent and "Generated with <agent>" footers, line-anchored and
  case-insensitive, so prose about the rule and a human co-author stay. It never
  blocks a commit.
- `connect-agent.sh` installs a `commit-msg` hook that runs it.
- `.claude/settings.json` sets Claude Code's `attribution` (commit and PR) to
  empty, so the harness stops asking for the trailer and the PR footer.
- The validator's agent-attribution check keeps the same pattern (the unit suite
  pins the two copies equal) and catches a commit that bypassed the hook.

## Adapt notes

The hook runs the script only when it exists and is executable, so a checkout
without the script commits as before. The pattern names `claude|codex|openclaw`;
extend it for another agent. Existing checkouts get the hook at their next relink.
