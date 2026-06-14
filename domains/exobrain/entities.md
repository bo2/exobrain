# Entities

An exobrain holds two kinds of **content** and one kind of **identity**. Anything you add belongs to one of them. Knowing which shapes where it lives, who owns it, and how long it stays current.

## Content: domains vs. workspaces

| Kind | Where | What it is | Relationship to time |
|---|---|---|---|
| **Domain** | `domains/<area>/` | A bounded area of what you know — a part of your life, a system, a project's facts | **Current truth.** Drift means it owes a refresh. |
| **Workspace** | `workspaces/YYYY/MM/DD-<slug>/` | A time-bound effort — a trip, a renovation, a job search, an investigation | **Point-in-time record.** Outdates by design once the effort ends. |

These are not a layering — they're different *kinds* of context pulled in for different reasons. Different reading patterns demand different update contracts:

- *"What's my current mortgage rate and renewal date?"* needs current truth → a **domain** read; the answer must reflect today.
- *"Why did I pick this contractor back in March?"* needs the contemporaneous reasoning, not a sanitized current view → a **workspace** read.

Collapsing them breaks one contract or the other: a workspace written under the currency rule loses its historical value; a domain written under the staleness rule misleads, presenting old facts as current.

## Identity: people and groups

| Kind | Where | What it is |
|---|---|---|
| **Person** | `people/<id>/` | One individual — their preferences, skills, tools, and machines. Solo exobrains have exactly one. |
| **Group** *(optional)* | `groups/<name>/` | A shared scope for several people — household, family, collaborators. Holds shared skills/scripts/conventions and its own `people/`. An organization calls these "teams." |

A person lives at top-level `people/<id>/` and needs **no group**. Add a group only when more than one person shares context. See [`scopes.md`](scopes.md) for how these overlay.

## Promote, don't link

The rule most easily violated:

> **Don't reference workspace files from anything that must stay current** — domains, skills, agent specs, any auto-loaded context.

Workspace links rot silently: the workspace stays fixed, the world moves, and a reader finds old information presented as current. If a finding turns out durably useful, **promote it** — move the script into a scope's `scripts/`, the fact into a `domains/` area, the framework into a skill. The workspace remains as historical provenance ("this originated in `workspaces/…`"); the artifact lives where it gets maintained. Citing a workspace as the *source* of a current fact is fine; citing it *as* the current fact is not.

## Entry points

Every domain and workspace uses `README.md` as its entry point — for humans browsing and agents loading context alike. There is no `AGENTS.md` at a domain or workspace root; the `README.md` carries that load. The `AGENTS.md` filename is reserved for the auto-loaded spec (repo root) and the optional group/person/host sidecars — see [`agents.md`](agents.md).

## Where to put a new thing

| You're capturing… | It belongs in… |
|---|---|
| Current state of a part of your life, a system, or a project | A **domain** — `domains/<area>/` |
| A reusable agent capability | A **skill** — at the scope that owns it (`skills/`, `people/<id>/skills/`, …) |
| A personal preference or override | The **person** scope — `people/<id>/` |
| Machine-specific config (paths, tunnels, local replicas) | The **host** scope — `people/<id>/hosts/<host>/` |
| The state of an active effort | A **workspace** — `workspaces/YYYY/MM/DD-<slug>/` |
| A throwaway scratch run | `tmp/` (gitignored), not a workspace |
