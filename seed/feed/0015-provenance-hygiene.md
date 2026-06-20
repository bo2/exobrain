---
id: 0015
title: Provenance hygiene — no downstream specifics in the seed or feed
date: 2026-06-13
tags: [propagation, authoring, conventions, security]
touches_invariant: false
files: [domains/exobrain/propagation.md, AGENTS.md, domains/exobrain/feed/README.md]
---

## Problem

The seed and its feed are public; the instances that feed improvements back up into
them are mostly private. Backporting a change by carrying its prose verbatim drags the
source instance's identity along — org or company names, internal hostnames, ticket
prefixes, usernames, private repo and tool names. That leaks private provenance into a
public repo, and bakes one instance's specifics into a pattern meant to be generic.

## Pattern

A hard adoption rule: when a change is backported up into the seed, the feed, or any
shared scope, **re-synthesize it free of the source instance's identity**. Strip org
and company names, internal hosts, ticket prefixes, usernames, and private repo/tool
names; describe the *pattern*, not where it came from. A card or shared-scope file that
names a downstream's specifics has leaked private provenance and must be genericized
before it lands. This is the upward complement to "no machine-specific paths outside
host scope" — both keep a shared scope free of a lower scope's specifics.

## Reference (illustration only)

`domains/exobrain/propagation.md` → "Provenance hygiene" (the authoritative rule); a
companion bullet in `AGENTS.md` § Conventions; a card-authoring note in
`domains/exobrain/feed/README.md`.

## Adapt notes

No invariant touched, though it reads like one — it never weakens. Applies to any
public or more-shared scope, not just this seed: a group scope shared across a family
shouldn't carry one member's private specifics either. The list of identifier kinds is
illustrative, not exhaustive — the test is "could a reader tie this to a specific
private repo or org?"; if so, genericize.
