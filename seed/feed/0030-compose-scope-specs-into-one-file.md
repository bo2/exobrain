---
id: 0030
title: Compose connected-scope specs into one generated file per agent
date: 2026-06-18
tags: [connect-agent, scopes, agents]
touches_invariant: false
files: [scripts/connect-agent.sh, CLAUDE.md, domains/exobrain/agents.md]
---

## Problem

Wiring per-scope agent specs as a fan of symlinks — one `AGENTS.<scope>.md` (plus a per-agent sidecar) per connected scope, plus an importer that `@-imports` each — produces a noisy agent directory, a bespoke link-and-prune path, and breakage whenever the suffix scheme changes. An agent that delivers specs by inlining (a marker-block rewrite) already concatenates the chain into one block, so the symlink fan is dead weight for it — symlinks created in its target dir that nothing reads.

## Pattern

Compose once, deliver per agent. Concatenate every connected scope's spec (shallow→deep) and the optional-skills index into a single stream from one helper, then hand that composition to each agent the way it natively loads context:

- an agent with a file-import directive `@-imports` one generated, gitignored composed file (in place of a fan of per-scope imports);
- an agent that inlines (no import primitive) writes the same composition into its memory file between markers.

The global scope (root spec + root sidecar) is auto-loaded by the agent and stays out of the composition for an import-directive agent whose checked-in entry point already loads it. Collapsing the fan into one helper removes the per-scope symlink machinery and a whole class of stale-link bugs.

## Reference (illustration only)

```sh
compose_context() {            # each chain scope's AGENTS.md (+ agent sidecar) + the index
  for s in "${CHAIN[@]}"; do
    [ "$s" = global ] && continue
    [ -f "$REPO/$s/AGENTS.md" ] && { echo "<!-- scope: $s -->"; cat "$REPO/$s/AGENTS.md"; }
    [ -f "$REPO/$s/$SIDECAR" ] && { echo "<!-- $s — $AGENT -->"; cat "$REPO/$s/$SIDECAR"; }
  done
  [ -f "$INDEX" ] && { echo "<!-- optional-skills -->"; cat "$INDEX"; }
}
# import-directive agent: compose_context > .agent/AGENTS.override.md  (entry point @-imports it)
# inline-only agent:      { root_sidecar; compose_context; } | inject into the memory file
```

## Adapt notes

Trade-off vs. live symlinks: a composed file is a snapshot, so editing a scope spec needs a relink to take effect (a post-merge / post-rewrite hook does this after a pull). Two delivery subtleties: (1) the import-directive agent must tolerate a *missing* composed file on a fresh clone — rely on imports being silently ignored when absent, and regenerate on first connect; (2) an inline-only agent that auto-loads the root `AGENTS.md` but *not* the root sidecar must prepend that sidecar ahead of the shared composition. Have the relink delete the previous scheme's artifacts (old per-scope symlinks) so upgrades are seamless — match the symlinks by name and delete only symlinks, so the real composed file (which shares the `AGENTS.*` glob) is never swept. No scope-resolution invariant changes: chain order and deepest-wins are untouched; only the delivery of specs to the agent surface changes.
