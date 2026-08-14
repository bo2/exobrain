---
id: 0117
title: An empty array is an unset variable
date: 2026-08-13
tags: [scripts, portability, validation, tests]
touches_invariant: false
files: [scripts/validate-exobrain.sh, skills/exobrain-tests/behavior/lib/invoke.sh, skills/exobrain-tests/behavior/lib/judge.sh, skills/exobrain-tests/behavior/lib/common.sh]
---

## Problem

bash before 4.4 — the 3.2 macOS still ships at `/bin/bash` — treats an empty array
as unset, so `"${arr[@]}"` under `set -u` is a fatal *unbound variable* rather than
zero arguments.

The behavioral test harness built its agent command from four arrays that are empty
in ordinary configurations: no `timeout(1)` installed, no pinned model, a profile
with no extra flags. On any machine where `/bin/bash` won the PATH, every case died
before the agent started — and reported as a **behavioral failure**, blaming the
exobrain's content for a harness defect. The suite looked run; nothing had run.

The rule was already known: one script carried the correct guard and a comment
naming the hazard. Knowing it in one file did not keep it out of the others.

## Pattern

Expand any array that can be empty in the guarded form, which is correct whether or
not it is empty and needs no accompanying count test:

```bash
${arr[@]+"${arr[@]}"}          # values
${arr[@]+"${!arr[@]}"}         # indices
```

Then check it, because this is the shape a published rule cannot hold: the
violating code works on the author's machine, and the failure surfaces as someone
else's test failing for an unrelated-looking reason.

Two properties make the check precise rather than noisy:

- **Flag only arrays you can prove go empty** — the ones some script assigns an
  empty literal (`arr=()`). An array built once from a fixed list is left alone.
- **Collect those names across the whole tree, not per file.** The array that is
  empty most often is assigned in a sourced library and expanded by its caller; a
  per-file rule misses exactly that case.

Strip the guarded form from a line before testing it: a guarded expansion contains
the bare one as a substring, so a naive pattern flags the fix.

Adopting it means a sweep. The guarded form is correct at every site, including
those a surrounding count test already protects, so the sweep is mechanical — and
where the count test existed only as a workaround, it can now be deleted.

## Related: a gate's message travels

The neighbouring portability gate reported violations with `see seed/feed/0061`.
That path exists only in the canonical seed; in every instance the rule ships to,
it points at nothing. A gate in the framework body states its reason in the
message — the reader who trips it is meeting the rule for the first time, and they
are usually not reading it where it was written.

## Adapt notes

Extends the validation contract with one deterministic check; no security or
scope-resolution semantics change. Run the check before wiring it into the push
gate and expect the sweep to be the larger half of the work.
