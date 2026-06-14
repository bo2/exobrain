---
id: 0009
title: Operational rules + authoring discipline sharpening
date: 2026-06-13
tags: [agents-md, authoring, claude, reader-lens, tools]
touches_invariant: false
files: [AGENTS.md, CLAUDE.md, domains/exobrain/authoring.md]
---

## Problem

A handful of agent-behavior and authoring rules the spec didn't yet state
plainly: agents silently built model-bending changes instead of flagging them;
nothing told an agent what to do when a task needs a tool that isn't connected;
the reader-lens rule didn't name its most common violation (author-serving
prose); and the authoring rules lacked a quick trigger for spotting drift-prone
values and a one-line test for current-state-vs-history.

## Pattern

Short, must-follow rules go in the auto-loaded spec; depth goes in the
on-demand docs:

- **Validate the request against the conventions** (AGENTS.md) — a requested
  change isn't automatically right; when it fights the model, propose the
  better-fitting structure with a concrete alternative before building. Challenge
  once, substantively; the human decides. Structural conflicts only.
- **Propose connecting a tool when the task needs one** (AGENTS.md) — on a
  not-connected / missing-credential error, name the tool and what it unlocks
  *for this task*, and offer to connect it; propose, don't auto-connect (the human
  drives credential setup).
- **Reader-lens cut, sharpened** (AGENTS.md) — a line that serves no nameable
  reader doesn't belong, *especially* prose explaining or defending your own
  choices, which serves the author, not the reader.
- **Authoring triggers** (`authoring.md`) — a "watch-for phrasing" list (N
  attempts, X-second timeout, $N balance, Z% growth = a value that drifts;
  reframe), and a litmus test for current-state-vs-history ("if this had landed
  years ago and the narrative were forgotten, would I still describe it this
  way?").
- **Two CLAUDE.md files** (`CLAUDE.md`) — distinguish the handcrafted root file
  from the generated `.claude/CLAUDE.md`.

## Reference (illustration only)

The named sections in the seed's `AGENTS.md`, `CLAUDE.md`, and
`domains/exobrain/authoring.md` at or after this card's date.

## Adapt notes

No invariant touched. The "propose a tool" rule sits next to §Security — keep its
"the human drives credential setup" boundary intact when rewording. Fold the
authoring triggers into your existing order-of-magnitude / current-state sections
rather than adding new ones, to keep the doc lean. The CLAUDE.md note is
Claude-specific; the equivalent for Codex/OpenClaw is their own injection file.
