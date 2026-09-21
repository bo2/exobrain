---
title: How knowledge lands
description: The path a fact takes from noticed to committed — a branch, a validator wired into git, a model reading the writing, and a squash-merged pull request.
---

Every agent now ships some form of automatic memory. It watches the session, decides something is worth keeping, and keeps it. You meet what it kept when it acts on it.

An exobrain takes the opposite trade. The agent still does the writing — but between the writing and the repository sit gates you can read, run, and fail.

## The path a fact takes

1. **A branch, in its own worktree.** Changes never accumulate on the default branch. The work is isolated before the first file is touched, so an abandoned idea costs nothing.
2. **A commit, one per logical change.** Imperative subject, agent-neutral. The unit of review is a change, not a session.
3. **Deterministic validation.** Naming conventions, registry shape, machine-specific paths in files shared across machines, unretired compatibility shims, shell portability. This one is wired into git as a pre-push hook, so it runs whether or not anyone remembered it.
4. **A model reads the writing.** Changed specs and knowledge files go to a headless agent that reviews them against the authoring rules — content that serves the author rather than a reader, a rationale restated at every mention, prose that only makes sense as a reply to the session that produced it. It carries one hard gate of its own: a skill newly shared across a whole scope is blocked until there's committed proof it earns that reach.
5. **A pull request, squash-merged.** The change arrives as a diff with a title and a description, in a history you can walk backwards.

Your agent runs this itself, as one command, at each completed change. The point isn't the ceremony — it's that every one of those steps is a place the change can be stopped, including by you.

## What the gates are honestly worth

The deterministic half is exactly as good as its rules and no better: it catches a filename, a bad registry entry, an absolute path where one can't live. It never catches a fact that's simply wrong.

The model half is a model. It's held strict and it reads writing, not truth — it will flag a paragraph that exists to justify itself, and it will pass a confidently stated falsehood. It also **degrades open**: if no agent CLI is installed, or the review errors, the land proceeds rather than reporting a violation it didn't actually find. It's skippable with an environment variable, on purpose.

So: a floor, not a guarantee. The thing it guarantees is narrower and more useful than correctness — that nothing enters your knowledge base without a diff you could have read.

## Why this beats memory that writes itself

Four things fall out of the pipeline that automatic memory structurally cannot offer:

- **You can read it before it counts.** A pull request is the reading surface. Memory that writes itself has none.
- **You can reject it.** Not edit-after-the-fact — refuse, before it's ever in effect.
- **You can see when it changed, and what it replaced.** `git log` on a knowledge file is the history of what you believed and when you stopped.
- **It survives the agent.** The gates are shell scripts in your repository. They keep working when you switch agents, and they keep working if this project disappears.

The cost is real and worth saying: **it does not populate itself.** An exobrain nobody writes to is an empty repository. Automatic memory's whole appeal is that it asks nothing of you, and for a lot of people that's the right trade. This one asks for the habit and pays it back in knowledge you can actually trust.

## One memory, not two

An exobrain running beside an agent's own memory gives you two knowledge bases that drift apart without telling you. Both look healthy, and the agent answers from whichever it happens to read. So the exobrain owns durable memory:

- **Where the agent's memory can be switched off for one repository, it is.** Connecting Claude Code sets `autoMemoryEnabled: false` in the checkout's gitignored local settings.
- **Where the only switch is user-wide, it's yours.** Codex ships with memory off, and the connector doesn't reach into your global config to keep it that way; a tool that wires one repository doesn't change settings for all of them.
- **Where memory can't be switched off, the agent gets a rule.** Its own memory holds session scratch. Anything durable is promoted into the exobrain, correcting what it contradicts rather than adding beside it, and no copy stays behind.
