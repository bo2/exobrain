---
id: 0078
title: A/B-grade the agent's authored output, not only its tool choice
date: 2026-07-19
tags: [skills, testing, exobrain-ab]
touches_invariant: false
files: [skills/exobrain-ab/scripts/run_one.sh, skills/exobrain-ab/scripts/run.sh, skills/exobrain-ab/scripts/tasks.example.sh, skills/exobrain-ab/SKILL.md]
---

## Problem

The behavioral A/B harness could only grade *tool choice* — which PATH-shadowed
command an agent reached for. Many context changes target the agent's *authored
text* instead: a required phrasing, a banned claim, a structural convention in
what it writes. Those were unmeasurable, so such changes shipped on intuition.

## Pattern

Make the agent's own stdout a gradable signal alongside the tool-stub log. Two
`GRADE` modes read stdout instead of the stublog: `output` (correct when a
required regex matches, else wrong when a banned regex matches) and
`output_absent` (a negative — correct when the banned regex is absent). The
per-run CSV gains an `evidence` column recording whichever stream was graded, so
a verdict stays inspectable after the fact. Tool-choice grading is unchanged and
stays the default; output modes need no stub, since the target is text, not a
command.

## Reference (illustration only)

`run_one.sh` grades on a `case "$GRADE"` switch: `no_tool` / `match` read
`$LOG` (the stublog), `output` / `output_absent` read `$OUTF` (agent stdout).
Each arm sets an `ev` string that becomes the CSV's third column.

## Adapt notes

- The task-row format is pipe-delimited, so a grading regex cannot contain `|`
  (no alternation) — use single-branch patterns.
- The discriminator constraint's "stub-gradable" clause applies only to tool
  modes; for output modes only the "change-only" clause carries over.
