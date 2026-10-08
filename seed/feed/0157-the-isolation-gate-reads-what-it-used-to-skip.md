---
id: 0157
title: The isolation gate reads what it used to skip — encodings, ++ lines, names
date: 2026-10-08
tags: [mounts, security, validation]
touches_invariant: true
files: [scripts/mount-isolation.py, scripts/persist.sh, knowledge/exobrain/mounts.md, skills/exobrain-tests/unit/test-mounts.sh]
---

## Problem

The isolation gate (card 0155) scanned the added lines of UTF-8 text files and
nothing else. A text file in another encoding was treated as binary and passed
whole; a UTF-16 file, which git calls binary, showed no hunks; an added line
that itself began with `++` was dropped by the `+++`-header test; and a never
term in a filename, the branch name, or the PR title landed unscanned.

## Pattern

- A NUL-free file that is not UTF-8 is a **finding**, not a skip: the gate
  cannot judge it, so the author recodes it. UTF-8 with a BOM, and BOM-marked
  or NUL-patterned UTF-16/UTF-32, are decoded and scanned — for those git
  shows no lines, so the gate diffs the decoded text against the base version
  itself. A file with other NUL bytes is binary and passes on its name alone.
- Hunk state, not a prefix test, decides what is an added line: the `+++ b/…`
  header comes before the first `@@`, an added `++` line comes inside one.
- The term and pattern scan also runs over each changed file's name, the
  branch name, and the PR title, which persist passes as `--title`.

## Adapt notes

Extends the gate; nothing it blocked before passes now. A national identifier
checksum stays out of the built-ins (locale-specific); a charter lists such
shapes under `never.patterns`.
