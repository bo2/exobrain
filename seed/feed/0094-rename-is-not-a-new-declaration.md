---
id: 0094
title: Grandfather a renamed shared skill through the proof gate
date: 2026-07-31
tags: [skills, validation, authoring]
touches_invariant: false
files: [scripts/authoring-review.sh, knowledge/exobrain/skills.md, skills/exobrain-tests/unit/test-authoring-review.sh]
---

## Problem

The new-shared-skill proof gate decides what is "new" by diffing declaration
*names* between the base ref and HEAD: a name present at HEAD and absent at base
is a new shared skill and must carry committed proof it earns its reach.

Renaming an existing shared skill presents exactly that signature. The gate
blocks the land and demands proof for a skill that already had standing, whose
reach did not change by a single reader — nothing new loads for anyone. The
only ways past are to fabricate a proof artifact or to skip the gate, both of
which cost more than the rename. In practice a shared skill becomes unrenamable.

The same trap waits for any gate keyed on identity strings — registry names,
tool doc filenames, scope ids. Renames are common; the gate reads every one of
them as a birth.

## Pattern

Gate on the **change in reach**, not on the appearance of a new string. A rename
changes what a thing is called; it does not change whose context loads it.

Resolve the rename before comparing: ask the VCS which paths at HEAD are renames
of paths at base, and let the new name inherit the old name's standing.

Grant that inheritance **per registry**, which keeps the gate honest in the case
that looks similar but isn't: a skill *moved* from a person scope into a shared
one is also a rename at the path level, but its reach genuinely widens, so it
must still face the gate. Inheriting only within the same registry file
distinguishes the two for free.

## Reference (illustration only)

Build a `<new>=<old>` map from rename detection over the entry-point files, then
consult it when a declared name is missing from the base:

```bash
_renames=" "
while IFS=$'\t' read -r _st _old _new; do
    case "$_st" in R*) ;; *) continue ;; esac
    _old="${_old#*skills/}"; _old="${_old%/SKILL.md}"
    _new="${_new#*skills/}"; _new="${_new%/SKILL.md}"
    _renames="$_renames$_new=$_old "
done < <(git diff --name-status --find-renames "$BASE...HEAD" -- '*SKILL.md')

# ... per registry, for each name declared at HEAD but not at BASE:
_from="$(rename_src "$nm")"
if [[ -n "$_from" ]] && printf '%s\n' "$base_decls" | grep -qxF -- "$_from"; then
    continue          # same registry, former name — standing inherited
fi
```

Pair it with two tests that pin both directions: a renamed shared skill lands
clean, and a genuinely new unproven one still blocks. The second is the one that
matters — grandfathering a rename must not blunt the gate it runs inside.

## Adapt notes

Preserves the gate's invariant: an unproven skill newly reaching a shared scope
is still blocked. If your gate's "already declared" set spans all scopes at once
rather than one registry at a time, add the scope comparison explicitly —
otherwise a person→global move inherits standing it hasn't earned.

Rename detection needs the source and destination to be similar enough to pair;
a rename that also rewrites most of the file reads as delete + add and faces the
gate. That failure direction is the safe one.
