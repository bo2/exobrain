# Scopes

A **scope** is a level at which wiring (skills, tools, agent specs, scripts) can live. The same kind of content can exist at several scopes; deeper scopes override shallower ones at link time.

Scopes apply to the **identity** side of an exobrain. Domains and workspaces are content, not scopes — see [`entities.md`](entities.md).

## A scope is any directory with an AGENTS.md

The presence of an `AGENTS.md` is the **scope flag**: any directory containing one is a scope. The repo root is the implicit `global` scope. No registry is needed to *identify* a scope — drop an `AGENTS.md` (even a one-line stub) into a directory and it's a scope. Non-scope directories (collection dirs like `people/`, `hosts/`) carry no `AGENTS.md` and are skipped.

This matches the convention that every scope already carries an `AGENTS.md`; it just makes that file load-bearing.

## Scope types and nesting

Scopes nest by **literal directory containment**. A scope dir may contain more scope dirs; the path expresses the tree:

```
people/alex/hosts/laptop/            # person → host          (no group)
groups/acme/teams/ads/people/alex/   # group → team → person  (deep org)
```

A scope's **type** (person / group / team / host / …) is cosmetic — inferred from its parent collection dir, with optional nicer labels in `scopes.json`:

```json
{ "scopes": [ { "type": "person", "collection": "people" },
              { "type": "host",   "collection": "hosts" } ] }
```

"Any other type when needed" = make a directory with an `AGENTS.md`. `scopes.json` is metadata, never identification.

## The local scope

`local/` at the repo root is a standalone **gitignored** scope for private context that must never land in the repo — org identifiers, internal hostnames, anything unpublishable. Every *tracked* scope (person and group included) is visible to anyone with repo access; `local/` is the one layer that stays on the machine. It is an ordinary scope in every other way — an `AGENTS.md` dir, connected as a leaf, resolved through the same walk. Because it is not a person-type scope, a setup that connects only `local/` carries no person id in its chain — set `person` in `.exobrain.json` so skill owner-match still works.

## Connection and resolution

`.exobrain.json` (gitignored, per machine) stores `connected_scopes` — a list of **leaf** scope paths — and `person`, your id (used for skill owner-match, so it's location-independent of where the person scope sits):

```json
{ "connected_scopes": ["people/alex/hosts/laptop"], "person": "alex", "agents": ["claude"] }
```

Connecting a leaf implies its whole ancestor chain. The wiring algorithm:

1. For each connected leaf, the **scope chain** is the repo root plus every ancestor dir down to the leaf that contains an `AGENTS.md`.
2. Union chains across leaves, dedup shared prefixes, sort **shallow → deep**.
3. Resolve skills / specs / tools across that ordered list, **deepest wins**.

The old fixed ladder (`global < team < person < host`) is just one chain shape. Solo, family, and org trees all flow through the same walk. Empty `connected_scopes` = guest mode (global only).

A connected leaf can be **any** scope — any `AGENTS.md`-bearing dir — not only a person/host pinpoint scope or one on a single branch. Because chains are unioned, you may list several leaves on different branches and even a standalone top-level scope (e.g. a `seed/` scope) alongside your person/host chain; each joins resolution at its own depth, deepest still winning.

The connector resolves identity by **name-match** — your handle and hostname match a scope by its leaf name (the `people/`·`hosts/` parent is a tiebreaker, not a requirement). The interactive wizard scaffolds the person/host pair when absent, then offers a checkbox menu of every connectable scope with person + host pre-checked, so connecting a standalone scope is a toggle, not a hand-edit. Non-interactive callers pass identity as flags — `--handle` / `--host` / `--scope` / `--guest` — and flags **never scaffold**: they connect the deepest existing scope for the handle (host leaf, else person), or nothing but `--scope`, with a notice. Scripted setups (`create-instance`, CI) create their scope dirs first, then connect.

## What we explicitly do NOT scope

| Would-be scope | Why | Where that content lives |
|---|---|---|
| **Instance** | A single agent run is too short-lived to track | Local untracked files in the working dir |
| **Repository** | Knowledge about a codebase belongs with the code | That repo's own `AGENTS.md` |

## Resolution across systems

| System | What merges | How |
|---|---|---|
| **Skills** | Per-`(name, scope, owner)` tier (`always`/`optional`/`off`) | `skills_resolve` in `scripts/skills-registry.sh` |
| **Sidecar specs** | Each scope's `AGENTS.md` + agent sidecar, linked side by side; the agent reads all | `scripts/connect-agent.sh` |
| **Tools catalog** | Per-tool docs `tools/<name>.md` + group/person/host overlays (by tool name) | globbed by scope; deeper scope wins |

Skills are the only resolver that uses `off` to actively shadow a shallower scope; sidecars and tool overlays merge additively. The `scope` value of a skill entry is the scope's repo-relative path (or `global` / `external`), so the same skill name at two scopes never collides — they link with distinct path-derived suffixes (`name.people__alex`).

## How to override

You don't edit a shallower scope — you add a deeper, higher-priority entry that wins resolution:

```bash
scripts/skills-promote.sh <skill> --scope=<path> --owner=<id> --to=always
scripts/connect-agent.sh <agent> --relink
```

For sidecar specs you *add* a scope's `AGENTS.md` / agent sidecar; `connect-agent.sh` links it next to the others and the agent reads both.

## What goes at which scope

Bias toward the **lowest scope a thing fits**. A skill you wrote for yourself starts at your person scope; if a housemate adopts it, *then* promote it to a shared group. Premature group-scoping turns a shared dir into a graveyard of one-person utilities.
