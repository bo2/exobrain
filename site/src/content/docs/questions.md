---
title: Questions
description: Ownership, dependency, privacy, project status, and what to do when something doesn't work.
---

## Am I locked into anything?

No, and there's very little to be locked into. Your exobrain is a git repository of markdown files and shell scripts on your own disk. No account, no service, no API key, no licence check. Nothing in it contacts this project at runtime.

There's no export path because there's nothing to export — the files are already the artifact, in a format you can read.

## What if this project is abandoned?

Your exobrain keeps working, unchanged.

It doesn't execute anything hosted here. The framework scripts were **copied into your repository** when it was created; they're yours, and you can edit them. The only thing you'd lose is new patterns to adopt, which is a stream of optional improvements, not a dependency.

This is worth weighing against the usual alternative. A hosted memory service going away takes your data with it. This going away leaves you with exactly what you had the day before.

## Who maintains it, and is there support?

It's a **personal project**, used daily by its author. There's no company, no roadmap, no support commitment, and no response-time promise. Setting that expectation honestly is more useful than implying otherwise.

What replaces support is that the system is written to be read by an agent — and you have one. The full model lives in [`knowledge/exobrain/`](https://github.com/bo2/exobrain/tree/main/knowledge/exobrain) in the repository, written as reference documentation. When something is unclear or broken, pointing your own agent at the repository and asking is usually faster than asking a person, and it works at three in the morning.

## Do I have to keep it updated?

No. There's no version to track and nothing breaks from skipping updates indefinitely.

When you do want improvements, you ask your agent to run the update, and it adapts each change to the structure you actually have — see [Staying current](/concepts/staying-current/). You can decline any individual change.

## Does anything leave my machine?

Only what your agent already sends. An exobrain adds no telemetry, no sync, and no network calls of its own.

Whether the repository is hosted anywhere is your choice — it works entirely locally. Many are private, which is the sensible default given what accumulates in one.

## Is it safe to put sensitive things in?

With the standard caution that anything in your repository is visible to anyone with access to your repository, and to your agent.

The design draws one hard line: **credentials never go in.** Secrets live in an untracked environment file, scripts read them at runtime, and documents use placeholders — so the value never enters the agent's context or the git history. There's also a gitignored local scope for context that must never be committed.

For everything else, the honest framing is that it's your repository under your access controls, and you should treat what goes in it accordingly.

Whether an agent actually honours that line under pressure is tested, not assumed — see [Evidence](/evidence/).

## Isn't this just a `CLAUDE.md` with extra steps?

For a single machine, a single agent, and no colleagues — genuinely yes, and you should use the flat file. That comparison is laid out properly in [Why an exobrain](/why/#versus-a-single-agentsmd--claudemd).

## Which agents work with it?

Claude Code, Codex, and OpenClaw have connectors. Anything that reads files and runs commands can use it, since universal context lives in `AGENTS.md` and per-agent specifics live in sidecars.

Using two agents against the same exobrain is a supported case, not a workaround.

## Does it work for a team?

Yes — a team is just more person scopes. Each person connects their own, shared knowledge is shared, and nobody's context leaks into anyone else's session.

The same machinery covers a household where only one person writes code. Solo, team, and family differ by configuration, not by design.

## How much time does this take?

Setup is one prompt and a few minutes of questions.

After that the honest answer is **it depends entirely on the habit**, not on the system. The habit is writing something down when you notice you've explained it twice — seconds, at the moment you're already thinking about it. If you don't build that habit you'll have an empty repository, and the system won't save you. It's explicit by design; that's the trade for being readable and reviewable.

---

## The agent doesn't seem to be reading it

Most often the connection step, not the content.

1. **Re-run the connector** from inside your exobrain: `scripts/connect-agent.sh <agent>` — or `--relink` if you've changed scopes or skills since.
2. **Check you connected a leaf scope.** Context resolves from the connected scope up. If nothing is connected, nothing loads.
3. **Start a fresh session.** Context loads at session start; an open session won't pick up changes.
4. **Ask it directly** — *"which context files did you load?"* Comparing that answer against what you expected usually locates the problem immediately.

## Something else is broken

Ask your agent, with the repository available to it. The concept documents are reference material written for exactly this, and the diagnosis is usually a scope that isn't connected or a link that needs refreshing.

If you find a real bug, [the repository](https://github.com/bo2/exobrain) is the place for it — with the caveat about response times above.
