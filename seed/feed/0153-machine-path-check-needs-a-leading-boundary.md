---
id: 0153
title: The machine-path check matches an absolute path only at a path boundary
date: 2026-10-01
tags: [validation, scripts, portability]
touches_invariant: false
files: [scripts/validate-exobrain.sh, skills/exobrain-tests/unit/test-portable-paths.sh, skills/exobrain-tests/unit/run.sh]
---

## Problem

The validator's machine-specific-path check matched `/(Users|home)/<segment>/`
anywhere on a line. The pattern has no leading boundary, so it also matches the
tail of a relative path whose second-to-last directory is named `home` or
`Users` — `src/components/home/sidebar.tsx` — and a workspace citing ordinary
source paths is refused as carrying a machine-specific path.

## Pattern

Anchor the pattern at a path boundary: the `/` that opens `/Users/` or `/home/`
must start the line or follow a character that cannot be part of a path
(`(^|[^A-Za-z0-9._/~-])`). A relative path runs through such a segment; an
absolute one starts at it.

The harness builds a real git repository with a default ref — the check is
diff-scoped, so without one every negative assertion is vacuous — and assembles
its fixture paths at run time, since a file that spells a machine-specific path
would fail the gate it tests. It asserts both absolute forms are caught and
that a relative path, a `<name>` placeholder, and host scope pass.
