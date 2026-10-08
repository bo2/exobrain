---
id: 0162
title: A security findings ledger — per-scope registries, a script that owns them, and a rule to record what is noticed
date: 2026-10-08
tags: [security, registries, healthcheck, validation, behavior]
touches_invariant: false
files: [security.schema.json, scripts/security-findings.py, scripts/validate-exobrain.sh, scripts/exobrain-healthcheck.sh, AGENTS.md, knowledge/exobrain/security.md, skills/exobrain-tests/unit/test-security-findings.sh, skills/exobrain-tests/behavior/cases/security-finding-recorded, skills/exobrain-tests/behavior/cases/neg-no-finding-for-scoped-credential]
---

## Problem

An agent working on something else meets a credential scoped wider than its
use, a secret in a tracked file, a gate it could bypass — and either fixes it
silently, widening the task, or passes it by. A weakness noticed and not
written down is noticed again by the next session, or by nobody.

## Pattern

`security.json` at the repo root or in any scope directory (the gitignored
`local/` included, for findings the repository's audience may not read),
validated against `security.schema.json`: each finding carries a severity
(`high` exploitable as things stand, `medium` needs another failure first,
`low` hygiene), where it is, what it allows, the proposed fix, and who can
carry it out (`agent` or `person`); open, or `accepted` with a reason and a
review date. A fixed finding is removed — the commit is the record. A finding
never holds a secret value.

`scripts/security-findings.py` owns the registries: `add` / `accept` /
`reopen` / `close` / `reviewed` / `list`; `summary` names what needs a person
(a high finding left open, an accepted risk past its review date, a review
overdue) and exits 2 when anything does; `--check` validates every registry,
and the validator runs it. The session-start healthcheck prints the summary's
attention lines, so every instance has one channel without building any.

The rule, auto-loaded: a suspected weakness noticed in passing is recorded,
then the task carries on and the reply names it. Two behavior cases prove it
is read: the over-broad credential is recorded, the correctly scoped one is
not.

## Adapt notes

The posture and the ledger's mechanics are `knowledge/exobrain/security.md`;
what a review of an instance walks is that instance's own list.
