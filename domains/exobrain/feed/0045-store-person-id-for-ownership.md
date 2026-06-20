---
id: 0045
title: Store the person id in .exobrain.json for skill owner-match
date: 2026-06-20
tags: [scopes, skills, scripts, config]
touches_invariant: false
files: [scripts/connect-agent.sh, scripts/skills-registry.sh, domains/exobrain/scopes.md]
---

## Problem

Skill ownership ("a declaration auto-enables for its owner") needs to know *who you
are*. It derived your "self" ids from the basenames of connected **person-type**
scopes — which couples identity to folder position (a scope is "person" only by
sitting under the `people/` collection). Identity should be a fact about you, not a
function of where your scope directory lives.

## Pattern

Record the connecting person's id explicitly as a `person` key in the per-machine
`.exobrain.json`, written by the connector when it saves the connection. Resolve
owner-match against that stored id. Keep deriving from person-type scope basenames
as a **fallback** for configs that predate the key (and for callers that resolve
from leaves with no config), so nothing regresses while configs migrate.

## Reference (illustration only)

```sh
# owner_self_ids: prefer the stored id, else fall back to type-derivation
stored="$(jq -c '(.person // empty) | if type=="array" then . else [.] end' "$cfg")"
[[ -n "$stored" && "$stored" != "[]" ]] && { echo "$stored"; return; }
# …else derive from connected person-type scope basenames (previous behavior)
```

```json
{ "connected_scopes": ["people/<id>/hosts/<host>"], "person": "<id>", "agents": ["claude"] }
```

## Adapt notes

`.exobrain.json` is gitignored/per-machine, so the `person` key appears only after
the connector next writes config (first connect / reconfigure); the fallback covers
the gap. No security or scope-resolution invariant changes — only the source of the
owner-match "self" ids. If your instance lets one person hold several ids, store an
array.
