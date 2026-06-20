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
| **Claude Code** | Every connected scope's spec composes into one `.claude/AGENTS.override.md`, `@-imported` by the generated `.claude/CLAUDE.md` | Inlined in `AGENTS.override.md` |
| **OpenClaw** | Inlined into `USER.md` via a marker block (`<!-- exobrain --> … <!-- END exobrain -->`) | Inlined in the same block |
| **Codex** | Inlined into `AGENTS.md` via a marker block | Inlined in the same block |

All three deliver the **same composition** — deeper-scope specs (shallow→deep) plus the index, with the global scope auto-loaded separately. Claude `@-imports` one composed file; OpenClaw and Codex inline it via a marker-block rewrite because they lack an import primitive.

## `connect-agent.sh` end-to-end

A single run:

1. **Resolve config** — establish `connected_scopes` + the `person` id from one of four sources, in precedence order: explicit flags (`--handle`/`--host`/`--scope`/`--guest`) > existing/parent `.exobrain.json` > the interactive wizard > guest. Identity is name-matched (handle/hostname → a scope by leaf name); the wizard offers a checkbox menu of connectable scopes with person + host pre-checked.
2. **Resolve the skills registry** — walk every `skills.json` in priority order into a plan.
3. **Link always-tier skills** — symlink each into the agent's skills dir as `<name>.<scope-owner>/`. Most agents read it from their context surface (`.claude/skills`, `~/.openclaw/workspace/skills`); Codex scans a repo-local `.agents/skills`, so its skills link there — out of the global `~/.codex`, scoped to this repo.
4. **Fetch external skills** — route to `skills/` (always) or `skills-optional/` (optional).
5. **Generate `optional-skills.md`** from optional-tier entries.
6. **Compose + inject** — concatenate each connected scope's `AGENTS.md` (+ agent sidecar, shallow→deep) and the optional-skills index into one context surface, then deliver it: Claude `@-imports` the composed `.claude/AGENTS.override.md`; OpenClaw/Codex inline it into a marker block.
7. **Install the post-merge hook** (first run) — re-links every marked agent after `git pull`.
8. **Run scope hooks** — if a scope dir has an executable `scripts/connect-agent.sh`, run it.

`--relink` repeats steps 2–6 without prompting; `--configure` re-resolves identity (the wizard, or the identity flags); `--render-specs-only` runs steps 2–6 and stops before any write outside the target dir (no marker, no hooks) — for wiring a throwaway copy.

## Adding a new agent

To support a fourth agent: pick a marker and a target dir, add a link/inject branch in `connect-agent.sh` (symlink-and-import or marker-block shape), recognize its `<AGENT>.md` sidecar, add it to the agent filter, and document its runtime quirks in the root `<AGENT>.md`. The agent-specific bits extend without touching the universal layer. Test: connect each agent in turn on a fresh clone, confirm none sees another's content.
