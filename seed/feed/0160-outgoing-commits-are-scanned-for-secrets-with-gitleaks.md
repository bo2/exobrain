---
id: 0160
title: Outgoing commits are scanned for secrets with gitleaks
date: 2026-10-08
tags: [security, validation, scripts]
touches_invariant: true
files: [scripts/validate-exobrain.sh, .gitleaks.toml, AGENTS.md, skills/exobrain-tests/unit/test-secret-scan.sh, skills/exobrain-tests/unit/run.sh]
---

## Problem

"Never commit secrets" was a rule and a `.gitleaks.toml` nobody ran; a pasted
token was caught only by eye. The config's allowlists for `workspaces/` and
`_raw/` exempted exactly the places pasted material lands.

## Pattern

The validator runs gitleaks over the commits a branch adds against the default
branch, with the checkout's `.gitleaks.toml` (else the instance's, for a
mount's worktree): one redacted violation per hit — rule, file, line, commit,
never the match. Diff-scoped like the other checks, so the history is
grandfathered and the pre-push hook stays fast. Not installed is a note, no
violation; installed but failing is a violation, since a scan that silently did
not happen is the gap being closed. A line that is secret-shaped by design
(a public client identifier, a planted canary) carries an inline
`gitleaks:allow`; the config allowlists two shapes instead of two trees — a
container image pinned to a commit, and the behavior suite's canary prefix.

The harness assembles its planted key from two strings, so it passes the scan
it tests, and self-skips without gitleaks.
