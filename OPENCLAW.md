# OpenClaw — exobrain-specific guidance

This file holds OpenClaw-specific guidance. The shared conventions in `AGENTS.md` apply to every agent; the notes below apply only when running under OpenClaw. Claude Code and Codex users see `CLAUDE.md` and `CODEX.md` respectively.

## Tooling primitive names

When `AGENTS.md` or a skill refers to "the agent's primitive for X", map it to the OpenClaw equivalent for file edits, search, and shell. OpenClaw has no separate skill-invocation primitive: `tier: always` skills are linked into its skills dir, and `tier: optional` skills appear in the optional-skills index inside the injected block — read the `SKILL.md` at the path given and follow it inline.

## Answer from the exobrain, not cold

A short personal follow-up is a request for recorded context even when it names no domain: "we", "our", "my", something the person "already" has, a household member, a recorded possession, event, or preference. Retrieve before asking — the knowledge index picks the likely domain, its `README.md` comes first, then the domain's content, then `workspaces/` for provenance. Ask the person to restate a provider, product, file, event, or preference only after retrieval fails, and say what was checked. An impersonal general-knowledge request with no dependency on their world is exempt.

## Skills are exobrain files

Every skill this agent sees is an exobrain repo file, scripts included — change one the way any exobrain file changes: through the normal review, into the skill that governs it or a new skill declared in `skills.json`, never into a workspace proposal. OpenClaw's own Skill Workshop is off and its `skill_workshop` tool denied wherever this exobrain is connected; the connector keeps that config reconciled.

## Exobrain versus OpenClaw memory

Sort content by one question: **would it survive replacing OpenClaw with a different agent runtime?** What survives belongs in the exobrain — knowledge, preferences, skills, tool docs. What dies with the runtime stays in OpenClaw's workspace — cron definitions, chat ids, ports, session policy, daily memory. Where the two meet, procedure is portable and wiring is not: a cron prompt names the skill it runs rather than restating one. OpenClaw is itself a **tool** by `AGENTS.md` § Tools, so what any agent needs in order to drive this machine belongs in its tool doc, while gotchas only OpenClaw needs about itself stay in `MEMORY.md`.

A memory-consolidation pass is therefore an exobrain review, not a filing exercise: **reconcile rather than append** — correct what a new note contradicts instead of stacking another version of the fact beside it — and once something is promoted, keep no second copy of the synthesis in `MEMORY.md`. Raw notes and routine churn stay in OpenClaw memory to be pruned normally. Entries OpenClaw's own dreaming sweep promotes into `MEMORY.md` are candidates for that review, not durable truth.

## Persisting from a chat turn

A land (`scripts/persist.sh`, the `exobrain-persist` skill) spends a minute or two on git and forge round-trips; a chat turn must not hold the session lane for it, or the person's next message queues behind git. Under OpenClaw:

1. Make the change in a worktree and commit it. The commit is the durable point — "saved" means committed on the branch, not merged. Anything this same turn reads back reads the worktree file; later turns read the default branch once the land completes.
2. Reply to the person.
3. Start the land detached — `exec` with `background: true`, running `scripts/persist.sh` from inside the worktree (`-m` when the work is still uncommitted; `--machinery-verified` when the skill's step 3 applies) — and end the turn. Don't poll `process` for it.
4. The process exit wakes the session. Exit `0`: nothing to say. Non-zero: tell the requester the change is committed on its branch but not yet landed, and what failed; the host's scheduled `scripts/persist.sh --sweep` retries a claimed worktree on its next pass, so a transient failure needs no action from anyone.

A scheduled (cron) session has no one waiting and runs the script in the foreground.

## Git history hygiene

Keep this repo's history agent-neutral — omit OpenClaw's default attribution from commit messages and PR bodies.

## Auto-loading

OpenClaw has no `@`-import primitive and auto-loads the root `AGENTS.md` but not the root sidecar, so `scripts/connect-agent.sh openclaw` delivers the rest of the composition into its private `~/.openclaw/workspace/USER.md`, between `<!-- BEGIN exobrain -->` … `<!-- END exobrain -->` markers: this file (`OPENCLAW.md`) if present, then the shared deeper-scope content — every connected scope's `AGENTS.md` (shallow→deep), the OpenClaw-filtered optional-skills index, the tools index, and the knowledge index. The same run reconciles OpenClaw's config so the linked skills load (§ Skills are exobrain files).

## MCP servers

The default exobrain setup registers MCP servers agent-agnostically — one registration serves every agent. See the per-tool docs under `tools/`. No OpenClaw-specific registration is needed.
