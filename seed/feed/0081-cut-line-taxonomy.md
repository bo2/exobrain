---
id: 0081
title: Cut-on-sight / survives-the-cut taxonomy for the domain transcription rule
date: 2026-07-19
tags: [authoring, domains]
touches_invariant: false
files: [domains/exobrain/authoring.md]
---

## Problem

The "don't transcribe what the source already holds" rule stated the litmus and a
self-check but left the two hardest calls implicit: exactly which content to cut,
and exactly which content earns its place. Authors erred toward keeping
code-discoverable transcription because the "keep" side was never enumerated.

## Pattern

Turn the transcription rule into two explicit lists under a named **cut line**:

- **Cut on sight** — file:line citations, function-body / struct / JSON
  transcriptions, class- or function-by-function walks, enum or config-key
  listings, hardcoded tuning constants.
- **Survives the cut** — design rationale, cross-system invariants, gotchas the
  code mis-signals, operational patterns, migration scars still in the code.

Keep the one-grep litmus and the self-check; note that the deterministic
validator enforces the file:line half. Separately, extend the
order-of-magnitude rule to name point-in-time business/product metrics (revenue
share, fill rate, headcount, partner count) as the same drift anti-pattern as a
tuning constant.

## Adapt notes

- The "survives the cut" list is the higher-value half — it tells an author what a
  profile is *for*, not just what to delete.
- Keep it integrated with the existing transcription section; a separate section
  duplicates the litmus and drifts.
