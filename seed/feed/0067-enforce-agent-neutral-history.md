---
id: 0067
title: Enforce agent-neutral history at the push gate
date: 2026-07-11
tags: [validation, git, scripts]
touches_invariant: false
files: [scripts/validate-exobrain.sh]
---

## Problem

Card 0024 states the rule — no agent attribution in git history — but nothing
enforces it, and agent CLIs re-add their default footers silently: a
`Co-Authored-By: Claude …` trailer or `🤖 Generated with …` footer lands in a
squash commit and is permanent once pushed.

## Pattern

The deterministic validator scans commit messages not yet on the remote
default branch for line-anchored attribution markers
(`^Co-Authored-By: Claude`, `^🤖 Generated with`) and blocks the push on a
match. Line-anchoring keeps a rule that *quotes* the forbidden footer inline
from false-positiving. Outgoing-only scope means adopting the check never
flags history retroactively.

## Adapt notes

- An instance that deliberately keeps agent attribution should skip this card
  (it enforces card 0024; adopt them together or not at all).
- Extend the pattern list for other agents' default footers as they appear.
