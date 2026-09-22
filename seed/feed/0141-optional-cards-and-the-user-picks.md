---
id: 0141
title: Triage new cards into four categories and ask once per category
date: 2026-09-22
tags: [propagation, evolve, feed]
touches_invariant: false
files: [skills/exobrain-evolve/SKILL.md, knowledge/exobrain/propagation.md]
---

## Problem

`exobrain-evolve` was permissive by default and *let* the user veto — a phrasing an
agent reads as "apply unless told otherwise", so a run could land every new card
without a pick ever being made. Asking per card is the opposite failure: an
instance that falls thirty cards behind faces thirty questions. And every card
carried the same weight: the feed had no way to ship a pattern some instances want
and others deliberately don't (a hook that rewrites commit messages, for one)
without recommending it to all.

## Pattern

Triage sorts, then asks once per category. The agent reads each new card against
the instance and files it as **mandatory** (`touches_invariant: true`, a fix to a
framework file the instance carries, or a dependency of a later card),
**recommended** (the seed's default), **optional** (`optional: true` in the
frontmatter — the seed offers it without recommending, and its Problem says whose
preference it serves — or a preference here), or **probably not needed** (a scope
type, tool, or agent this instance lacks). One question covers the run: for each
category, apply automatically, confirm card by card, or skip — proposed as
apply / apply / confirm / skip. Nothing is applied before that answer; a
confirm-by-card category is then walked one pick at a time.

The ledger records every decided card, adopted *or declined* (with the reason or
the category it was skipped under), so a settled card is not asked again; a card
set aside without a decision gets no row and returns next run.

## Adapt notes

The frontmatter key is read by the agent, not a script — an instance's copy of the
evolve skill needs only the triage and record wording. The feed's README (in the
seed) defines the flag.
