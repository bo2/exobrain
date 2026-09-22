---
id: 0143
title: An unattended land posts its authoring findings as a PR review
date: 2026-09-22
tags: [persist, authoring-review, scripts]
touches_invariant: false
files: [scripts/persist.sh, skills/exobrain-repair-findings/scripts/findings-pending.sh, skills/exobrain-repair-findings/SKILL.md, skills/exobrain-repair-findings/tests/test-findings-pending.sh, skills/exobrain-persist/SKILL.md, knowledge/exobrain/landing.md, knowledge/exobrain/machinery.md, skills/exobrain-tests/unit/test-persist.sh]
---

## Problem

A detached or swept land wrote the authoring review's findings into the PR body
(card 0129). The body is the change's own record — commits plus the session's
handover — and findings about it are a reviewer's voice, not the author's; mixed
in, the body reads as if the author flagged their own work, and the repair
detector had to search bodies for a phrase that machinery PRs also mention.

## Pattern

`persist.sh` posts the findings as a **comment review** on the PR, headed
`## Authoring review (unattended land, not blocking)`, right after the PR exists
and before the merge. A resumed land reads the PR's reviews first and posts
once. Attended lands still block on findings.

`findings-pending.sh` lists the merged PRs lacking the `findings-repaired` label
whose reviews open with the heading — read from the most recent hundred, since
forge search does not match review text. The repair skill reads the review, and
the body's "Source context" section for intent.

## Adapt notes

A comment review is the only kind the opening account can post on its own PR.
The heading is a plain literal shared by the two scripts; keep it quote-free so it
embeds in the detector's `--jq` filter.
