---
id: 0040
title: An "unlisted" registry tier — registered but deliberately unsurfaced
date: 2026-06-18
tags: [skills, registry, discoverability]
touches_invariant: false
files: [skills.schema.json, scripts/skills-registry.sh, AGENTS.md]
---

## Problem

A skill registry usually has two visibility levels: auto-loaded (full description always in context) and listed (a one-line index row the agent can match against). But the listed row still costs context every session and, worse, invites the agent to *proactively* fire the skill on a loose match. Some skills should only ever run when explicitly named — destructive or misfire-risk tools, experiments, by-name-only utilities — and an always-present trigger row is exactly wrong for them.

## Pattern

Add a third level between "listed" and "removed": **unlisted** — registered and invocable, but absent from the agent's context. Not auto-loaded, and **not** in the proactive index. The agent reaches it only when the user names it or when it deliberately consults the registry; one shared pointer in the always-loaded context ("to invoke a skill you don't see listed, resolve it from the registry") keeps by-name invocation working at near-zero standing cost.

The control is over *salience, not access* — an agent that reads the registry still sees it; unlisted means "won't be surfaced or suggested," not "locked." It sits cleanly between the listed tier and a removed state: unlisted is a live, invocable registration; removed deletes the entry entirely.

## Reference (illustration only)

If the surfacing code filters tiers by exact match, the new value rides existing behavior for free — the link step links `always`, the index step lists `optional`, and anything else (including `unlisted`) is simply left unsurfaced. The only additions: accept the value in the schema/validator, and add one pointer in the always-loaded context telling the agent where to resolve a named-but-unlisted skill (e.g. the discovery catalog command).

## Adapt notes

The token saving over a listed tier is marginal; the real value is **trigger precision** — keeping the proactive index high-signal and giving misfire-risk skills a home behind explicit intent. A new tier costs almost nothing when surfacing branches on exact tier values (unmatched ⇒ unsurfaced, which is the desired behavior). Decide whether externally-fetched skills at this tier are still installed locally (so they're invocable by name) but excluded from the index.
