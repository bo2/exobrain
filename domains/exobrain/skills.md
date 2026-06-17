# Skills system

## What a skill is

A **skill** is a directory containing `SKILL.md` (YAML frontmatter — `name`, `description` — plus an optional body) and any helper scripts or references it needs. Each agent auto-loads the `SKILL.md` descriptions of skills present in its skills folder and exposes them through its invocation primitive (e.g. Claude Code's `Skill` tool).

Skills are **inert until declared** — a directory under `skills/` does nothing until some `skills.json` references it.

## Scopes

Skills live at five scopes. Each has its own `skills.json`; resolution merges them **global < group < person < host**, keyed by `(name, scope, owner)`. Highest scope wins the `tier`.

| Scope | `skills.json` location | Skill directories | Put a skill here when… |
|---|---|---|---|
| **global** | `<exobrain>/skills.json` | `<exobrain>/skills/<name>/` | useful everywhere |
| **group** | `groups/<g>/skills.json` | `groups/<g>/skills/<name>/` | useful to everyone in a group |
| **person** | `people/<id>/skills.json` | `people/<id>/skills/<name>/` | useful only to you, any machine |
| **host** | `people/<id>/hosts/<h>/skills.json` | `people/<id>/hosts/<h>/skills/<name>/` | specific to one machine |
| **external** | declared inline in any scope's `skills.json` | fetched into the agent's `skills/<name>.<owner>/` | third-party skill from a public repo |

## Seed-local skills (`seed/`)

The canonical seed keeps skills that operate on **the seed itself** — the `create-instance` generator and the behavioral test harness — under `seed/`, outside the registry. They are **never copied into a rendered instance** (an instance has nothing to generate or test), so they carry no `skills.json` entry and `skills-validate` excludes `seed/` from its declaration and orphan scans. They are not surfaced through the Skill tool; invoke one by reading its `SKILL.md` directly (the bootstrap prompt points a fresh agent at `seed/skills/create-instance/SKILL.md`). A rendered instance has no `seed/` at all.

## Registry shape

Schema: [`/skills.schema.json`](../../skills.schema.json). Each entry is an explicit `(name, scope, owner, tier)` tuple — no implicit inference:

```json
{
  "$schema": "../../skills.schema.json",
  "skills": [
    { "name": "review-pr",  "scope": "person",   "owner": "oleg",  "tier": "always" },
    { "name": "skill-creator", "scope": "external", "owner": "anthropic", "tier": "optional",
      "source": { "repo": "https://github.com/anthropics/skills", "path": "skills/skill-creator", "ref": "main" } }
  ]
}
```

Required: `name`, `scope`, `owner`, `tier`. External entries also need `source.{repo, path, ref}`. Any entry may carry `agent` (string) or `skipAgents` (array) — see § Agent filtering. `scope` + `owner` identify the directory; `tier` controls surfacing.

## Tiers

| Tier | Behavior |
|---|---|
| **`always`** | Symlinked into the agent's skills dir; full `SKILL.md` description auto-loaded; invokable via the Skill tool. |
| **`optional`** | Not auto-loaded. Listed in a generated `optional-skills.md` (name, path, one-line summary). The agent reads `SKILL.md` on demand when the user names it or the request maps to the summary. |
| **`off`** | Shadow an entry inherited from a lower scope; remove any previously linked/fetched artifact. |

## Resolution

`skills_resolve` in [`/scripts/skills-registry.sh`](../../scripts/skills-registry.sh): read every scope's `skills.json` in priority order, emit one row per entry, merge by `(name, scope, owner)` keeping the highest-priority tier. Inspect with `scripts/skills-status.sh`.

## Linker and fetcher

- **Linker** (`connect-agent.sh`): for each `always` in-tree entry, symlink `<agent>/skills/<name>.<scope-owner>/` → the source dir. The suffix lets two scopes supply same-named skills without collision. `optional` / `off` aren't symlinked.
- **Fetcher** ([`/scripts/fetch-external-skills.sh`](../../scripts/fetch-external-skills.sh)): for `external` rows, sparse-clone `source.repo@ref` into `skills/` (always) or `skills-optional/` (optional); `off` removes it. Each install records its ref so reruns are idempotent.

## Agent filtering

| Field | Shape | Semantics |
|---|---|---|
| `agent` | string | Loads ONLY under this agent. Use when the skill depends on one agent's runtime. |
| `skipAgents` | array | Loads for every agent EXCEPT those listed. Use when one agent ships a native equivalent. |

Mutually exclusive; universal skills omit both. A skill tagged `agent: "claude"` is invisible to Codex/OpenClaw — not symlinked, not fetched, not listed. This enforces non-interference.

## Authoring a skill

1. Pick the scope — `people/<id>/skills/` for personal, `groups/<g>/skills/` for shared.
2. Create the directory + `SKILL.md` (frontmatter `name`, `description`; body for usage).
3. Add a registry entry to that scope's `skills.json` (or run `scripts/skills-promote.sh`).
4. `scripts/skills-validate.sh` to confirm it resolves and isn't orphaned.
5. `scripts/connect-agent.sh <agent> --relink`.

### Craft principles

The `description` field **is the trigger** — include the user phrasings that should fire it ("when the user wants to X, asks about Y"), not just a label. Use **progressive disclosure**: keep frontmatter tight (always in context), the body focused (loads on trigger), and push depth into `references/` (loads on demand) and `scripts/` (executable, no loading). **Explain the why** rather than stacking ALL-CAPS MUSTs — today's models generalize from intent. The highest-value check is **with-skill vs. no-skill**: run the same prompt with and without the skill; if outputs match, the skill isn't earning its tokens. Anthropic's `skill-creator` (register it as an external optional skill) holds the well-tested craft — read its `SKILL.md` when authoring; take the principles, not its packaging mechanics.

## File map

| File | Purpose |
|---|---|
| [`/skills.schema.json`](../../skills.schema.json) | Schema for every `skills.json` |
| [`/skills.json`](../../skills.json) | Global registry |
| [`/scripts/skills-registry.sh`](../../scripts/skills-registry.sh) | Resolver (sourced by other scripts) |
| [`/scripts/connect-agent.sh`](../../scripts/connect-agent.sh) | Connector — links, fetches, injects |
| [`/scripts/fetch-external-skills.sh`](../../scripts/fetch-external-skills.sh) | External skill fetcher |
| [`/scripts/skills-status.sh`](../../scripts/skills-status.sh) | Show resolved registry |
| [`/scripts/skills-validate.sh`](../../scripts/skills-validate.sh) | Verify entries vs. directories; flag orphans |
| [`/scripts/skills-promote.sh`](../../scripts/skills-promote.sh) | Edit your person/host `skills.json` |
