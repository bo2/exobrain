# Machinery

A map of the concrete machinery that makes an exobrain work — the scripts, hooks, registries, and gates. One row per artifact: what it does, with a pointer to the topic file that explains it in depth. This is an **index, not a description** — the semantics live in the topic files ([`scopes.md`](scopes.md), [`agents.md`](agents.md), [`skills.md`](skills.md), [`tools.md`](tools.md), [`domains.md`](domains.md), [`authoring.md`](authoring.md), [`propagation.md`](propagation.md)) and in root `AGENTS.md`. Come here for the whole moving-parts surface at a glance; follow the pointer for how each piece works.

Paths are repo-relative. *Generated* artifacts are produced by `connect-agent.sh` and gitignored (under `.claude/`, or the agent's `$TARGET_DIR`); everything else is tracked. Keep this map current when machinery is added or removed — it's part of auditing the surface area of a change.

## Connection & linking

The `connect-agent.sh` ecosystem wires repo content into each agent's context — see [`agents.md`](agents.md).

| Artifact | Role |
|---|---|
| `scripts/connect-agent.sh` | The connector. Resolves identity by name-match from one of four sources — flags (`--handle`/`--host`/`--scope`/`--guest`), existing config, the interactive wizard (checkbox menu, person/host pre-checked), or guest; `--relink` / `--configure` / `--render-specs-only` thereafter. Resolves the skills registry, links always-tier skills, fetches external skills, composes each agent's own context surface, installs the git hooks. |
| `.claude/CLAUDE.md` *(generated)* | Claude's generated entry point — `@-import`s `.claude/connected-scopes.md` + `.claude/optional-skills.md`. (The handcrafted root `CLAUDE.md` is separate and loads the global scope via `@AGENTS.md`.) |
| `.claude/connected-scopes.md` *(generated)* | A manifest of `@-import`s to each connected deeper scope's source `AGENTS.md`/`CLAUDE.md`, shallow→deep — referenced by relative path, not copied, so scope edits show up without a recompose. |
| `.claude/optional-skills.md` *(generated)* | The Claude-filtered optional-skills index. |
| `AGENTS.override.md` *(generated, Codex)* | Codex surface — the full composition (root `AGENTS.md` + root sidecar + deeper-scope specs + index) written to an in-repo, gitignored `AGENTS.override.md`, which Codex reads natively and which outranks `AGENTS.md` at the same directory level (so it must carry the root spec too). |
| `~/.openclaw/workspace/USER.md` *(generated)* | OpenClaw surface — the same composed context inlined between markers, since OpenClaw has no `@-import` primitive. |
| `.claude/` · `.codex` · `.openclaw` | Per-agent markers — which agents this checkout connects. `--relink` silently skips agents without a marker. |
| `.exobrain.json` *(gitignored)* | Saved config: `connected` scope leaves, `agents`, per-tool state. |
| `.agents/skills/` *(generated, Codex)* | Repo-local Codex skills dir (real dir, symlinked children) — keeps exobrain skills out of the global `~/.codex/skills`. |
| `scripts/skills-registry.sh` · `scripts/fetch-external-skills.sh` | Sourced/invoked by the connector — see § Skills system. |
| `seed/skills/seed-tests/scripts/test-connect-agent.sh` | Deterministic connector/registry harness (seed-local, under the `seed-tests` skill) — builds isolated fake exobrains in temp dirs and asserts scope-chain resolution, opt-in skill tiers, flag-driven identity (name-match / guest / extra scope / stored person), the Claude manifest / Codex override surfaces, the tools index, and validator/fetcher plumbing. |
| `skills/exobrain-tests/` · `seed/skills/seed-tests/` | The **behavioral** suite (agent-driven): `exobrain-tests` (global, runs on any instance) + `seed-tests` (seed-only — builds an instance from the seed, then runs the suite against it). See § Skills system. |
| `skills/instance-tests/` | The **real-environment** suite (non-hermetic): fresh Docker machine → clone the instance's origin → connect → healthcheck/validator; optional headless-agent onboarding e2e. Requirements per case; skips when unmet. |

**Verifying a connector/wiring change** (`connect-agent.sh`, `skills-registry.sh`, `fetch-external-skills.sh`, the injection): first run `seed/skills/seed-tests/scripts/test-connect-agent.sh` for the fixture-level logic. Then render a real checkout side-effect-free with `connect-agent.sh <agent> --render-specs-only` (point `CODEX_HOME` / `OPENCLAW_WORKSPACE` at a throwaway dir to render those agents without touching your home config), and spot-check the agent's surface — for Claude that `.claude/connected-scopes.md` + `.claude/optional-skills.md` exist and every manifest `@-import` resolves to a real file; for Codex that the generated in-repo `AGENTS.override.md` holds the expected scopes, for OpenClaw that the marker block in `USER.md` does — plus the `.claude/` and `.agents/skills/` dirs. Finally run `scripts/validate-exobrain.sh` for conventions.

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
| `scripts/validate-exobrain.sh` | Deterministic conventions: `AGENTS.md` placement, file naming, JSON syntax, `scopes.json` shape, the skills registry, agent-neutral outgoing commit messages — plus every connected scope's validator hook (`<scope>/scripts/validate-exobrain.sh`, run with the checkout under validation as `$1`; non-zero exit → its output becomes violations; the gitignored `local/` scope's hook is the private leak scan). | pre-push + manual |
| `scripts/authoring-review.sh` | LLM judgment over changed specs/domains against the authoring rules; self-skips when none changed; degrades open when no agent CLI is installed; skippable with `EXOBRAIN_SKIP_AUTHORING_REVIEW=1`. | `exobrain-persist` (after commit, before push) + manual; not a push-hook gate |
| `scripts/exobrain-healthcheck.sh` | Connection integrity (not-connected / stale links) + trunk freshness (main checkout behind upstream → suggests `git pull --ff-only`; the fetch is throttled and time-boxed, and it never pulls). Read-only; resolves the main checkout from a worktree; always exits 0. | SessionStart + manual |
| `exobrain-authoring-audit` skill | Scopes a new or justification-heavy doc by its readers, tracing each contested fact to a real reader need. | before drafting/revising a substantial doc |

The authoring rules these enforce live in [`authoring.md`](authoring.md) and `AGENTS.md` → "Reader Lens" / "Conventions".

## Skills system

Physical skill directories at any scope, inert until declared in a `skills.json` — see [`skills.md`](skills.md).

| Artifact | Role |
|---|---|
| `skills.json` (root) + per-scope (`<group>/`, `<person>/`, `<host>/`) | Registries. **Declarations** (`name`, `owner`, `tier`, optional `force`) introduce a skill in their own scope; **overrides** (`from` + `tier`) opt one in/out elsewhere. Tiers `always` / `optional` / `unlisted` / `off`; agent filtering via `agent` / `skipAgents`. |
| `skills.schema.json` | Registry schema (declaration/override). |
| `scripts/skills-registry.sh` | Resolver — walks the connected scope chain (`build_scope_chain`), deepest contribution wins; a declaration fires only if forced or owned. |
| `scripts/skills-status.sh` | Show the resolved registry; `--all` catalogs every declared skill for discovery. |
| `scripts/skills-validate.sh` | Verify declarations have directories and overrides reference real declarations. |
| `scripts/skills-promote.sh` | Opt a skill in/out (override) or `--force` a declaration, without hand-editing JSON. |
| `scripts/fetch-external-skills.sh` | Fetch external (third-party) skills declared with `source`. |
| optional-skills index *(generated)* | Index of optional-tier skills, read on demand — `.claude/optional-skills.md` (Claude), or inlined into `AGENTS.override.md` (Codex) / `~/.openclaw/workspace/USER.md` (OpenClaw). |

Global skills the seed ships: `exobrain-ab`, `exobrain-authoring-audit`, `exobrain-domains`, `exobrain-evolve`, `exobrain-persist`, `exobrain-tests`, `exobrain-tools`, `instance-tests`.

## Tools

The per-tool catalog of external data sources — see [`tools.md`](tools.md).

| Artifact | Role |
|---|---|
| `tools/*.md` | The catalog: one self-contained doc per tool (its presence at a scope *is* its registration). The seed ships `tools/README.md` + `tools/example-tool.md` (a template); add a doc per tool you connect, with group/person/host overlays as needed. |
| `.exobrain.json` *(gitignored)* | Per-machine, per-tool connection state (the `tools` block). |
| tools index *(generated)* | Flat catalog of every visible tool doc (name + path + first-line purpose), composed into each agent's surface like the optional-skills index — `.claude/tools-index.md` (Claude), or inlined into `AGENTS.override.md` (Codex) / `~/.openclaw/workspace/USER.md` (OpenClaw). Visibility only; connection stays per-machine in `.exobrain.json`. |
| `exobrain-tools` skill | Drives the catalog: `onboard` / `status` / `add` / `refresh` / `doctor` over the connected scope chain. |

Each tool doc carries its own Setup → Verify procedure; run it by hand, or let the `exobrain-tools` skill drive it (it never reads or stores a secret value).

## Domains

The durable knowledge areas — see [`domains.md`](domains.md).

| Artifact | Role |
|---|---|
| `domains/*/README.md` | Each domain's entry point — frontmatter (`name`, `type`, `curator`, `summary`) + TL;DR + file index. The one-line `summary:` is pulled verbatim into the domains index. |
| domains index *(generated)* | Flat catalog of every domain (name + README path + `summary:`), composed into each agent's surface like the tools index — `.claude/domains-index.md` (Claude), or inlined into `AGENTS.override.md` (Codex) / `~/.openclaw/workspace/USER.md` (OpenClaw). Root-only and unscoped (no tiers/overlays); a pure function of the committed READMEs, regenerated on relink. |
| `exobrain-domains` skill | Builds and maintains domains (`create` / `distill` / `curate` / `update`), including setting and refreshing each README's `summary:`. |

## Git workflow

See `AGENTS.md` → "Git workflow" and the `exobrain-persist` skill.

| Artifact | Role |
|---|---|
| `scripts/create-worktree.sh` | Create a worktree off the default branch — symlinks `.env*` / `.exobrain.json` into it. |
| `src/<repo>/` *(gitignored)* | Clones of external code; `src/exobrain-seed/` is the one fixed name — the seed's update cache for `exobrain-evolve`. |
| `exobrain-persist` skill | The worktree → commit → push → PR → squash-merge → update main → cleanup procedure (a skill + standing authorization, not a script). |

## Periodic jobs

| Artifact | Role |
|---|---|
| `scripts/scheduler.py` | One entry point for the repo's periodic jobs. Jobs declared in per-scope `schedule.json` registries (repo root + any scope dir, the gitignored `local/` included); period-based ticks (`every` = minimum period between run starts); per-job flock so runs never overlap; modes `tick` (cron), `loop` (tmux; re-reads registries each tick), `run <job>`, `status`. State and logs under gitignored `tmp/scheduler/`. |
| `schedule.json` *(per scope, optional)* | `{"jobs": [{"name", "every", "command" (argv, `{ROOT}` expands to the repo root), "timeout", "enabled"}]}` — job names unique across all registries. |

## Agent-agnostic mechanism

How one body of content serves Claude, Codex, and OpenClaw without bleed — see [`agents.md`](agents.md).

| Mechanism | Role |
|---|---|
| Per-scope sidecars `CLAUDE.md` / `CODEX.md` / `OPENCLAW.md` | Agent-specific content at any scope; composed only for the matching agent. |
| `<name>.<agent>.sh` script suffix | Agent-specific script variant; invokers pick the right one. |
| Per-agent surface | Each agent owns its surface and no two write the same file: Claude `@-import`s `.claude/connected-scopes.md` + `.claude/optional-skills.md`; Codex reads a generated in-repo `AGENTS.override.md`; OpenClaw gets the same context inlined into `USER.md` via marker block. |
| Non-interference | The linker and fetcher filter by `agent` / `skipAgents`, so one agent's artifacts never enter another's context. |

## Propagation

How improvements move between this seed and downstream instances — see [`propagation.md`](propagation.md). This repo is the canonical read-target + generator, so it **publishes** rather than adopts.

| Artifact | Role |
|---|---|
| `seed/feed/` | The published changelog — dated pattern-cards (a problem, a pattern, the files it touches, adapt notes) that instances read (from the seed cache) to adopt. Seed-only; never copied into an instance. |
| `exobrain-evolve` skill | The command an instance runs to move forward: fetch the seed into `src/exobrain-seed/`, diff the feed against its own adoption ledger, copy/re-synthesize each new card, record what it adopted. |

A downstream instance keeps an adoption ledger (`adopted-feed.md` at its repo root) of the card IDs it has taken; the seed, as the source, keeps none.

## Behavioral rules

The rules that *drive* several of these gates — Reader Lens, propose-a-tool, validate-the-request, audit-the-surface-area, worktree-first, auto-persist — live in root `AGENTS.md`. They're auto-loaded, so every agent carries them; this map covers the machinery they trigger.
