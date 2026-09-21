---
id: 0139
title: An owner-less skill declaration must not shift the registry's columns
date: 2026-09-21
tags: [skills, scripts, portability]
touches_invariant: false
files: [scripts/skills-validate.sh, scripts/skills-status.sh, skills/exobrain-tests/unit/test-skills-validate.sh, skills/exobrain-tests/unit/test-skills-status.sh]
---

## Problem

`IFS=$'\t' read` treats tab as whitespace, so consecutive tabs collapse and an
empty field vanishes. A skill declared without an `owner` therefore read with
every later column shifted one place left: `skills-validate.sh` never saw its
kind as in-tree and skipped the missing-`SKILL.md` check for it, and
`skills-status.sh --all` printed its tier under OWNER. The connector already
parses its tab rows by hand for this reason; these two scripts did not.

## Pattern

Never split a row that can carry an empty field with a whitespace `IFS`. Either
join with a non-whitespace separator (`\x1f`) and read on that, or let `awk -F'\t'`
do the split and hand `read` only fields that are never empty. Each script gets a
harness whose fixtures omit every optional field in turn and assert each column
lands under its own heading.
