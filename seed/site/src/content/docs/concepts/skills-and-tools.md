---
title: Skills and tools
description: Procedures the agent can invoke, and external systems it can reach.
---

Knowledge tells the agent what's true. Skills and tools are how it *does* things.

## Skills — procedures worth repeating

A skill is a directory with a `SKILL.md` inside: instructions the agent reads when the task calls for it. Landing a change, running a release, working through a particular kind of investigation.

The difference from pasting a prompt each time is that a skill is **in version control**. It improves when you improve it, it doesn't depend on you remembering the details, and everyone connected to that scope gets the same procedure.

Skills load at three levels of eagerness, which matters because context isn't free:

| Tier | Behaviour |
|---|---|
| **always** | Loaded into every session. Reserve for procedures that must never be missed. |
| **optional** | Listed in an index with a one-line summary; the agent reads the full skill when it's relevant. The right default. |
| **unlisted** | Registered and invocable by name, but not surfaced. For rarely-used procedures. |

Skills also scope. One declared at your person scope reaches only you; sharing it more widely is a deliberate act, because a skill at a shared scope imposes on everyone connected there.

## Tools — external systems

A tool is anything the agent reads from or acts on outside the repo: an issue tracker, a cloud API, a calendar, a deploy pipeline.

Each gets **one self-contained document** — what it's for, how to authenticate, the exact commands, and the failure modes. The document's presence *is* the registration; there's no registry to keep in sync. An index of every tool and its one-line purpose loads each session, so the agent knows what exists and reads the full document before reaching for one.

The failure-mode sections earn their keep fastest. The obscure error that cost you an hour goes in the doc, and it never costs that hour again.

### Credentials stay out

The rule is absolute and worth stating plainly, because it's what makes tool docs safe to commit and safe to share:

- Secrets live in an untracked environment file. **Scripts read them at runtime; the value never enters the agent's context.**
- Documents use placeholders, never real values.
- Secrets are never passed as command-line arguments a tool might echo.

Which system is connected is per-machine state, so a tool everyone can read about is only *usable* where it's actually been set up.

## The division

A rough guide when it's unclear where something belongs:

- **Knowledge** — a fact that is true. *The deploy runs from the release branch.*
- **Skill** — a procedure with steps. *How to cut a release.*
- **Tool** — an external system with an interface. *The deploy API, and how to call it.*
