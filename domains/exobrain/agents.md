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

At any scope (global root, group, person, host), three sidecar filenames are recognized alongside `AGENTS.md`: `CLAUDE.md`, `CODEX.md`, `OPENCLAW.md`. Each loads *only* when `connect-agent.sh` runs for that agent. Use them for tooling-primitive names ("use Edit, not Bash sed"), MCP registration commands, and per-agent quirks. Content that applies under all agents goes in the universal `AGENTS.md` at the same scope — never duplicated into each sidecar.

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

| Agent | Universal + sidecar injection | Optional-skills index |
|---|---|---|
| **Claude Code** | Symlinks `AGENTS.<scope>.md` / `CLAUDE.<scope>.md` into `.claude/`; root `CLAUDE.md` `@-imports` each | `@optional-skills.md` line in `CLAUDE.md` |
| **OpenClaw** | Inlined into `USER.md` via a marker block (`<!-- exobrain --> … <!-- END exobrain -->`) | Inlined in the same block |
| **Codex** | Inlined into `AGENTS.md` via a marker block | Inlined in the same block |

Claude's `@-import` composes; OpenClaw and Codex use a marker-block rewrite because they lack an import primitive.

## `connect-agent.sh` end-to-end

A single run:

1. **Resolve config** — read `.exobrain.json` (or run the wizard): person `id`, connected groups (if any), `hostname`.
2. **Resolve the skills registry** — walk every `skills.json` in priority order into a plan.
3. **Link always-tier skills** — symlink each into the agent's `skills/<name>.<scope-owner>/`.
4. **Link sidecar specs** — per scope, symlink `AGENTS.<scope>.md` and the matching `<AGENT>.<scope>.md`.
5. **Fetch external skills** — route to `skills/` (always) or `skills-optional/` (optional).
6. **Generate `optional-skills.md`** from optional-tier entries.
7. **Inject** into the agent surface (Claude `@-imports`; OpenClaw/Codex marker block).
8. **Install the post-merge hook** (first run) — re-links every marked agent after `git pull`.
9. **Run scope hooks** — if a scope dir has an executable `scripts/connect-agent.sh`, run it.

`--relink` repeats steps 2–7 without prompting; `--configure` re-runs the wizard.

## Adding a new agent

To support a fourth agent: pick a marker and a target dir, add a link/inject branch in `connect-agent.sh` (symlink-and-import or marker-block shape), recognize its `<AGENT>.md` sidecar, add it to the agent filter, and document its runtime quirks in the root `<AGENT>.md`. The agent-specific bits extend without touching the universal layer. Test: connect each agent in turn on a fresh clone, confirm none sees another's content.
