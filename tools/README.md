# Tools

A **tool** is an external system an agent reads from or acts on — a calendar, an email account, a GitHub org, a database, an API. Tools are an optional capability layer on top of *browse the repo* and *connect a local agent*; each is independent, and you set up only the subset you need.

This directory is the catalog: **one self-contained markdown file per tool**, `<name>.md`, holding everything needed to set it up, verify it, and troubleshoot it. The filename stem is the tool's name. There is no JSON registry and no registration step — a file's presence at a scope *is* its declaration.

## Scopes

Tools live at every scope, exactly like skills — a tool file's location is its scope:

| Scope | Location |
|---|---|
| global | `tools/<name>.md` (this directory) |
| group  | `groups/<g>/tools/<name>.md` |
| person | `people/<id>/tools/<name>.md` |
| host   | `people/<id>/hosts/<host>/tools/<name>.md` |

An agent's available tool set is the union of all tool files visible across its resolved scopes — global plus each connected group, person, and host. On a name collision the deeper scope wins (`global < group < person < host`), mirroring skills resolution in `scripts/skills-registry.sh`.

## Connecting a tool

Connecting is a per-machine act — credentials, VPN, and OS differ per host — so connection state lives in the untracked, machine-local `.exobrain.json` at the repo root, never committed. To connect a tool, follow its doc's **Setup**, then run its **Verify** — or let the `exobrain-tools` skill drive it (`onboard` / `status` / `add <tool>` / `refresh <tool>` / `doctor`), which discovers tools by globbing these scope locations, reads each doc on demand, and tracks per-tool state in `.exobrain.json`.

## Each tool file

```
# <Tool Name>
<one-line purpose>

## At a glance
- **Prerequisites:** <upstream tools, or "none">
- **Platforms:** <all | macOS only (darwin)>
- **Credentials:** <where values live: .env, keychain:<svc>, OAuth (browser), config:<path>, SSH, or none>
- **Scripts:** <helper scripts the tool ships, or none>
- **Reach:** <read-only | private write | public-capable — can it publish beyond this exobrain's people?>
- **Use cases:** <glossary tags>

## Prerequisites   — full human setup requirements, when non-trivial
## Setup           — steps a human walks through
## Verify          — command + pass criteria (omit for credential-only tools)
## Troubleshooting — known failure modes
```

The credential line names *where* each value lives, never the value itself — the agent reads it at use-time and never ingests a secret into context (see [`/AGENTS.md`](../AGENTS.md) § Security).

The **Reach** line flags publishing power: a `public-capable` tool can put content on the open internet (a public repo write, a public page or post, mail to outsiders), so every publish through it falls under the per-publish confirmation rule in [`/AGENTS.md`](../AGENTS.md) § Security — the doc should say which of its operations are public-capable and default to the gated variant.

The `<one-line purpose>` directly under the heading is pulled verbatim into the generated **tools index** that `connect-agent.sh` composes into each agent's auto-loaded context (so the agent knows the tool exists and reaches for its doc). Keep it a complete, self-contained one-liner — a wrapped or buried first line yields a useless index row.

## Use-case glossary

Onboarding maps a stated goal to tools via each file's `Use cases` tags. Keep the vocabulary small and extend it as needs arise:

| Tag | Meaning |
|---|---|
| `general` | Wanted by most setups regardless of role — basic context, status, lookups. |
| `engineering` | Code work — pull requests, issues, code search, automation. |
| `analytics` | Data/warehouse queries, dashboards, metrics. |
| `personal` | Home, finance, calendar, email, and other personal-life systems. |

## Adding a tool

1. **Pick the scope.** Useful everywhere → `tools/<name>.md` (here). One group → `groups/<g>/tools/<name>.md`. Personal or machine-specific → the person/host `tools/` directory.
2. **Write `<name>.md`** following the shape above. Reuse an existing credential where one already covers the system — don't introduce a parallel one.
3. **`.env.example`** — add any `.env` variables with placeholder values. Keychain/OAuth credentials are documented in the tool file, not `.env.example`.
4. **Confirm** the doc's **Verify** step passes from a fresh setup.

See [`domains/exobrain/tools.md`](../domains/exobrain/tools.md) for the concept and machinery. `example-tool.md` here is a non-functional template — copy it as a starting point, or delete it once you have real tools.
