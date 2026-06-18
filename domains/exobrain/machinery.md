# Machinery

A map of the concrete machinery that makes an exobrain work — the scripts, hooks, registries, and gates. One row per artifact: what it does, with a pointer to the topic file that explains it in depth. This is an **index, not a description** — the semantics live in the topic files ([`scopes.md`](scopes.md), [`agents.md`](agents.md), [`skills.md`](skills.md), [`tools.md`](tools.md), [`domains.md`](domains.md), [`authoring.md`](authoring.md), [`propagation.md`](propagation.md)) and in root `AGENTS.md`. Come here for the whole moving-parts surface at a glance; follow the pointer for how each piece works.

Paths are repo-relative. *Generated* artifacts are produced by `connect-agent.sh` and gitignored (under `.claude/`, or the agent's `$TARGET_DIR`); everything else is tracked. Keep this map current when machinery is added or removed — it's part of auditing the surface area of a change.

## Connection & linking

The `connect-agent.sh` ecosystem wires repo content into each agent's context — see [`agents.md`](agents.md).

| Artifact | Role |
|---|---|
| `scripts/connect-agent.sh` | The connector. Interactive wizard on first run; `--relink` / `--configure` / `--render-specs-only` thereafter. Resolves config + the skills registry, links always-tier skills, fetches external skills, composes each agent's own context surface, installs the git hooks. |
| `.claude/CLAUDE.md` *(generated)* | Claude's generated entry point — `@-import`s `.claude/connected-scopes.md` + `.claude/optional-skills.md`. (The handcrafted root `CLAUDE.md` is separate and loads the global scope via `@AGENTS.md`.) |
| `.claude/connected-scopes.md` *(generated)* | A manifest of `@-import`s to each connected deeper scope's source `AGENTS.md`/`CLAUDE.md`, shallow→deep — referenced by relative path, not copied, so scope edits show up without a recompose. |
| `.claude/optional-skills.md` *(generated)* | The Claude-filtered optional-skills index. |
| `~/.codex/AGENTS.md` · `~/.openclaw/workspace/USER.md` *(generated)* | Codex / OpenClaw surfaces — the same composed context (root sidecar + deeper-scope specs + index) inlined between markers, since neither has an `@-import` primitive. |
| `.claude/` · `.codex` · `.openclaw` | Per-agent markers — which agents this checkout connects. `--relink` silently skips agents without a marker. |
| `.exobrain.json` *(gitignored)* | Saved config: `connected` scope leaves, `agents`, per-tool state. |
| `.agents/skills/` *(generated, Codex)* | Repo-local Codex skills dir (real dir, symlinked children) — keeps exobrain skills out of the global `~/.codex/skills`. |
| `scripts/skills-registry.sh` · `scripts/fetch-external-skills.sh` | Sourced/invoked by the connector — see § Skills system. |

**Verifying a connector/wiring change** (`connect-agent.sh`, `skills-registry.sh`, `fetch-external-skills.sh`, the injection): render a real checkout side-effect-free with `connect-agent.sh <agent> --render-specs-only` (point `CODEX_HOME` / `OPENCLAW_WORKSPACE` at a throwaway dir to render those agents without touching your home config), then spot-check the agent's surface — for Claude that `.claude/connected-scopes.md` + `.claude/optional-skills.md` exist and every manifest `@-import` resolves to a real file; for Codex/OpenClaw that the marker block in `AGENTS.md` / `USER.md` holds the expected scopes — plus the `.claude/` and `.agents/skills/` dirs. Then run `scripts/validate-exobrain.sh` for conventions.

## Git hooks

Installed by `connect-agent.sh`, refreshed idempotently on every relink.

| Hook | Runs |
|---|---|
| `post-merge` | `connect-agent.sh <agent> --relink` for each connected agent after a fast-forward/merge `git pull`. |
| `post-rewrite` | The same relink after a rebase-based pull (`git pull --rebase`); guarded to skip plain `commit --amend`. |
| `pre-push` | `scripts/validate-exobrain.sh` (deterministic) — blocks the push on a violation. |

## Session hooks (Claude)

| Hook | Runs |
|---|---|
| `SessionStart` (committed `.claude/settings.json`) | `scripts/exobrain-healthcheck.sh` — warns if the agent isn't connected or its links are stale, and relays the suggested `connect-agent.sh` command. Read-only, advisory. See `AGENTS.md` → "Setup and relink safety". |

## Validation & quality gates

| Gate | Checks | When |
|---|---|---|
| `scripts/validate-exobrain.sh` | Deterministic conventions: `AGENTS.md` placement, file naming, JSON syntax, `scopes.json` shape, the skills registry. | pre-push + manual |
| `scripts/authoring-review.sh` | On-demand LLM judgment over changed specs/domains against the authoring rules; degrades open when no agent CLI is installed; skippable with `EXOBRAIN_SKIP_AUTHORING_REVIEW=1`. | manual (not a push gate) |
| `scripts/exobrain-healthcheck.sh` | Connection integrity (not-connected / stale links). Read-only; resolves the main checkout from a worktree; always exits 0. | SessionStart + manual |
| `exobrain-reader-lens` skill | Scopes a new or justification-heavy doc by its readers, tracing each contested fact to a real reader need. | before drafting/revising a substantial doc |

The authoring rules these enforce live in [`authoring.md`](authoring.md) and `AGENTS.md` → "Reader Lens" / "Conventions".

## Skills system

Physical skill directories at any scope, inert until declared in a `skills.json` — see [`skills.md`](skills.md).

| Artifact | Role |
|---|---|
| `skills.json` (root) + per-scope (`<group>/`, `<person>/`, `<host>/`) | Registries. Each entry is `(name, scope, owner, tier)`; tiers `always` / `optional` / `off`; agent filtering via `agent` / `skipAgents`. |
| `skills.schema.json` | Registry schema. |
| `scripts/skills-registry.sh` | Resolver — walks the connected scope chain (`build_scope_chain`), deepest scope wins. |
| `scripts/skills-status.sh` | Show the resolved registry for a checkout. |
| `scripts/skills-validate.sh` | Verify registry entries match real directories; flag orphans. |
| `scripts/skills-promote.sh` | Edit personal/host tiers without hand-editing JSON. |
| `scripts/fetch-external-skills.sh` | Fetch `scope: external` (third-party) skills. |
| optional-skills index *(generated)* | Index of optional-tier skills, read on demand — `.claude/optional-skills.md` (Claude) or inlined into `~/.codex/AGENTS.md` / `~/.openclaw/workspace/USER.md`. |

Global skills the seed ships: `exobrain-ab`, `exobrain-domains`, `exobrain-evolve`, `exobrain-persist`, `exobrain-reader-lens`.

## Tools

The per-tool catalog of external data sources — see [`tools.md`](tools.md).

| Artifact | Role |
|---|---|
| `tools/*.md` | The catalog: one self-contained doc per tool (its presence at a scope *is* its registration). The seed ships `tools/README.md` + `tools/example-tool.md` (a template); add a doc per tool you connect, with group/person/host overlays as needed. |
| `.exobrain.json` *(gitignored)* | Per-machine, per-tool connection state. |

Each tool doc carries its own Setup → Verify procedure; run it by hand (credentials make the human drive setup).

## Git workflow

See `AGENTS.md` → "Git workflow" and the `exobrain-persist` skill.

| Artifact | Role |
|---|---|
| `scripts/create-worktree.sh` | Create a worktree off the default branch — symlinks `.env*` / `.exobrain.json` into it. |
| `src/<repo>/` *(gitignored)* | Clones of external code; `src/exobrain-seed/` is the one fixed name — the seed's update cache for `exobrain-evolve`. |
| `exobrain-persist` skill | The worktree → commit → push → PR → squash-merge → update main → cleanup procedure (a skill + standing authorization, not a script). |

## Agent-agnostic mechanism

How one body of content serves Claude, Codex, and OpenClaw without bleed — see [`agents.md`](agents.md).

| Mechanism | Role |
|---|---|
| Per-scope sidecars `CLAUDE.md` / `CODEX.md` / `OPENCLAW.md` | Agent-specific content at any scope; composed only for the matching agent. |
| `<name>.<agent>.sh` script suffix | Agent-specific script variant; invokers pick the right one. |
| Per-agent surface | Each agent owns its surface and no two write the same file: Claude `@-import`s `.claude/connected-scopes.md` + `.claude/optional-skills.md`; Codex / OpenClaw get the same context inlined into `~/.codex/AGENTS.md` / `USER.md` via marker block. |
| Non-interference | The linker and fetcher filter by `agent` / `skipAgents`, so one agent's artifacts never enter another's context. |

## Propagation

How improvements move between this seed and downstream instances — see [`propagation.md`](propagation.md). This repo is the canonical read-target + generator, so it **publishes** rather than adopts.

| Artifact | Role |
|---|---|
| `domains/exobrain/feed/` | The published changelog — dated pattern-cards (a problem, a pattern, the files it touches, adapt notes) that instances read to adopt. |
| `exobrain-evolve` skill | The command an instance runs to move forward: fetch the seed into `src/exobrain-seed/`, diff the feed against its own adoption ledger, copy/re-synthesize each new card, record what it adopted. |

A downstream instance keeps an adoption ledger of the card IDs it has taken; the seed, as the source, keeps none.

## Behavioral rules

The rules that *drive* several of these gates — Reader Lens, propose-a-tool, validate-the-request, audit-the-surface-area, worktree-first, auto-persist — live in root `AGENTS.md`. They're auto-loaded, so every agent carries them; this map covers the machinery they trigger.
