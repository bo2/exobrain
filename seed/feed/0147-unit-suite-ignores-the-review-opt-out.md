---
id: 0147
title: The unit suite clears the authoring-review opt-out before it runs
date: 2026-09-22
tags: [tests, persist, scripts]
touches_invariant: false
files: [skills/exobrain-tests/unit/run.sh]
---

## Problem

`persist.sh` runs the unit suite itself on a machinery diff. Run with
`EXOBRAIN_SKIP_AUTHORING_REVIEW=1`, it handed that variable to the harnesses that
test the review gate, whose fake reviewer honours the opt-out — so the gate tests
failed for the one reason the caller had asked to skip.

## Pattern

`unit/run.sh` unsets the opt-out before running any harness. A caller's choice
about their own land never reaches a test of the machinery being landed.
