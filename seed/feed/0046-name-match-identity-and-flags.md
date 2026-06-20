---
id: 0046
title: Name-match identity, flag-driven connection, and a scope multi-select
date: 2026-06-20
tags: [scopes, scripts, connector]
touches_invariant: false
files: [scripts/connect-agent.sh, scripts/skills-registry.sh, domains/exobrain/scopes.md, domains/exobrain/agents.md]
---

## Problem

The connector special-cased person/host: it discovered them by a fixed
collection path (`find */people/<handle>`), auto-derived and connected them on any
headless run, and offered no way to connect a standalone scope without hand-editing
`.exobrain.json`. Identity was coupled to the folder vocabulary, and the only
non-interactive behavior was a silent auto-derive.

## Pattern

Split identity-resolution from a type-agnostic connector, and feed the connector
from one of four sources in precedence order: **explicit flags → existing/parent
config → interactive prompts → guest**.

- **Name-match identity**: a handle/hostname matches a scope by its *leaf name*,
  anywhere in the tree; the person/host collection name is only a tiebreaker when
  several match. Fall back to the conventional collection path when the scope
  doesn't exist yet. No fixed-path discovery scan.
- **Flags**: `--handle` / `--host` resolve (and scaffold) the person/host pair;
  `--scope` adds any standalone scope; `--guest` connects nothing. This is how a
  scaffolder or test drives connection without a TTY — replacing the dropped
  headless auto-derive.
- **Interactive**: a checkbox menu of every connectable scope (every `AGENTS.md`
  dir), with person + host pre-checked. Connecting a standalone scope is a toggle.
- The connector stores `connected_scopes` + the `person` id and never reads scope
  *type* for wiring.

## Reference (illustration only)

```sh
# name-match: leaf basename, parent-collection keyword as a tiebreaker only
find_scope_by_name() {  # <repo> <name> [keyword] → AGENTS.md dirs named <name>
    # collect dirs named <name> that contain an AGENTS.md; if several and a
    # keyword is given, keep the ones whose parent dir is the keyword.
}
# precedence
if $flags_given; then resolve_from_flags
elif $CONFIGURE || ! load_config; then
    if ! $RELINK && ! $RENDER_ONLY && is_interactive; then run_wizard; else CONNECTED_LEAVES=(); fi
fi
```

## Adapt notes

Keep `people/`·`hosts/` as an organizing convention — only the *matcher* stops
depending on them. Under `set -euo pipefail`, guard empty-array expansions and the
empty connected-list case (write `[]`, not `[""]`), and end name-search helpers on
a zero exit. Drops the `discover_person_dirs` scan and (now unused)
`scopes_container_collections`. No scope-resolution or security invariant changes.
