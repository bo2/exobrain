# OpenClaw — exobrain-specific guidance

This file holds OpenClaw-specific guidance. The shared conventions in `AGENTS.md` apply to every agent; the notes below apply only when running under OpenClaw. Claude Code and Codex users see `CLAUDE.md` and `CODEX.md` respectively.

## Tooling primitive names

*(Skeleton — fill in as OpenClaw-specific tool primitives are documented in this repo. The Claude Code equivalents are under "Tooling primitive names" in `CLAUDE.md`.)*

## Git history hygiene

Keep this repo's history agent-neutral — omit OpenClaw's default attribution from commit messages and PR bodies. (`validate-exobrain.sh` gates outgoing commit messages for agent-attribution trailers and footers regardless of which agent authored them.)

## Auto-loading

OpenClaw has no `@`-import primitive and auto-loads the root `AGENTS.md` but not the root sidecar, so `scripts/connect-agent.sh openclaw` delivers the rest of the composition into its private `~/.openclaw/workspace/USER.md`, between `<!-- BEGIN exobrain -->` … `<!-- END exobrain -->` markers: this file (`OPENCLAW.md`) if present, then the shared deeper-scope content — every connected scope's `AGENTS.md` (shallow→deep), the OpenClaw-filtered optional-skills index, the tools index, and the domains index.

## MCP servers

The default exobrain setup registers MCP servers agent-agnostically — one registration serves every agent. See the per-tool docs under `tools/`. No OpenClaw-specific registration is needed.
