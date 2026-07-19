---
id: 0082
title: PR / issue / comment authoring conventions
date: 2026-07-19
tags: [agents-md, git, workflow]
touches_invariant: false
files: [AGENTS.md]
---

## Problem

Agents opening PRs and writing issue/PR comments hit avoidable footguns: a bare
`#<number>` in a body or comment gets auto-linked by the forge into an unintended
cross-reference on some other issue/PR; a PR's title and description drift out of
date as later commits change its scope; and in a collaborative repo a human can't
tell which comments an agent wrote.

## Pattern

Three conventions in the always-loaded spec:

1. Never write a bare `#<number>` in a PR/issue body or comment — write "Item 3"
   or the full URL — so the forge doesn't manufacture a cross-reference.
2. Keep a PR's title and description current as commits shift its scope.
3. Authored artifacts (commit messages, PR titles/descriptions) stay
   agent-neutral; a comment addressed *to a person* carries a robot marker so the
   reader knows an agent wrote it. The two don't conflict: one keeps the durable
   history neutral, the other adds transparency to a conversation.

## Adapt notes

- Rule 3 matters only where people collaborate on PRs/issues; a solo instance can
  drop it. It is deliberately scoped to person-directed comments, never to the
  neutral authored artifacts the history-hygiene rule governs.
- "The forge" is whatever host the instance uses; the `#<n>` auto-link behavior is
  common to the major ones.
