---
id: 0083
title: exobrain-evolve — verify an "already present" verdict, don't assume it
date: 2026-07-19
tags: [skills, exobrain-evolve, propagation]
touches_invariant: false
files: [skills/exobrain-evolve/SKILL.md]
---

## Problem

Adopting a seed card, it's tempting to wave one through as "already present" on a
partial concept match and move on. If the instance's version actually contradicts
the card's specifics, that isn't adoption — it's a latent bug flying an adopted
flag, and it survives because nobody read the files.

## Pattern

Make "already present" a verdict that must be earned: read the files the card
`touches` and confirm none contradicts it (check specifics plus the card's Adapt
notes), and treat a contradiction as a fix-and-rewire, not a skip. In the ledger,
an "already-present" row must cite the concrete artifact it was checked against; a
vague citation signals a shallow check.

## Adapt notes

- Applies to any instance running exobrain-evolve; makes no structural assumptions.
