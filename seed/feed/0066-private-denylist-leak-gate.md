---
id: 0066
title: Private-denylist leak gate in the deterministic validator
date: 2026-07-11
tags: [validation, security, scripts]
touches_invariant: false
files: [scripts/validate-exobrain.sh]
---

## Problem

A repo whose tracked tree is visible beyond its author — public, or shared
with a team — can leak private identifiers (real names, employers, internal
hostnames, ticket prefixes, private tool names) through file content, commit
messages, or branch names. An authoring rule says to keep them out, but
nothing enforces it at push time, and one missed term in a squash commit is
permanent once pushed: scrubbing it afterwards takes a history rewrite. The
term list itself can't be committed — it *is* the private information.

## Pattern

Keep the forbidden-term list in the gitignored `local/` scope
(`local/denylist.txt`, one case-insensitive ERE per line, `#` comments), and
teach the deterministic validator — already the pre-push gate — to scan three
surfaces when the file exists: all tracked content (`git grep`), commit
messages not yet on the remote default branch, and the current branch name.
Absent file → the check degrades open, so fresh clones and instances that
don't need it pay nothing. Worktrees don't carry untracked `local/`, so the
validator resolves the main checkout through the shared git common dir and
reads the list from there — pushes from feature worktrees stay gated.

Git hooks never see PR titles or bodies; a scope rule instructs the agent to
scan those against the same list before `gh pr create` and after body edits.

## Adapt notes

- Scan only *outgoing* commit messages (`origin/<default>..HEAD`), never full
  history — adopting the gate must not flag commits that already shipped.
- Word-boundary syntax in the list is the list author's concern (it's
  per-machine): `\b` works in GNU and BSD grep; spell out
  `(^|[^a-z0-9])term([^a-z0-9]|$)` where portability matters.
- Too-generic terms (a chat tool's name that is also an English word) block
  legitimate prose; leave them to agent judgment and note that in the local
  scope's spec rather than listing them.
