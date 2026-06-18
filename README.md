# Exobrain

A small, version-controlled **knowledge base for your AI agent**. Any agent (Claude Code, Codex, OpenClaw, …) loads it as context, so it works with knowledge of *your* world — your projects, preferences, and machines — instead of starting cold every session.

This repo is the **concept + a generator**. You don't fork it. You point an agent at it and it builds *your own* exobrain — with names and structure that fit you.

## Create your own exobrain

Open your AI agent in an empty folder where you want your exobrain to live, and paste this:

```text
You're going to help me set up my own "exobrain" — a small, version-controlled
knowledge base that any AI coding agent (Claude Code, Codex, OpenClaw) loads as
context, so it works with knowledge of my world (my projects, preferences, and
machines) instead of starting cold every session.

The concept and a generator live at https://github.com/bo2/exobrain. Please:

1. Fetch it: clone https://github.com/bo2/exobrain into `src/exobrain-seed/` in
   this folder — my instance keeps it there as its update-cache (gitignored)
   (or, if you can't clone, read the repo's raw files from GitHub).
2. Read its domains/exobrain/ (what an exobrain is — scopes, skills,
   propagation) and seed/skills/create-instance/SKILL.md (how to build one).
3. Then follow create-instance: ask me a few short questions (what I'll use
   this for, whether anyone else shares it, one or two domains to
   start with), and scaffold a fresh exobrain for me IN THE CURRENT DIRECTORY,
   copying the framework scripts from the clone and adapting names and
   structure to my answers.

Detect my setup as you go (git, which agent you are) instead of assuming it,
and explain anything you're about to do that I'd want to approve. Start by
fetching the repo and reading those two things, then ask me the questions.
```

That's it. The agent reads the concept, interviews you, and scaffolds a working exobrain in place — then tells you how to connect your agent to it.

> No agent handy? You can still **browse** this repo to learn the model, or clone it and run `scripts/connect-agent.sh <agent>` to use it as-is in guest mode.

## What is an exobrain?

Two kinds of content, plus a way to scope them to *you*:

- **Domains** (`domains/`) — durable areas of what you know (health, finances, a project's facts), kept current.
- **Workspaces** (`workspaces/`) — time-bound efforts (a trip, an investigation) that outdate by design.
- **Scopes** — a scope is any directory with an `AGENTS.md`. Connect a leaf (you, on this machine) and the agent inherits its whole ancestor chain: `global < … < you < this machine`. Solo, family, and org all use the same machinery.

It serves **any** agent: universal content lives in `AGENTS.md`; per-agent quirks live in `CLAUDE.md` / `CODEX.md` / `OPENCLAW.md` sidecars.

Full model: [`domains/exobrain/`](domains/exobrain/).

## What's in this repo

| Path | What it is |
|------|-----------|
| [`domains/exobrain/`](domains/exobrain/) | **The concept** — entities, scopes, agents, skills, tools, authoring, propagation, written for an agent to read |
| [`seed/`](seed/) | **Seed-local** — the `create-instance` generator and the behavioral test harness. Operates on the seed itself; never copied into an instance |
| [`skills/exobrain-evolve/`](skills/exobrain-evolve/) | Bring an instance up to date — read this repo's feed, copy/rewire each change, record it. Copied into every instance. |
| [`domains/exobrain/feed/`](domains/exobrain/feed/) | **The feed** — the changelog of dated pattern-cards `exobrain-evolve` reads to bring instances forward |
| [`scripts/`](scripts/) | The framework `create-instance` copies into a new instance (`connect-agent`, `skills-registry`, validators) |
| `AGENTS.md`, `scopes.json`, `skills.schema.json` | The spec and registries a new instance starts from |

## How updates work — no forking

Your instance is **independent** — no upstream remote, no merge. When this repo ships a change, you ask your agent to run `exobrain-evolve`: it reads the feed since you last updated, **copies** the files you haven't diverged and **re-synthesizes** the rest into your setup, then records the card IDs in your adoption ledger. See [`domains/exobrain/propagation.md`](domains/exobrain/propagation.md).

## License

[MIT](LICENSE.md) — use it, fork it, build your own. The exobrain *you* generate from it is yours.
