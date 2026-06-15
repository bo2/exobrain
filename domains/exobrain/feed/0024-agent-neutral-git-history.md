---
id: 0024
title: Keep git history agent-neutral — drop the harness's default commit/PR signature
date: 2026-06-15
tags: [git, workflow, agents, sidecar]
touches_invariant: false
files: [CLAUDE.md]
---

## Problem

Coding-agent harnesses bake their own attribution into git history by default —
Claude Code appends a `🤖 Generated with Claude Code` footer to PR bodies and a
`Co-Authored-By: Claude …` trailer to commit messages. An exobrain is
deliberately agent-neutral (a shared `AGENTS.md` plus per-agent sidecars), so
stamping one agent's branding into the repo's permanent history cuts against
that. It's not a repo convention either — it's a harness default that slips in
unnoticed, leaving history that reads as one tool's output rather than the
human's.

## Pattern

Codify, in the agent's **own sidecar** (`CLAUDE.md` / `CODEX.md` /
`OPENCLAW.md` — wherever that agent's behavior is configured), that commits and
PRs carry no agent attribution: no harness footer in PR bodies, no
`Co-Authored-By` trailer in commits. The sidecar is the right home because the
footer/trailer formats are harness-specific; each agent suppresses its own. The
payoff: history stays uniform regardless of which agent did the work, and reads
as the human's.

## Reference (illustration only)

A short **Git history hygiene** section in the root `CLAUDE.md`: "Keep this
repo's history agent-neutral — omit Claude Code's default attribution. No
`🤖 Generated with Claude Code` footer in PR bodies, and no `Co-Authored-By:
Claude …` trailer in commit messages."

## Adapt notes

No invariant touched. This is a preference, not a fix — an instance that *wants*
visible agent attribution can skip the card. Put the rule in the sidecar of each
agent you run (the trailer/footer differ per harness); a Codex- or
OpenClaw-driven instance writes the equivalent in its own sidecar. Already-merged
commits that carry the signature stay as-is — rewriting pushed history is
off-limits — so the rule governs only new commits and PRs.
