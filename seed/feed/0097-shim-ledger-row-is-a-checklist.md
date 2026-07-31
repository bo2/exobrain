---
id: 0097
title: Check the shim ledger's file list as a checklist, not a lookup
date: 2026-07-31
tags: [validation, compat, scripts]
touches_invariant: false
files: [scripts/validate-exobrain.sh, skills/exobrain-tests/unit/test-compat-ledger.sh]
---

## Problem

The compatibility-shim ledger pairs a marker at each code site with a row naming
every file that carries it, and the validator checks the pair. It checked one
direction properly — every file a row names must carry that row's marker — and
only half of the other: a marker had to have a row with its id, but nothing
asked whether that row **listed the file the marker was sitting in**.

So a shim spanning two files could be recorded as spanning one, and validation
stayed clean. The gap is worst exactly where it is most likely: a shim's code
and the test guarding it live in different files, the code goes in the row, and
the test quietly does not. Retirement then deletes the code and the row and
leaves a test asserting the behavior of something that no longer exists.

This is the failure the ledger was built to prevent, reintroduced one level up.
The ledger was right; the gate reading it was incomplete.

## Pattern

When a registry exists so that a future change can be made completely, validate
it for **completeness**, not just consistency. "Does this entry resolve?" is a
lookup. "Does this entry name everything it will have to account for?" is a
checklist, and only the second makes the registry trustworthy at the moment it
matters — when someone is deleting things.

Concretely, for a marker-and-ledger scheme, three checks are needed, not two:

1. every file a row names carries that row's marker;
2. every marker has a row with its id;
3. every marker's file appears in that row's file list.

The third is the one that makes the row a complete inventory. Without it the row
is merely non-contradictory, which is not the same thing.

## Reference (illustration only)

Record each row's files while parsing the ledger, then test membership on the
reverse pass, beside the checks already there:

```bash
# while parsing rows
LEDGER_FILES["$id"]="${LEDGER_FILES[$id]:-} $file"

# on the reverse pass, for a marker with id $mid found in $rel
case " ${LEDGER_FILES[$mid]:-} " in
    *" $rel "*) ;;
    *) record "COMPAT $mid marker in a file its ledger row doesn't list: $rel" ;;
esac
```

## Adapt notes

Extends the shim-ledger gate rather than replacing it; the two existing checks
are unchanged. Adopting it may surface real omissions in an existing ledger —
those are the finding, not a regression: add the missing files to their rows.

The same completeness question is worth asking of any registry whose purpose is
to make a later removal complete — a deprecation list, a feature-flag inventory,
an ownership map. Consistency checks pass on a half-filled registry.
