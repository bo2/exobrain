---
id: 0159
title: The authoring review fails closed on a land into a mount
date: 2026-10-08
tags: [authoring-review, mounts, security, persist]
touches_invariant: true
files: [scripts/authoring-review.sh, scripts/persist.sh, AGENTS.md, knowledge/exobrain/mounts.md, skills/exobrain-tests/unit/test-authoring-review.sh, skills/exobrain-tests/unit/test-mounts.sh]
---

## Problem

The authoring review degrades open: no engine, an error, a timeout, or an
empty answer exits 0 so a push is never taxed by a model round-trip. Under the
audience lens of a land into a mount, the review is the only judge of the
charter's never-topics — and a review that did not happen let the land through
exactly as a clean one would. Three smaller gaps rode with it: `AUTHORING-OK`
anywhere in the output passed, so a finding that quoted the token passed; under
a lens only markdown was reviewed, though a boundary is crossed in a CSV as
readily as in prose; and the opt-out ran before the deterministic proof gate,
waiving it.

## Pattern

The review reads the lens's first line (which `mount-isolation.py --lens`
writes) for its target. A target other than "this instance" fails closed: a
review that did not happen exits 3, says why and names the target, and persist
refuses the land with its own message rather than "flagged violations". A lens
on the instance, or no lens, keeps degrading open; every skip says why.

`AUTHORING-OK` counts only as a whole line, and a finding-shaped line beside
it still blocks. Under a lens every changed text file under `knowledge/` and
`workspaces/` is reviewed; `_raw/` stays with the deterministic gate. The
opt-out (`EXOBRAIN_SKIP_AUTHORING_REVIEW=1`) is honored after the proof gate,
and under a mount lens it says what it leaves unjudged — a person choosing to
skip is not the failure above.

## Adapt notes

Extends the validation contract. Exit 3 is new: a land caller that maps exit
codes to messages gets one for "the review did not run".
