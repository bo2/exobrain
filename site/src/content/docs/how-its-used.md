---
title: How it gets used
description: Concrete examples of what lives in an exobrain and what changes day to day when the agent already knows.
---

Abstractions are easy to nod along to and hard to act on. Here is what actually accumulates in one.

## Conventions the agent keeps getting wrong

The smallest useful thing, and usually the first.

> Default branch names vary per repo — resolve each repo's actual default rather than assuming `main`.

One line. It stops a class of confident wrong guesses permanently, across every session and every agent. Most exobrains start as a handful of lines like this, added the third time you corrected the same mistake.

The trigger is easy to recognize: **you've explained it twice.** That's the signal to write it down instead of explaining it a third time.

## The second machine

You set an agent up on your laptop. It learns where things live. Then you work from a different machine and none of it transfers, because half of what it learned was paths.

Host scopes exist for exactly this. Anything machine-specific — toolchain locations, where checkouts live, which services run locally — lives in that machine's scope and loads only there. The shared knowledge stays shared. Adding a third machine means adding a scope, not re-teaching everything.

## Decisions that survive the session

You spend an afternoon with an agent working out how something should be structured. You weigh three options, pick one, and move on. That reasoning lived in a chat window.

Six weeks later, the agent proposes option two.

Writing the outcome into a durable area — *what holds now*, not the transcript — means the next session starts from the decision instead of relitigating it. This is the highest-value habit in the whole system and the easiest to skip.

## Work that has an end

Not everything is durable. An investigation, a migration, a spike, a debugging session that sprawled across two days — these have a beginning and an end, and they shouldn't sit next to your permanent rules pretending to be current.

Workspaces hold them. Notes, scratch scripts, query output, the half-finished analysis. When something durable falls out — *and this is now how we do it* — it gets promoted into a knowledge area. The rest is allowed to go stale, because it's clearly marked as a point-in-time record.

The practical benefit is that "the agent is confidently telling me something out of date" becomes much rarer, because stale content is quarantined by design.

## Procedures worth repeating

Some things you do the same way every time: how a change gets landed, how a release goes out, how a particular kind of investigation is run.

Written as a **skill** — a directory with instructions the agent reads on demand — a procedure becomes something you invoke rather than re-describe. The difference from pasting a prompt each time is that the procedure lives in version control, improves when you improve it, and doesn't depend on you remembering the details.

## External systems

Agents get useful when they can reach things — an issue tracker, a cloud API, a calendar, a deploy pipeline.

Each external system gets a **tool doc**: what it's for, how to authenticate, the exact commands, and the failure modes worth knowing. The agent reads it before reaching for the system. Credentials are never in the doc; scripts read them at runtime, so what's written down is safe to share and the secrets stay out of the agent's context entirely.

The payoff is the failure modes. The obscure error you hit once and spent an hour on gets written down, and neither you nor the agent loses that hour again.

## Work that runs without you

Once context is durable, some work stops needing a person in the loop — a scheduled sweep that keeps an area current, a periodic check that reports only when something looks off, a routine ingest.

This is where an exobrain stops being documentation and starts being infrastructure. It's also where being able to read exactly what the agent believes stops being a nicety.

## People who don't write code

Scopes don't care whether the person is an engineer. A shared exobrain can serve a team where only some members touch the repo, or a household where only one person does — each person's context loads for them, the shared knowledge is shared, and the agent addresses each of them appropriately.

The machinery is identical. Solo, team, and family are the same three lines of configuration.

---

## What it actually feels like

The change is quieter than a demo would suggest. Sessions start further along. You stop bracing for the wrong-assumption correction. Occasionally the agent does something that makes you check whether you'd really written that down, and you had, months ago.

The failure mode is equally quiet: if you don't write things down, nothing accumulates, and you have an empty repo. This is an explicit system. It rewards the habit and does nothing without it.
