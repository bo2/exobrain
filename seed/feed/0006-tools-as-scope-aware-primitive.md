---
id: 0006
title: Tools as a scope-aware primitive — one doc per tool, no JSON registry
date: 2026-06-13
tags: [tools, scopes, validation, agents-md]
touches_invariant: true
files: [tools/README.md, tools/example-tool.md, domains/exobrain/tools.md, scripts/validate-exobrain.sh, AGENTS.md, domains/exobrain/scopes.md, skills/exobrain-create/SKILL.md, skills/exobrain-update/SKILL.md]
---

## Problem

A flat `tools.json` catalog is a second registry to keep in sync, with its own
schema and validator branch — separate from the model the repo already uses for
skills (presence at a scope = registration, deeper scope wins). It also forced a
parallel "connector doc" concept and a `_use_case_glossary` the stub didn't even
carry, so the validator checked structure that wasn't there.

## Pattern

Make tools the **same primitive as skills**: one self-contained markdown doc per
tool under `tools/<name>.md`, where the file *is* the connector and its presence
at a scope *is* its registration. No JSON entry, no registration step, no summary
table to drift. Tools resolve across scopes exactly like skills — the union over
resolved scopes, deeper scope wins (`global < group < person < host`). Connection
state stays per-machine in the gitignored `.exobrain.json`. Each doc opens with a
one-line purpose and an **At a glance** block (`Prerequisites / Platforms /
Credentials / Scripts / Use cases`), then `Setup / Verify / Troubleshooting`. The
credentials line names *where* each value lives, never the value.

Because there's no catalog file, the deterministic validator drops its tools.json
branch — there is nothing to schema-check; a tool's presence is its declaration.

## Reference (illustration only)

`tools/README.md` (the primitive overview + use-case glossary) and
`tools/example-tool.md` (a non-functional template) in the seed. The use-case
glossary ships only generic tags (`general`, `engineering`, `analytics`,
`personal`) — extend freely.

## Adapt notes

**Touches the validation contract** (an invariant): the change *removes* the
tools.json check rather than weakening one — sound only because the artifact it
validated no longer exists. Do the migration atomically: delete `tools.json` and
its validator branch together with the doc/skill updates, or the validator will
reference a removed file. **Scope-resolution semantics are preserved** — tools
resolve by the same shallow→deep, deepest-wins rule as skills. Re-point the scope
location table at your own vocabulary (`groups/` vs `teams/`, `domains/` vs your
durable-content dir). Audit everything that named `tools.json`: AGENTS.md, the
scopes resolution table, both create/update skills.
