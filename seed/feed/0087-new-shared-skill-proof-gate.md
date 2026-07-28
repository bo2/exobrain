---
id: 0087
title: A skill declared at a shared scope must carry committed proof
date: 2026-07-28
tags: [skills, gates, authoring]
touches_invariant: false
files: [scripts/authoring-review.sh, domains/exobrain/skills.md, AGENTS.md]
---

## Problem

Declaring a skill at a shared scope loads it for everyone whose chain includes that
scope. Nothing checked that the skill was worth that cost, so shared registries
accumulate skills nobody proved: prose restating the auto-loaded specs, generic
best-practice checklists, one-off helpers that only their author ever used. Each one
taxes every session it loads into and drifts from the specs it duplicates. The cost is
paid by people who never chose it, and the author has no moment where the question
"does this earn its reach?" is actually put to them.

## Pattern

At the land, a skill **newly declared at a shared scope** must carry *committed* proof
it earns that reach — or move to a person scope, which imposes on no one and which
colleagues can still opt into with an override. Proof is a committed artifact, not an
assertion in the pull request:

- registration as a periodic job in a `schedule.json` (something drives it);
- a test, eval, or A/B artifact inside the skill dir — a Utility proved by a run, a
  behavior-shaping skill by an A/B result showing it actually moves behavior.

Proof lives **with the skill**, not as a link to the workspace that produced it: a
skill has to stay current, and a citation into a point-in-time record goes stale
silently. Committing the run into the skill's own directory keeps proof and skill
together through every later move.

Three properties make this adoptable rather than disruptive:

- **Grandfathered.** The check set-differences declarations at HEAD against the base
  ref, so an existing corpus is never flagged — only what this branch adds.
- **Personal scope is the pressure valve.** The gate never says "don't write this"; it
  says "prove it or keep it yours." There is always an action that clears it.
- **Permissive detection.** A missed proof signal means a skill isn't flagged. That's
  the safe direction for a gate that blocks a land.

Pair the deterministic block with a **skill-authoring rubric** in the same review's
model pass, applied to any changed `SKILL.md`: type (utility / behavior-shaping /
hybrid — a helper script's presence doesn't make prose a utility), leverage (does it
enable something the auto-loaded context doesn't already?), proof, and reach (is
`force: true` or `tier: always` proportionate?). It recommends one of KEEP, TRIM,
PROVE, DEMOTE, MERGE. The deterministic block catches the omission; the rubric catches
the skill that has proof but shouldn't exist.

Place it at the **land**, not on every push: a work-in-progress branch carrying a
half-built skill must stay pushable.

## Reference (illustration only)

In `scripts/authoring-review.sh`, before the model pass, exiting 2 when it blocks:

```bash
_decls='.skills[] | select((has("from") | not) and (has("source") | not)) | .name'
head_decls="$(jq -r "$_decls" "$REPO_DIR/$sj" 2>/dev/null)"
base_decls="$(git -C "$REPO_DIR" show "$BASE:$sj" 2>/dev/null | jq -r "$_decls" 2>/dev/null)"
# names in head_decls but not base_decls -> new; check each for a proof signal
```

Which scope collections count as personal is read from `scopes.json` (the `person` and
`host` types) rather than hardcoded, so a renamed collection still resolves.

## Adapt notes

- The gate needs a base ref to diff against. When it doesn't resolve, skip the check
  entirely — a review script that degrades open must not start flagging every skill in
  the registry because a remote is missing.
- Exempt external skills (`source`) and overrides (`from`): neither introduces a new
  skill to this tree.
- If your instance also accepts a workspace reference in `SKILL.md` as proof, check it
  against your own rule on citing workspaces from things that must stay current — the
  two conflict, and keeping proof inside the skill dir resolves it without losing a
  usable signal.
- Cover both detection paths — a new declaration in a registry, and a newly added
  `SKILL.md` whose declaration lands in a later commit. Deduplicate by name.
- If your instance keeps the behavioral-test gate in the same script, this hangs off
  it naturally; if the test gate lives in the persist procedure instead, run this as a
  standalone block before the model pass.
