# Agents

An exobrain serves any AI coding agent — Claude Code, OpenClaw, Codex, others added later. Content is written **universally** by default; agent-specific bits are isolated so they never bleed into another agent's context. This file describes that isolation.

For the skill-loading side of the same machinery, see [`skills.md`](skills.md).

## Supported agents

| Agent | CLI | Marker (in repo) | Per-user config dir |
|---|---|---|---|
| **Claude Code** | `claude` | `.claude/` (directory) | `~/.claude/` |
| **OpenClaw** | `openclaw` | `.openclaw` (file) | `~/.openclaw/workspace/` |
| **Codex** | `codex` | `.codex` (file) | `~/.codex/` |

The marker tells `connect-agent.sh` *"this user wants this agent connected here."* The post-merge git hook re-links each agent that has a marker; agents without one are silently skipped.

## Universal-by-default

Specs, skills, and docs are written so the same content works for every agent — *"the agent reads `SKILL.md`"*, not *"Claude reads `SKILL.md`."* The universal `AGENTS.md` names no primitives; the per-agent sidecars translate. When a skill genuinely depends on one agent's runtime, mark it `agent: "<name>"` in `skills.json`; the opposite-shaped `skipAgents: [...]` excludes specific agents. See [`skills.md`](skills.md) § Agent filtering.

## Per-scope sidecars

At any scope (the repo root, a group/person/host, or a standalone scope like `seed/`), three sidecar filenames are recognized alongside `AGENTS.md`: `CLAUDE.md`, `CODEX.md`, `OPENCLAW.md`. Each loads *only* when `connect-agent.sh` runs for that agent. Use them for tooling-primitive names ("use Edit, not Bash sed"), MCP registration commands, and per-agent quirks. Content that applies under all agents goes in the universal `AGENTS.md` at the same scope — never duplicated into each sidecar.

## Per-scope script suffix

Scripts that depend on a specific agent's runtime use a `<name>.<agent>.sh` suffix. Universal scripts have no suffix. The invoker picks the right variant; `connect-agent.sh` doesn't manage these paths.

## Non-interference — enforced

Isolation is enforced at link and fetch time, not by convention:

- Running `connect-agent.sh codex` puts zero Claude-specific specs, skills, or sidecars in `~/.codex/`.
- The linker skips `CLAUDE.md` / `OPENCLAW.md` sidecars when injecting for Codex.
- The fetcher skips external entries tagged for another agent.
- The generated `optional-skills.md` excludes any skill not visible to the running agent.

The rule: **any agent-specific artifact must be invisible to other agents.** If it isn't, the agent filter is the bug.

## Per-agent injection surface

Each agent pulls auto-loaded specs into its prompt differently; the content is identical across agents.

| Agent | Connected-scope specs | Generated indexes |
|---|---|---|
| **Claude Code** | `.claude/CLAUDE.md` `@-import`s `.claude/connected-scopes.md` — a manifest of `@-import`s to each connected scope's *live* source `AGENTS.md`/sidecar (by reference, not copied) | The same `CLAUDE.md` `@-import`s `.claude/optional-skills.md`, `.claude/tools-index.md`, `.claude/domains-index.md` |
| **Codex** | The whole composition is written to an in-repo, gitignored `AGENTS.override.md`, read natively — it outranks `AGENTS.md` at the same directory level | Inlined in `AGENTS.override.md` |
| **OpenClaw** | Inlined into `USER.md` via a marker block (`<!-- BEGIN exobrain --> … <!-- END exobrain -->`) | Inlined in the same block |

All three deliver the **same content** — each connected scope's specs (shallow→deep) plus the generated indexes — differing in delivery and in how the global scope (root `AGENTS.md`) arrives. Claude `@-import`s a manifest pointing at the *live* source files, so a scope edit shows up without a recompose, and lets the checked-in root `CLAUDE.md` load the global scope; OpenClaw inlines a copy via a marker-block rewrite and relies on its native pickup of the root `AGENTS.md`. Codex is the exception: its `AGENTS.override.md` *replaces* `AGENTS.md`, so the file must be self-contained — the connector inlines the global scope into it rather than leaving it to be auto-loaded.

## `connect-agent.sh` end-to-end

A single run:

1. **Resolve config** — establish `connected_scopes` + the `person` id from one of four sources, in precedence order: explicit flags (`--handle`/`--host`/`--scope`/`--guest`) > existing/parent `.exobrain.json` > the interactive wizard > guest. Identity is name-matched (handle/hostname → a scope by leaf name); the wizard offers a checkbox menu of connectable scopes with person + host pre-checked.
2. **Resolve the skills registry** — walk every `skills.json` in priority order into a plan.
3. **Link always-tier skills** — symlink each into the agent's skills dir as `<name>.<scope-owner>/`. Most agents read it from their context surface (`.claude/skills`, `~/.openclaw/workspace/skills`); Codex scans a repo-local `.agents/skills`, so its skills link there — out of the global `~/.codex`, scoped to this repo.
4. **Fetch external skills** — route to `skills/` (always) or `skills-optional/` (optional).
5. **Generate the indexes** — `optional-skills.md` (optional-tier skills), `tools-index.md` (visible tool docs), `domains-index.md` (domains + their summaries).
6. **Compose + inject** — deliver each connected scope's `AGENTS.md` (+ agent sidecar, shallow→deep) and the generated indexes. Claude writes `.claude/connected-scopes.md` — a manifest of `@-import`s to the live source specs — and a `.claude/CLAUDE.md` that `@-import`s that manifest plus each index; Codex writes the self-contained in-repo `AGENTS.override.md` (root scope and root sidecar inlined, since it replaces `AGENTS.md`); OpenClaw inlines the same specs and indexes into a `USER.md` marker block, with its root sidecar prepended (the root `AGENTS.md` itself loads natively).
7. **Install the post-merge hook** (first run) — re-links every marked agent after `git pull`.
8. **Run scope hooks** — if a scope dir has an executable `scripts/connect-agent.sh`, run it.

`--relink` repeats steps 2–6 without prompting; `--configure` re-resolves identity (the wizard, or the identity flags); `--render-specs-only` runs steps 2–6 and stops before any write outside the target dir (no marker, no hooks) — for wiring a throwaway copy.

## Adding a new agent

To support a fourth agent: pick a marker and a target dir, add a link/inject branch in `connect-agent.sh` (symlink-and-import or marker-block shape), recognize its `<AGENT>.md` sidecar, add it to the agent filter, and document its runtime quirks in the root `<AGENT>.md`. The agent-specific bits extend without touching the universal layer. Test: connect each agent in turn on a fresh clone, confirm none sees another's content.
