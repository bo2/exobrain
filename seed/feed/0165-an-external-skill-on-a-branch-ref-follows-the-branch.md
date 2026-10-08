---
id: 0165
title: An external skill declared on a branch ref follows the branch
date: 2026-10-08
tags: [skills, connector]
touches_invariant: false
files: [scripts/fetch-external-skills.sh, skills.schema.json, knowledge/exobrain/skills.md, skills/exobrain-tests/unit/test-connect-agent.sh]
---

## Problem

The fetcher recorded the declared ref and skipped a skill whose recorded ref
matched, so a skill declared on a branch was fetched once and never again:
"follow main" behaved as "pin whatever main was that day".

## Pattern

A tag or commit ref is fetched once. For a branch ref the fetcher records the
installed commit in `.source-commit`, compares it with the remote branch head
(`git ls-remote`) on every run, and re-fetches when the branch has moved; when
the remote cannot be reached, the installed copy stays. The schema says which
kind of ref pins and which follows.
