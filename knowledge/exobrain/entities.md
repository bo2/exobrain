# Entities

An exobrain holds two kinds of **content** and one kind of **identity**. Anything you add belongs to one of them. Knowing which shapes where it lives, who owns it, and how long it stays current.

## Content: knowledge domains vs. workspaces

| Kind | Where | What it is | Relationship to time |
|---|---|---|---|
| **Knowledge domain** | `knowledge/<area>/` | A bounded area of what you know — a part of your life, a system, a project's facts | **Current truth.** Drift means it owes a refresh. |
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

> **Don't reference workspace files from anything that must stay current** — knowledge domains, skills, agent specs, any auto-loaded context.

Workspace links rot silently: the workspace stays fixed, the world moves, and a reader finds old information presented as current. If a finding turns out durably useful, **promote it** — move the script into a scope's `scripts/`, the fact into a `knowledge/` area, the framework into a skill. The workspace remains as historical provenance ("this originated in `workspaces/…`"); the artifact lives where it gets maintained. Citing a workspace as the *source* of a current fact is fine; citing it *as* the current fact is not.

## Synthesized, not raw

A domain or workspace holds what was made from data; the data itself stays where it belongs (root `AGENTS.md` § Synthesized knowledge, not raw data). Where each kind of material goes:

| Material | Home |
|---|---|
| Synthesis — facts, decisions, current state, analysis, conclusions | The domain or workspace |
| The code and queries that produced it — scripts, SQL, notebooks — and synthetic test fixtures | The workspace, or `scripts/` |
| Small derived results — aggregates, masked or sampled evidence, generated indexes | Beside the synthesis they back |
| Partially processed material no simple call reproduces — search results, a source sweep's findings, reference sets (IDs, links) into another system | `_raw/` |
| Raw data a call can retrieve again — an email, an issue, an API or query result | Its own system; `_raw/` keeps the call (command and parameters) |
| Raw data with a native home — a photo in a synced photo library, a document in a documents tree, a statement at the bank | Its own system; the citing file links it |
| Raw data with no native home — a photo sent in chat, a PDF from a site that won't keep it | A file store: the raw-data folder a connected scope names, in a subfolder mirroring the citing file's repo path; the citing file links it |
| Working copies for processing | A gitignored `_cache/` or `tmp/` |

The scope whose people share the folder names it and the tool that reaches it in its `AGENTS.md` — a person scope for a personal folder, a shared scope for one several people use; until one does, ask the person where such a file should go rather than committing it.

`validate-exobrain.sh` blocks a file in an unambiguously raw format — photos, PDFs, office documents, email and bank exports, GEDCOM, archives, audio, video — newly added under `knowledge/` or `workspaces/`. Files already tracked are left alone. CSV, JSON, and other text formats pass the gate, as do PNG, SVG, and GIF, because they are as often derived as raw (a chart, a recording of the work); for those, the table decides.

## Entry points

Every domain and workspace uses `README.md` as its entry point — for humans browsing and agents loading context alike. There is no `AGENTS.md` at a domain or workspace root; the `README.md` carries that load. The `AGENTS.md` filename is reserved for the auto-loaded spec (repo root) and the optional group/person/host sidecars — see [`agents.md`](agents.md).

## Where to put a new thing

| You're capturing… | It belongs in… |
|---|---|
| Current state of a part of your life, a system, or a project | A **knowledge domain** — `knowledge/<area>/` |
| A reusable agent capability | A **skill** — at the scope that owns it (`skills/`, `people/<id>/skills/`, …) |
| A personal preference or override | The **person** scope — `people/<id>/` |
| Machine-specific config (paths, tunnels, local replicas) | The **host** scope — `people/<id>/hosts/<host>/` |
| The state of an active effort | A **workspace** — `workspaces/YYYY/MM/DD-<slug>/` |
| A throwaway scratch run | `tmp/` (gitignored), not a workspace |
