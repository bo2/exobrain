# Codex — exobrain-specific guidance

This file holds Codex-specific guidance. The shared conventions in `AGENTS.md` apply to every agent; the notes below apply only when running under Codex. Claude Code and OpenClaw users see `CLAUDE.md` and `OPENCLAW.md` respectively.

## Tooling primitive names

When `AGENTS.md` or a skill refers to "the agent's primitive for X", map it to the Codex equivalent — file edits through its patch/apply mechanism, search and shell through its command tool. Codex has no separate skill-invocation primitive: `tier: always` skills are linked into `.agents/skills/`, and `tier: optional` skills appear in the optional-skills index inside `AGENTS.override.md` — read the `SKILL.md` at the path given and follow it inline.

## Git history hygiene

Keep this repo's history agent-neutral — omit Codex's default attribution from commit messages and PR bodies. (`validate-exobrain.sh` gates outgoing commit messages for agent-attribution trailers and footers regardless of which agent authored them.)

## Auto-loading

Codex has no `@`-import primitive, so its whole context is composed into one file. `scripts/connect-agent.sh codex` generates a gitignored, per-machine **`AGENTS.override.md`** at the repo root: the root `AGENTS.md`, then this file (`CODEX.md`) if present, then the shared deeper-scope content — every connected scope's `AGENTS.md` (shallow→deep), the Codex-filtered optional-skills index, the tools index, and the knowledge index. Codex reads it natively — an `AGENTS.override.md` outranks a plain `AGENTS.md` at the same directory level — so the composed file wins over the checked-in root `AGENTS.md` (whose content the override already contains).

Skills link into the repo-local `.agents/skills/` (Codex scans `.agents/skills` from the cwd up to the repo root), not the global `~/.codex/skills`. Nothing exobrain-specific is written under `~/.codex/` except the `config.toml` line that disables Codex's own memory (context comes from the override instead). Launch Codex inside the exobrain repo so it discovers `AGENTS.override.md` and `.agents/skills/`.

## MCP servers

The default exobrain setup registers MCP servers agent-agnostically — one registration serves every agent. See the per-tool docs under `tools/`. No Codex-specific registration is needed.
