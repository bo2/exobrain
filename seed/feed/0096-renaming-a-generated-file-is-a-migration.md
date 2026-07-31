---
id: 0096
title: Treat renaming a generated file as a state migration, not a rename
date: 2026-07-31
tags: [connector, compat, scripts]
touches_invariant: false
files: [scripts/connect-agent.sh, knowledge/exobrain/compat.md, skills/exobrain-tests/unit/test-connect-agent.sh]
---

## Problem

A connector that installs generated files onto an agent's surface typically
clears a destination when there is nothing to write, so a surface never imports
an index describing content that no longer exists. That installer knows exactly
one name per artifact: the one it writes.

Rename the artifact and the old copy becomes invisible to every mechanism at
once. The installer never names it again. The generated entry point stops
importing it. The file is gitignored, so no diff shows it and no validator walks
it. It simply sits in every checkout that relinks across the change, holding
content that ages forever, indistinguishable from a file the human put there.

Nothing breaks loudly. That is what makes it easy to ship.

## Pattern

A generated file's name is state on every machine that ever ran the generator.
Changing it is a migration, and migrations need a sweep with a removal date.

Key the sweep on **content, not name** — match the heading or sentinel the
generator itself emits. The old name is a name a human may also have used; the
generated first line is not. That way the sweep removes only what this tool
wrote and leaves a same-named file of the human's own untouched.

Give the sweep a marker and a dated ledger row like any other transitional code.
It clears once every machine has run the generator once, which for a connector
is short — the shim's own expiry is the reminder to delete it.

Cover both halves in one test: the stale copy is reaped, **and** a same-named
foreign file survives. The second assertion is the one that matters; without it
a sweep keyed on name passes just as well as one keyed on content.

## Reference (illustration only)

```bash
# COMPAT NNNN (remove after <date>) — <artifact> was called <old-name> before it
# was named after the tree it catalogs. The installer only clears the destination
# it writes, so a checkout relinking across the rename keeps the old copy with
# nothing importing it. Matched on the generated heading, so a same-named file of
# the human's own is left alone.
prune_renamed_index() {
    local dead="$TARGET_DIR/<old-name>" first
    [[ -f "$dead" ]] || return 0
    first="$(head -n 1 "$dead")"
    [[ "$first" == "<generated heading>" ]] || return 0
    rm -f "$dead"; echo "  - removed renamed index copy $dead"
}
```

## Adapt notes

Applies to anything a tool writes to a fixed path outside version control —
generated indexes, caches, home-config fragments, symlink farms. Ask what would
happen if the path changed today: if the answer is "the old one stays there
forever", the rename owes a sweep.

If your generated file carries no stable first line, add one before renaming it;
matching on content is what keeps the sweep from eating a human's file.
