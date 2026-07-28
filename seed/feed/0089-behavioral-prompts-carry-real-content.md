---
id: 0089
title: Give a behavioral case's prompt real content so the agent does the task
date: 2026-07-28
tags: [tests, behavior]
touches_invariant: false
files: [skills/exobrain-tests/behavior/cases/validate-stays-clean/prompt.md]
---

## Problem

A behavioral case whose prompt names a task without supplying anything to do it with
("add a domain called gardening") measures the wrong thing. A well-behaved agent reads
an instruction to create durable knowledge with no knowledge attached and does what the
repo's conventions tell it to: it pushes back, or asks what should go in the file. The
run then fails on a check that was meant to test something else entirely — here, that
the validator stays clean after a structural change — and the case reads as a
regression in the behavior under test rather than a defect in its own prompt.

## Pattern

A case prompt has to make the requested action the *obviously correct* one, so that the
only thing left varying is the behavior the check measures. Two additions do it:

- **Real content.** Supply the material the task consumes — concrete facts, enough of
  them that writing the file is a sensible act rather than fabrication. An agent given
  substance produces the artifact; an agent given a bare instruction argues with it.
- **An explicit go-ahead.** End with a line that closes the confirmation loop ("go ahead
  and create it now — don't ask me to confirm"). Otherwise a case that measures a file's
  *shape* keeps failing on agents that correctly stop to ask first.

The general rule: when a case fails, check whether the prompt gave the agent a real
reason to comply before concluding the behavior regressed. A prompt that invites a
challenge tests the challenge, not the check.

## Adapt notes

- Keep the content generic and inventable — a test prompt is committed, public, and read
  by everyone; it must carry no real personal or org detail.
- This applies only to cases measuring an artifact's shape. A case deliberately testing
  *whether* the agent pushes back — a refusal or challenge case — wants exactly the
  underspecified prompt this pattern removes.
