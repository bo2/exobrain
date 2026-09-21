---
id: 0137
title: Reconcile the bootstrap budget, keep raw capture out of git, and put the domains in semantic recall
date: 2026-09-21
tags: [connector, openclaw, privacy]
touches_invariant: false
files: [scripts/connect-agent.sh, OPENCLAW.md, knowledge/exobrain/agents.md, skills/exobrain-tests/unit/test-connect-agent.sh]
---

## Problem

Three gaps in the OpenClaw wiring, each silent:

- The injected `USER.md` outgrew the runtime's per-file bootstrap budget, which
  drops the tail without a word — and the tail is the knowledge index.
- The workspace is a git repo, and the runtime writes raw capture into its
  `memory/` — near-verbatim session-reset transcripts, the dreaming sweep's
  corpus and candidate logs. A workspace with a remote publishes all of it
  permanently; deleting the working file later cannot reach history.
- Semantic recall indexed only the workspace's own memory, so the cheap
  retrieval path searched raw capture while current truth needed a deliberate
  read.

## Pattern

All three join the connector's existing config reconcile (card 0126):

- Raise `agents.defaults.bootstrapMaxChars` / `bootstrapTotalMaxChars` to
  **floors**; a larger human-set value stays.
- Inject a marker block into the workspace's `.gitignore` covering the three
  raw-capture paths (curated `YYYY-MM-DD.md` notes stay tracked). Files an
  earlier commit already holds are *reported* with the untrack command, never
  untracked behind the human's back. `inject_block` takes optional fence strings
  so it can write into a non-HTML file.
- Union `knowledge/` into `memory.search.extraPaths` as one positive glob per
  directory depth with every segment matched as `[!_]*` — the indexer has no
  exclusion, and an unsupported negation glob silently matches everything, so
  this is what keeps `_raw/` and `_meta/` (superseded phrasing, open questions)
  out of recall.

## Adapt notes

- **Indexing sends the matched files to the runtime's configured embedding
  provider.** Decide that deliberately for domains holding sensitive content.
- Depth 4 is one past the deepest domain file; a deeper tree needs another glob.
