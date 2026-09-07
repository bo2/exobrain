---
id: 0128
title: Retrieve before asking the person to restate what they already recorded
date: 2026-09-07
tags: [openclaw, sidecar, behavior]
touches_invariant: false
files: [OPENCLAW.md]
---

## Problem

In a chat runtime, a short personal follow-up — "did we renew it?", "what's our
plan?", "the one I already have" — names no domain, and an agent answering it
cold asks the person to restate a provider, a product, a file, an event, a
preference they recorded in the exobrain precisely so they would not have to. The
root spec says to read a domain before reasoning about it; it does not say that
a pronoun is a domain reference.

## Pattern

**A personal follow-up is a retrieval request.** When the message says "we",
"our", "my", something the person "already" has, a household member, or a
recorded possession, event, or preference, retrieve before asking: the knowledge
index picks the likely domain, its `README.md` first, then the domain's content,
then `workspaces/` for provenance. Ask the person to restate only after retrieval
fails, and say what was checked. An impersonal general-knowledge request with no
dependency on their world is exempt.

## Adapt notes

- Lives in the runtime sidecar of the chat-facing agent, where short follow-ups
  arrive; a coding agent's sidecar rarely needs it.
- Unmeasured: the A/B harness has no runner for the chat runtime, so this rule
  ships on judgment. An instance that can drive its chat runtime headless should
  measure it (a follow-up task with the fact recorded in a domain; grade whether
  the agent reads the domain before replying) and record the result beside the
  rule.
