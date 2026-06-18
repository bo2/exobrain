---
id: 0028
title: Keep the LLM authoring review opt-in, not a pre-push gate
date: 2026-06-18
tags: [scripts, validation, authoring, hooks, connect-agent]
touches_invariant: true
files: [scripts/connect-agent.sh, scripts/authoring-review.sh, AGENTS.md]
---

## Problem

Wiring the LLM authoring review into the `pre-push` hook (alongside the fast deterministic validator) taxes *every* push with a model round-trip — seconds to tens of seconds — on changes that often touch no spec or domain file at all. The latency is paid up front and unconditionally, while the value (catching judgment-level authoring smells) is occasional. A gate that slow on the common path trains people to reach for `--no-verify`, which defeats the deterministic gate sitting behind it too.

Supersedes card 0011 (authoring-review as a pre-push gate): that card's own design anticipated this "ship the script unwired" option.

## Pattern

Keep the pre-push hook to **fast, deterministic** checks only; make the **slow LLM judgment** pass an on-demand tool rather than a blocking gate. The script stays — runnable by hand before a substantial spec/domain edit — but nothing forces it onto the push path. Pushes stay quick; the judgment review runs when it's worth it, chosen by the author rather than imposed on every push. The deterministic validator remains the only automatic gate.

## Reference (illustration only)

Drop the `authoring-review.sh` invocation from the generated `pre-push` hook in `connect-agent.sh`, leaving only the deterministic validator. Reword the script's banner and verdict message, the validation spec section in `AGENTS.md`, and any harness comment so the review reads as on-demand, not as a push gate (no "blocks the push" / "bypass with `--no-verify`" framing).

## Adapt notes

**Touches the validation contract** (an invariant) — but by *narrowing what runs automatically*, not by weakening enforcement: the deterministic validator (including its greppable authoring subset) still gates every push, and the script's prompt-injection safety (diff-as-data) is unchanged. An instance that genuinely wants the LLM review on every push can keep it wired — this is a latency/value trade-off, not a correctness fix. If you unwire it, strip the now-stale push-gate framing from the script and every doc that names it in the same pass, so it reads as on-demand everywhere.
