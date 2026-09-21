---
title: Exobrain
description: Plain markdown in a repo you own, loaded by your agent every session, so it works with your world instead of starting cold.
---

Plain markdown in a repo you own, loaded by your agent every session — so it works with your world instead of starting cold.

**Managed, not automatic.** Every agent now has a memory that writes itself, and you meet what it kept when it acts on it. Here a fact arrives as a pull request — past a validator wired into git, and a model reading the writing — so nothing enters without a diff you could have read. [How knowledge lands →](/concepts/how-knowledge-lands/)

**Scoped to person and machine.** One repo serves you on every machine, and other people alongside you. Each session loads its own chain, innermost wins, and nobody's context leaks into anyone else's. Solo, household and team are the same machinery. [Scopes →](/concepts/scopes/)

**Tested, not assumed.** The rules run against real agents — seventeen behavioral cases, security cases in a sealed sandbox, negative controls that fail an over-cautious guardrail. Changing a rule everyone loads is gated on showing it works. [Evidence →](/evidence/)

## Do you need one? Ask your agent

You're already talking to something that knows how you work. Rather than reading a site that wants you to say yes, hand it the question.

<div class="prompt">

```text
Read https://exobrain.diy, look at how I actually work with you, and tell me
whether it's worth setting up and maintaining — or whether I'm fine as I am.
```

</div>

Two lines on purpose. You shouldn't have to audit a wall of instructions before pasting something from a stranger's website into your agent.

A fair number of people should get back *no, not yet* — one machine, one agent, a context file that fits on a screen and isn't causing trouble. That's a real answer, and it's the right one more often than a project's own website tends to admit.

If the answer is yes, [creating one](/start/) is a second prompt pasted into an agent in an empty folder. If you'd rather judge it yourself first, [the ordinary argument](/why/) is the rest of this made the usual way.

---

## So what is it, exactly?

A **git repository of markdown files** that your agent loads as context at the start of every session. No database, no service, no daemon, no account.

Three ideas hold it together:

- **Knowledge** is durable — how your stack is set up, which conventions hold, what you decided and why. It's kept current.
- **Workspaces** are time-bound — an investigation, a migration, a piece of work with an end. They're allowed to go stale, which is what keeps the durable half trustworthy.
- **Scopes** decide what loads. A rule for everyone sits at the top; one that applies only to you, or only on one machine, sits further down. Your agent inherits the chain, and the innermost wins.

Alongside them sit **skills** — procedures the agent runs rather than re-reads — and a **tool doc** for each external system it reaches. Knowledge to read, procedures to run, systems to reach, and a flow to land its own work: an exobrain is what an agent operates from, not just what it remembers.

Four things follow from it being nothing but a repository of markdown:

- **Any agent.** Universal context lives in `AGENTS.md`. Per-agent quirks live in `CLAUDE.md`, `CODEX.md`, or `OPENCLAW.md` sidecars. Switching agents doesn't mean rewriting anything.
- **Yours outright.** You don't fork this repo and you never merge from it. An agent reads the concept and builds *your* exobrain. It has no upstream, so nothing here can break it.
- **Readable.** Every fact is a line of markdown in a git history. When your agent gets something wrong you can see which line taught it that, and fix it.
- **Scales down.** A useful exobrain is one `AGENTS.md` and one knowledge file. The rest exists when you need it and stays out of the way when you don't.

## Read on

- [Why an exobrain](/why/) — six ordinary moments with a bare agent and with an exobrain, the failure modes behind them, and an honest comparison against a flat `AGENTS.md`, built-in agent memory, and a wiki. Including when not to bother.
- [Philosophy](/philosophy/) — the idea underneath: people coordinating through a shared space their agents read and write, instead of through each other.
- [How knowledge lands](/concepts/how-knowledge-lands/) — the gates a fact crosses on the way in, and what each one is honestly worth.
- [How it gets used](/how-its-used/) — what actually accumulates in one, and what it feels like day to day.
- [Evidence](/evidence/) — a behavioral test suite that runs real agents against the context and checks what they do, and how to run it yourself.
- [Get started](/start/) — paste one prompt into an agent in an empty folder. It interviews you and scaffolds your exobrain in place.
- [Questions](/questions/) — is this lock-in? What if the project stops? Do I have to keep it updated?
- [Changelog](/changelog/) — every framework change, newest first.
- [Maintainer](/maintainer/) — who builds this, and where it came from.
