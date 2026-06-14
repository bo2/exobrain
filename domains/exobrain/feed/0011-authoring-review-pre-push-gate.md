---
id: 0011
title: LLM authoring-review pre-push gate
date: 2026-06-13
tags: [scripts, validation, authoring, hooks, connect-agent]
touches_invariant: true
files: [scripts/authoring-review.sh, scripts/connect-agent.sh]
---

## Problem

`validate-exobrain.sh` catches deterministic violations (naming, JSON, registry)
but not the *judgment* ones the authoring rules are mostly about: change-narrative
in a profile, transcribed code, ephemeral numbers, author-serving prose, a spec
written as a delta. Those slip through to the repo because nothing reads the diff
with the rubric in hand.

## Pattern

A second, **judgment** layer that complements the deterministic checks: on push,
diff the changed spec/domain markdown against the base branch and have a headless
agent review it against the authoring rubric, emitting `AUTHORING-OK` or a list of
concrete findings. Critical properties keep it safe to wire into a hook:

- **Degrades open.** No agent CLI installed, or a timeout/error → exit 0. A
  missing or flaky checker never blocks a push.
- **Treats the diff as data.** The rubric is a quoted heredoc; the diff is
  concatenated as plain data, never interpreted — the prompt-injection invariant
  holds even though it processes untrusted content.
- **Bypassable.** `EXOBRAIN_SKIP_AUTHORING_REVIEW=1`, or `git push --no-verify`.

## Reference (illustration only)

`scripts/authoring-review.sh` (engine order claude → codex → degrade-open), wired
into the `pre-push` hook that `connect-agent.sh` installs, right after the
`validate-exobrain.sh` call.

## Adapt notes

**Touches the validation contract** (an invariant) — but by *extending* it (adds
a gate, drops none), which is allowed. It's a deliberate design choice to run an
LLM on spec-touching pushes; an instance that doesn't want that can ship the
script unwired (run it manually) or skip the card. Set the base ref to your
default branch (`origin/main`), and make the rubric reference only docs you
actually have (the seed cites `authoring.md` + `domains.md`). Point its escalation
at whatever deeper authoring/reader-lens skill you ship.
