---
id: 0173
title: A/B grader errors fail the run instead of reading as a null result
date: 2026-10-26
tags: [ab, scripts, tests]
touches_invariant: false
files: [skills/exobrain-ab/scripts/run_one.sh, skills/exobrain-ab/scripts/run.sh, skills/exobrain-ab/scripts/tasks.example.sh, skills/exobrain-tests/unit/test-exobrain-ab.sh]
---

## Problem

Two ways of miswriting a task's grader make both arms of an `exobrain-ab` run
score zero, which reads as "the change moved nothing" when the truth is "nothing
was graded":

- A `correct_re` or `wrong_re` that begins with `-` (a flag the agent should
  pass, say) is handed to `grep` bare, so grep parses it as an option, exits 2,
  and no run ever grades `correct` or `wrong`.
- A `|` inside any field — alternation is the natural regex to write — splits
  the pipe-delimited row: the regex is truncated and its tail is prepended to the
  prompt. The seed's own task template carried two such rows.

Neither error announces itself; the summary looks like a clean A/A.

## Pattern

A grading-configuration error fails loudly, before the first agent run. Every
pattern reaches `grep` as an operand (`-e`), so a dash-leading pattern is a
pattern. The runner refuses a tasks file whose row is not exactly six fields and
names the row and its count, before any sandbox is built. A unit harness runs the
grader against a fake agent and pins both.

## Adapt notes

A runner that changed the row format checks its own field count; what carries
over is that the check runs before anything is spent and names the row. A task
that needs alternation uses a character class (`^tool +[^l]` for "a subcommand
other than list") or a second task.
