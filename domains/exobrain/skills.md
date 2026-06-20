# Skills system

## What a skill is

A **skill** is a directory containing `SKILL.md` (YAML frontmatter — `name`, `description` — plus an optional body) and any helper scripts or references it needs. Each agent auto-loads the `SKILL.md` descriptions of skills present in its skills folder and exposes them through its invocation primitive (e.g. Claude Code's `Skill` tool).

Skills are **inert until declared** — a directory under `skills/` does nothing until some `skills.json` references it.

## Declaration vs override

The registry splits **declaring** a skill (it exists here, by this owner, at this recommended tier) from **enabling** it (turning it on for a scope). A `skills.json` holds two record kinds:

- **Declaration** — introduces a skill that lives in *this* scope's `skills/<name>/`. The folder is its home scope, so a declaration has **no scope field**. It carries `owner` (who added it — who to ask; also whose connection auto-enables it), a recommended `tier`, and an optional `force` flag (default off).
- **Override** — references a skill declared in another scope (`from` = that home scope, or `external`) and sets a `tier` for the referencing scope. Use it to opt a skill **in** (any tier) or **out** (`off`).

This means **placement expresses only potential audience.** A skill dropped in a shared scope reaches just its `owner` until someone sets `force: true` — a deliberate, reviewed act (the loud flag name is the social gate). Everyone else discovers it and opts in with an override. `owner` is therefore free to mean "who to ask," because a skill's identity is its location, not an owner key.

## Scopes

Skills live at any scope; each scope's `skills.json` declares skills in its own `skills/` and may override skills from shallower scopes. Resolution merges the connected chain **global < group < person < host**, deepest wins.

| Scope | `skills.json` location | Skill directories |
|---|---|---|
| **global** | `<exobrain>/skills.json` | `<exobrain>/skills/<name>/` |
| **group** | `groups/<g>/skills.json` | `groups/<g>/skills/<name>/` |
| **person** | `people/<id>/skills.json` | `people/<id>/skills/<name>/` |
| **host** | `people/<id>/hosts/<h>/skills.json` | `people/<id>/hosts/<h>/skills/<name>/` |
| **external** | declared inline in any scope's `skills.json` (carries `source`) | fetched into the agent's `skills/<name>.<owner>/` |

## Seed-local skills (`seed/`)

The canonical seed has two seed-local skills under `seed/skills/`, both **seed-only** (never copied into a rendered instance — it has no `seed/` at all):

- **`create-instance`** (the generator) stays *outside* the registry — it bootstraps from an empty dir before any `skills.json` exists, so it carries no declaration; invoke it by reading its `SKILL.md` directly (the bootstrap prompt points a fresh agent there).
- **`seed-tests`** (the seed test driver) *is* declared, in `seed/skills.json`, owned by the `seed/` scope — so it resolves only here, where that scope joins the chain (it never appears in an instance, which has no `seed/`).

`skills-validate` excludes `seed/` from its declaration and orphan scans, so the undeclared `create-instance` isn't flagged (`validate-exobrain` still JSON-checks `seed/skills.json`). The **universal** behavioral suite is *not* seed-local — it's the global `exobrain-tests` skill, which ships into instances so any instance can self-test; `seed-tests` invokes it against the seed's built instance.

## Registry shape

Schema: [`/skills.schema.json`](../../skills.schema.json).

```json
{
  "$schema": "../../skills.schema.json",
  "skills": [
    { "name": "review-pr", "owner": "oleg", "tier": "optional" },
    { "name": "tidy", "owner": "acme", "tier": "always", "force": true },
    { "name": "review-pr", "from": "global", "tier": "always" },
    { "name": "skill-creator", "owner": "anthropic", "tier": "optional",
      "source": { "repo": "https://github.com/anthropics/skills", "path": "skills/skill-creator", "ref": "main" } }
  ]
}
```

- A **declaration** requires `name`, `owner`, `tier` (one of `always`/`optional`/`unlisted`); `force` and `source` are optional (`source.{repo,path,ref}` is required for external skills).
- An **override** requires `name`, `from`, `tier` (may also be `off`); it carries `owner` only when `from: "external"`. The presence of `from` is what marks an entry as an override.
- Any entry may carry `agent` (string) or `skipAgents` (array) — see § Agent filtering.

## Tiers

| Tier | Behavior |
|---|---|
| **`always`** | Symlinked into the agent's skills dir; full `SKILL.md` description auto-loaded; invokable via the Skill tool. |
| **`optional`** | Not auto-loaded. Listed in a generated `optional-skills.md` (name, path, one-line summary). The agent reads `SKILL.md` on demand when the user names it or the request maps to the summary. |
| **`unlisted`** | Registered and invocable **by name**, but absent from every auto-loaded surface — not linked, not in the optional index. For misfire-risk or name-only skills. The agent reaches it only when the user names it or it consults the registry (`skills-status.sh --all`). |
| **`off`** | Override-only. Shadow/disable a skill that would otherwise resolve on (e.g. opt out of a forced shared skill); removes any previously linked/fetched artifact. |

## Resolution

`skills_resolve` in [`/scripts/skills-registry.sh`](../../scripts/skills-registry.sh) reads every connected scope's `skills.json` shallow→deep and, per skill:

- a **declaration** contributes its tier **iff** `force == true` **or** `owner` is one of the connecting user's self ids (a connected person-scope leaf basename);
- an **override** always contributes its tier (including `off`);
- the **deepest** contribution wins; a skill with **no contribution is off**.

So a forced or owned skill resolves on; a non-forced skill someone else declared resolves off until you override it in. Inspect with `scripts/skills-status.sh`.

## Discovery

Because a non-forced declaration is invisible to non-owners, list every declared skill repo-wide with `scripts/skills-status.sh --all` — name, home scope, owner, recommended tier, whether forced, and a one-line description — then opt one in with `scripts/skills-promote.sh <name> --from=<home-scope> --to=<tier>`.

## Linker and fetcher

- **Linker** (`connect-agent.sh`): for each `always` in-tree row, symlink `<agent>/skills/<name>.<home-scope>/` → the source dir. The suffix lets two scopes supply same-named skills without collision. `optional` / `unlisted` / `off` aren't symlinked.
- **Fetcher** ([`/scripts/fetch-external-skills.sh`](../../scripts/fetch-external-skills.sh)): for resolved `external` rows, sparse-clone `source.repo@ref` into `skills/` (always) or `skills-optional/` (optional); `off` removes it. Each install records its ref so reruns are idempotent.

## Agent filtering

| Field | Shape | Semantics |
|---|---|---|
| `agent` | string | Loads ONLY under this agent. Use when the skill depends on one agent's runtime. |
| `skipAgents` | array | Loads for every agent EXCEPT those listed. Use when one agent ships a native equivalent. |

Mutually exclusive; universal skills omit both. A skill tagged `agent: "claude"` is invisible to Codex/OpenClaw — not symlinked, not fetched, not listed. This enforces non-interference.

## Authoring a skill

1. Create the directory + `SKILL.md` (frontmatter `name`, `description`; body for usage) at the right scope — `people/<id>/skills/` for personal, `groups/<g>/skills/` for shared.
2. **Declare** it in that scope's `skills.json`: `{ "name", "owner": "<you>", "tier" }`. It reaches just you until you add `"force": true` (share it scope-wide) — or someone else opts in with an override.
3. To enable a skill declared elsewhere for your scope, add an **override** (or run `scripts/skills-promote.sh <name> --from=<home-scope> --to=<tier>`).
4. `scripts/skills-validate.sh` to confirm it resolves and isn't dangling.
5. `scripts/connect-agent.sh <agent> --relink`.

### Craft principles

The `description` field **is the trigger** — include the user phrasings that should fire it ("when the user wants to X, asks about Y"), not just a label. Use **progressive disclosure**: keep frontmatter tight (always in context), the body focused (loads on trigger), and push depth into `references/` (loads on demand) and `scripts/` (executable, no loading). **Explain the why** rather than stacking ALL-CAPS MUSTs — today's models generalize from intent. The highest-value check is **with-skill vs. no-skill**: run the same prompt with and without the skill; if outputs match, the skill isn't earning its tokens. Anthropic's `skill-creator` (register it as an external optional skill) holds the well-tested craft — read its `SKILL.md` when authoring; take the principles, not its packaging mechanics.

## File map

| File | Purpose |
|---|---|
| [`/skills.schema.json`](../../skills.schema.json) | Schema for every `skills.json` (declarations + overrides) |
| [`/skills.json`](../../skills.json) | Global registry |
| [`/scripts/skills-registry.sh`](../../scripts/skills-registry.sh) | Resolver (sourced by other scripts) |
| [`/scripts/connect-agent.sh`](../../scripts/connect-agent.sh) | Connector — links, fetches, injects |
| [`/scripts/fetch-external-skills.sh`](../../scripts/fetch-external-skills.sh) | External skill fetcher |
| [`/scripts/skills-status.sh`](../../scripts/skills-status.sh) | Show resolved registry; `--all` for the discovery catalog |
| [`/scripts/skills-validate.sh`](../../scripts/skills-validate.sh) | Verify declarations vs. directories; flag dangling overrides |
| [`/scripts/skills-promote.sh`](../../scripts/skills-promote.sh) | Opt in/out (override) or `--force` a declaration |
