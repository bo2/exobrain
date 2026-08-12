---
id: 0112
title: Check the rule you published, or it decays into advice
date: 2026-08-12
tags: [validation, scripts, portability]
touches_invariant: false
files: [scripts/validate-exobrain.sh, knowledge/exobrain/machinery.md, AGENTS.md]
---

## Problem

A portability rule was written down, explained with examples, and applied to the
one script that had prompted it. Over the following weeks five fresh violations of
that same rule landed in the framework — in the validator, in the connector, in the
test harness — each written by someone who had read the rule and simply did not
think of it while writing an associative array.

Downstream, every one of those had to be found and removed again. The cost of an
unchecked rule is not paid once by the author; it is paid by each instance, every
time it adopts.

The specific rule was shell portability (bash 3.2 is still what macOS ships at
`/bin/bash`, and it has no `declare -A`, `mapfile`, or `readarray`). The general
shape is any convention that is (a) mechanically detectable, (b) invisible in
review because the violating code works fine on the author's machine, and (c)
published as prose.

## Pattern

If a rule is mechanically checkable and its violation is invisible on the author's
machine, it belongs in the deterministic gate, not only in a document. Prose
teaches the reason; the check enforces the rule.

Two properties keep such a gate from becoming a nuisance:

- **Exempt the discussion.** Skip comment lines, so the rule stays writable in
  prose — a check that flags its own documentation gets disabled.
- **Provide a named opt-out.** A file that genuinely needs the construct declares
  it (`# exobrain-allow-bash4`) and says why. An escape hatch that must be written
  down is a decision, not a loophole.

Report the file and line, and point at the card that explains the why — the person
who trips the gate is usually meeting the rule for the first time.

## Reference (illustration only)

```bash
while IFS= read -r f; do
    grep -qF 'exobrain-allow-bash4' "$f" && continue
    while IFS= read -r hit; do
        record "bash 4 construct in ${f#"$REPO_DIR"/}:${hit%%:*} — macOS ships bash 3.2"
    done < <(grep -nE '(^|[;&|(`]|[[:space:]])(mapfile|readarray)[[:space:]]|declare[[:space:]]+-A' "$f" \
             | grep -vE '^[0-9]+:[[:space:]]*#')     # comment lines exempt
done < <(find_repo -type f -name '*.sh')
```

## Adapt notes

Extends the validation contract with a new deterministic check; no security or
scope-resolution semantics change. Adopting it means fixing the existing
violations first — run it before wiring it into the push gate, and expect the
sweep to be the larger half of the work.

The general move transfers: any published convention that keeps being re-broken is
a candidate. Prefer a check with an opt-out over a stricter rule with none.
