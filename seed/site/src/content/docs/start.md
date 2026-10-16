---
title: Get started
description: From an empty folder to a connected agent, followable end to end without asking anyone.
---

Setup is one prompt. An agent reads the concept, interviews you, and scaffolds your exobrain in place — so the thing that onboards you is the same thing you'll be using.

## Before you start

- **An AI coding agent** — Claude Code, Codex, OpenClaw, or another that can read and write files and run commands.
- **git**, and somewhere to put a repository. It can stay local; it does not have to be hosted anywhere.
- **An empty folder.** Your exobrain is its own repo, not a directory inside an existing project.

No account, no service, no API key. Nothing here phones home.

## Create it

Open your agent in the empty folder and paste this:

```text
You're going to help me set up my own "exobrain" — a small, version-controlled
knowledge base that any AI coding agent (Claude Code, Codex, OpenClaw) loads as
context, so it works with knowledge of my world (my projects, preferences, and
machines) instead of starting cold every session.

The concept and a generator live at https://github.com/bo2/exobrain. Please:

1. Fetch it: clone https://github.com/bo2/exobrain into `src/exobrain-seed/` in
   this folder — my instance keeps it there as its update-cache (gitignored)
   (or, if you can't clone, read the repo's raw files from GitHub).
2. Read its knowledge/exobrain/ (what an exobrain is — scopes, skills,
   propagation) and seed/skills/create-instance/SKILL.md (how to build one).
3. Then follow create-instance: ask me a few short questions (what I'll use
   this for, whether anyone else shares it, one or two knowledge domains to
   start with), and scaffold a fresh exobrain for me IN THE CURRENT DIRECTORY,
   copying the framework scripts from the clone and adapting names and
   structure to my answers.

Detect my setup as you go (git, which agent you are) instead of assuming it,
and explain anything you're about to do that I'd want to approve. Start by
fetching the repo and reading those two things, then ask me the questions.
```

It will ask a few short questions — what you'll use it for, whether anyone else shares it, one or two areas to start with — and build the structure around your answers. Expect a handful of minutes.

:::note[It should be asking, not assuming]
A good run interviews you and explains what it's about to do. If your agent starts scaffolding without asking anything, stop it and tell it to read `seed/skills/create-instance/SKILL.md` first.
:::

## Connect your agent

From inside your new exobrain:

```sh
scripts/connect-agent.sh claude    # or: codex, openclaw
```

This links your context into the place your agent looks for it, and installs a hook that re-links after you pull. Run it again with `--relink` after you change scopes or skills.

It writes outside the repo — agent config and a git hook. It'll tell you where before it does.

## Check that it worked

Start a fresh session and ask something only your exobrain would know:

> What do you know about my setup?

The answer should reflect what you told the generator. If it's generic, the connection didn't take — see [Questions](/questions/#the-agent-doesnt-seem-to-be-reading-it).

## The first week

Resist filling it. An exobrain that grows from real friction stays useful; one built speculatively is a chore with no payoff.

The habit that matters: **when you catch yourself explaining something for the second time, stop and write it down.** That single rule builds a good exobrain over a few weeks without any deliberate effort.

Good first entries:

- A convention your agent keeps getting wrong.
- Where things live on this machine, if that's ever tripped it up.
- One decision you'd be annoyed to relitigate.

Bad first entries: anything you're writing because it seems like it belongs, rather than because it cost you something.

## Where to go next

- **[Concepts](/concepts/scopes/)** — scopes, knowledge and workspaces, skills and tools. Worth reading once you've used it a little; the ideas land better with something concrete to attach them to.
- **[The repository](https://github.com/bo2/exobrain)** — the full model as your agent reads it, in `knowledge/exobrain/`.
- **[Questions](/questions/)** — including what to do when something doesn't work.
