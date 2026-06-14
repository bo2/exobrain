# Tools

A **tool** is an external system an agent reads from or acts on — a calendar, an email account, a GitHub org, a database, an API. Tools are an optional capability layer on top of *browse the repo* and *connect a local agent*; each is independent, and you set up only the subset you need.

This file covers the *concept and machinery*. The catalog itself — which tools exist, what each does, what credentials it needs — is the set of per-tool docs under [`tools/`](../../tools/) plus any group/person/host overlays.

## Why tools are opt-in

Browsing the repo and connecting an agent are one-time: clone, connect, done. Tools are different — each is its own setup, with its own credentials, prerequisites, and verifier. Some are OS-specific; some require a VPN; some require an account another party grants. Making each tool an independent opt-in keeps onboarding from being all-or-nothing: get a working agent first, then add tools as needs arise.

## Catalog vs. state

Two different things, often conflated:

| Concern | Where it lives | Maintained by |
|---|---|---|
| **Catalog** — what tools exist and how they're set up | one markdown doc per tool: `tools/<name>.md` (global) + group/person/host overlays, all tracked | You (or a group) |
| **State** — what's connected on *this* machine | `.exobrain.json` at the repo root, gitignored | Written as you add/refresh tools |

The catalog says *"the calendar tool needs an OAuth token"*; the state says *"calendar is connected on this laptop, verified 2026-06-07."* The catalog is shared truth; the state is per-machine — connecting a tool is an authorization act that differs per host, so it is never committed.

## One doc per tool

Each tool is a single self-contained markdown file, `<name>.md`, where the filename stem is the tool's name. There is no JSON entry and no separate connector doc — the file *is* the connector, and its presence at a scope *is* its registration. The file opens with a one-line purpose and an **At a glance** block, then carries the setup contract:

| Part | Holds |
|---|---|
| **At a glance** | `Prerequisites` (upstream tool names), `Platforms` (`all` or e.g. `darwin`), `Credentials` (where each value lives), `Scripts` (helpers the tool ships), `Use cases` (goal tags) |
| **Prerequisites** | full human setup requirements — accounts, VPN, installs — when non-trivial |
| **Setup** | the steps a human walks through |
| **Verify** | a command (and pass criteria) that proves the tool works; omitted for credential-only tools |
| **Troubleshooting** | the failure modes the maintainer has seen |

The `Credentials` line names *where* each value lives — `.env`, `keychain:<service>`, OAuth (browser flow), `config:<path>`, or SSH — never the value itself. The agent reads these at use-time, never ingesting secrets into context (see [`/AGENTS.md`](../../AGENTS.md) § Security).

## Scopes and resolution

Tools live at every scope, like skills — a file's location is its scope:

| Scope | Location |
|---|---|
| global | `tools/<name>.md` |
| group  | `groups/<g>/tools/<name>.md` |
| person | `people/<id>/tools/<name>.md` |
| host   | `people/<id>/hosts/<host>/tools/<name>.md` |

A user's available tool set is the union across their resolved scopes — global, each connected group, their person and host. On a name collision the deeper scope wins (`global < group < person < host`), the same precedence `scripts/skills-registry.sh` applies to skills. This is how group-specific and host-specific tools appear only where they belong.

The use-case glossary that onboarding maps goals against lives in [`tools/README.md`](../../tools/README.md).

## State: `.exobrain.json`

Gitignored, at the repo root. Holds an **identity** block (person `id`, `hostname`, connected scopes — written by the `connect-agent.sh` wizard) and, optionally, a **tools** block keyed by tool name with per-tool state (`wanted`, `env`, `verify`, `verified_at`). `connect-agent.sh` preserves the tools block when it rewrites identity, so a tool keeps its state even if its doc moves between scopes.

## Connecting a tool

Connecting is per-machine. To connect a tool, follow its doc's **Setup**, then run its **Verify**. A small setup skill can automate this — `add <tool>` / `status` / `refresh <tool>` / `doctor`, discovering tools by globbing the scope locations and reading each doc on demand — but this seed ships only the docs; add such a skill once you maintain more than a couple of tools.

## Adding a new tool

1. **Decide scope.** Useful everywhere → `tools/<name>.md`. Useful only to one group → `groups/<g>/tools/<name>.md`. Personal or machine-specific → the person/host `tools/` directory.
2. **Write the tool doc** following the shape above (and in [`tools/README.md`](../../tools/README.md)): one-line purpose, **At a glance** block, then **Prerequisites / Setup / Verify / Troubleshooting** — omit **Verify** for credential-only tools. Reuse an existing credential where one already covers the system; don't introduce a parallel one.
3. **`.env.example`.** Add any `.env` variables with placeholder values. Keychain/OAuth credentials are documented in the tool doc, not `.env.example`.
4. **Test the flow** from a fresh checkout: walk the doc's Setup, then confirm Verify passes.

The tool doc is the single source — its presence at a scope is its registration. Humans browse `tools/`; a setup skill reads the docs on demand. There is no separate summary table to keep in sync.

## Cross-references

- [`/AGENTS.md`](../../AGENTS.md) → *Tools* — the opt-in rule and per-tool-doc entry point
- [`/tools/`](../../tools/) — the per-tool catalog; [`/tools/README.md`](../../tools/README.md) — primitive overview + use-case glossary
- [`scopes.md`](./scopes.md) — how the scope hierarchy resolves tools alongside skills
