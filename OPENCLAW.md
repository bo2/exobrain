# OpenClaw — exobrain-specific guidance

This file holds OpenClaw-specific guidance. The shared conventions in `AGENTS.md` apply to every agent; the notes below apply only when running under OpenClaw. Claude Code and Codex users see `CLAUDE.md` and `CODEX.md` respectively.

## Tooling primitive names

When `AGENTS.md` or a skill refers to "the agent's primitive for X", map it to the OpenClaw equivalent for file edits, search, and shell. OpenClaw has no separate skill-invocation primitive: `tier: always` skills are linked into its skills dir, and `tier: optional` skills appear in the optional-skills index inside the injected block — read the `SKILL.md` at the path given and follow it inline.

## Exobrain versus OpenClaw memory

Durable, structured knowledge belongs in the exobrain; OpenClaw's own workspace memory holds session scratch and short-lived conversational continuity. Don't let `MEMORY.md` become a second knowledge base.

A memory-consolidation pass is therefore an exobrain review, not a filing exercise: **reconcile rather than append** — correct what a new note contradicts instead of stacking another version of the fact beside it — and once something is promoted, keep no second copy of the synthesis in `MEMORY.md`. Raw notes and routine churn stay in OpenClaw memory to be pruned normally.

## Git history hygiene

Keep this repo's history agent-neutral — omit OpenClaw's default attribution from commit messages and PR bodies. (`validate-exobrain.sh` gates outgoing commit messages for agent-attribution trailers and footers regardless of which agent authored them.)

## Auto-loading

OpenClaw has no `@`-import primitive and auto-loads the root `AGENTS.md` but not the root sidecar, so `scripts/connect-agent.sh openclaw` delivers the rest of the composition into its private `~/.openclaw/workspace/USER.md`, between `<!-- BEGIN exobrain -->` … `<!-- END exobrain -->` markers: this file (`OPENCLAW.md`) if present, then the shared deeper-scope content — every connected scope's `AGENTS.md` (shallow→deep), the OpenClaw-filtered optional-skills index, the tools index, and the knowledge index.

## MCP servers

The default exobrain setup registers MCP servers agent-agnostically — one registration serves every agent. See the per-tool docs under `tools/`. No OpenClaw-specific registration is needed.
