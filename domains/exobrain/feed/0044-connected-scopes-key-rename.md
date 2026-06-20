---
id: 0044
title: Rename the .exobrain.json connection key to connected_scopes
date: 2026-06-20
tags: [scopes, scripts, config]
touches_invariant: false
files: [scripts/connect-agent.sh, scripts/skills-status.sh, scripts/skills-promote.sh, scripts/test-connect-agent.sh, domains/exobrain/scopes.md, domains/exobrain/tools.md]
---

## Problem

`.exobrain.json`'s connection list was keyed `connected` — a bare adjective that
reads ambiguously next to the file's other state (`agents`, `tools`) and against
the verb "connect an agent." The value is a list of scope paths, so the key should
say so.

## Pattern

Rename the key to `connected_scopes` everywhere it is read or written, and in the
docs/examples that show the file's shape. Keep it a clean rename — one name, no
compatibility alias — and migrate the per-machine `.exobrain.json` as part of
adopting. The connection *semantics* are unchanged: still a list of leaf scope
paths, unioned and resolved deepest-wins.

## Reference (illustration only)

Readers and the writer move from `.connected` to `.connected_scopes`:

```sh
# read
jq -r '(.connected_scopes // [])[]' "$CONFIG_FILE"
# write (connect-agent save_config)
jq -n --argjson e "$existing" --argjson c "$leaves_json" --argjson ag "$agents_json" \
  '$e + {connected_scopes: $c, agents: $ag}'
```

```json
{ "connected_scopes": ["people/<id>/hosts/<host>"], "agents": ["claude"] }
```

## Adapt notes

`.exobrain.json` is gitignored and per-machine, so the rename can't migrate it for
you — update the key in each machine's file when you adopt, or the connector reads
an empty list and falls to guest mode. Grep your own tree for every `.connected`
reader (connector, skills-status/promote, any tool-state helper, the connector test
harness) and the doc examples; rename them together. No security or
scope-resolution invariant changes.
