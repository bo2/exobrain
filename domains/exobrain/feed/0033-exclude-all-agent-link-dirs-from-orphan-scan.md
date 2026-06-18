---
id: 0033
title: Exclude every agent backend's linker-output dir from skill orphan validation
date: 2026-06-18
tags: [skills, scripts, validation, multi-agent]
touches_invariant: false
files: [scripts/skills-validate.sh]
---

## Problem

The skill registry validator warns about "orphan" skill directories — dirs under a `skills/` folder that no `skills.json` declares. To avoid flagging generated output, it excludes the agent's linker-output directory (where the connector symlinks the resolved always-tier skills). But the exclusion list named only the first agent backend's output dir. When a second backend gets its own repo-local link target, the validator keeps scanning it, so every skill that backend links surfaces as a false-positive orphan — burying the genuine orphans (real source dirs no registry references) and making the validator untrustworthy.

## Pattern

The orphan scan must skip **every** agent backend's linker-output directory, not just one. Treat "agent link targets" as a set that grows whenever a new backend is supported, and keep the validator's exclusion list in sync with that set. The principle generalizes: a validator that walks the tree for generated content must exclude all generated-output locations, or each location it forgets becomes its own class of false positives.

## Reference (illustration only)

Both `find` invocations (the `skills.json` scan and the `skills/`-dir scan) carry the same exclusion list; add each agent's repo-local link dir alongside the existing one:

```sh
find "$REPO_DIR" -type d -name skills \
    -not -path "$REPO_DIR/.claude/*" -not -path "$REPO_DIR/.agents/*" \
    -not -path "$REPO_DIR/src/*" ...
```

## Adapt notes

- Keep the two `find` exclusion lists identical — they must agree on what counts as generated output.
- The fix excludes generated symlink dirs only; the real integrity checks (every registry entry resolves to a source `SKILL.md`; every source skill dir is declared) are unchanged.
- When you add a new agent backend with its own repo-local skills-link target, extend this list in the same change — otherwise its linked skills reappear as orphans. A backend that links into a *global* dir outside the repo tree needs no exclusion (the repo walk never reaches it).
