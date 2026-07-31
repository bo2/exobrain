---
id: 0101
title: Catch rationale echo and session echo in the authoring gate
date: 2026-07-31
tags: [authoring, specs, validation]
touches_invariant: false
files: [AGENTS.md, scripts/authoring-review.sh]
---

## Problem

Agents writing docs reliably produce two flaws that generic authoring rules miss.
**Rationale echo**: when a change has a reason, the agent attaches that reason to
*every* mention of the changed thing — each site reads as legitimate context in
isolation, so a reviewer (human or model) told to be conservative passes all of
them, and the same justification lands three or four times across the diff.
**Session echo**: the prose answers a question only the conversation behind the
change asked — it reads as a reply to the session, not as present-tense truth to a
cold reader.

Rules against change-narrative ("in May we…") don't catch either: rationale echo
is present-tense and per-site plausible, and session echo needs the reviewer to
ask *what question is this sentence answering* rather than scan for tense markers.

## Pattern

Name both shapes at the two layers that shape writing:

- **The always-loaded reader-lens rule** — one sentence each, so the flaw is less
  likely to be written at all: a why is stated once, where the thing is defined;
  every other mention states only the fact. A cold reader gets the present rule,
  not the story.
- **The authoring review rubric** — an explicit check with the cross-file
  instruction, since per-file reading is exactly how rationale echo survives:
  flag the same justification attached to a thing at more than one mention site
  *across the diff*, with the fix "state the fact, drop the rationale"; flag
  added prose that presumes the change's backstory.

## Adapt notes

- The cross-file clause is the load-bearing part of the rubric check — a reviewer
  that judges each file alone will keep passing rationale echo.
- Keep the definition-site exception explicit: the why *does* belong somewhere,
  usually the concept doc that owns the thing. The flaw is repetition, not
  rationale itself.
- Commit messages are the one place change-rationale is at home; the rule targets
  specs, docs, and skills — artifacts a cold reader meets as present truth.
