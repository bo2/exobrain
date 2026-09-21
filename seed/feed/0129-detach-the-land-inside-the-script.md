---
id: 0129
title: Detach the land inside the script, and let an unattended land record findings instead of stopping
date: 2026-09-21
tags: [persist, scripts, chat-runtime]
touches_invariant: false
files: [scripts/persist.sh, skills/exobrain-persist/SKILL.md, OPENCLAW.md, skills/exobrain-tests/unit/test-persist.sh]
---

## Problem

Card 0122 asked a chat runtime to background the land itself. In practice the
model ran the script in the foreground and held the reply for minutes to cite the
PR: a rule living in a sidecar paragraph lost to the skill's own Land step, which
showed one form of the command. And once lands did run unattended, the first one
stopped on authoring-review findings nobody was there to fix.

Beside it, the option parser looped forever on a value-taking option given
without its value (`shift 2` fails without shifting), and `die` echoed its exit
code into the message.

## Pattern

**Put the detach in the script, and the choice of form in the skill.**
`persist.sh --detach` commits in the foreground — so "saved" is true when the
reply goes out — then re-runs itself in a new session with stdio on a log under
the main checkout's `.git/persist-logs/`, and returns. The skill's Land step
shows both forms and says which turn takes which; the runtime sidecar keeps only
what is the runtime's. A machinery diff without its assertion is refused in the
foreground, where the caller still sees it.

**An unattended land (detached or swept) records authoring findings in the PR
body** under a fixed heading and lands anyway. The deterministic gates — the
validator and the review's proof gate — block either way, and a foreground land
still blocks on every finding.

## Adapt notes

- The timeline row added by the background half folds into the commit the
  foreground half just made, so the branch still carries one commit.
- The findings heading is a contract with whatever later enumerates those PRs
  (card 0131); keep it in one place and test that the two agree.
