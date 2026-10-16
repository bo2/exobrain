---
title: Philosophy
description: The idea exobrain is built on — people coordinating through a shared space their agents read and write, instead of through each other.
---

Exobrain is built on one idea about how work coordinates once agents do the execution: people stop syncing with each other and start syncing with a shared space that their agents read and write. The name for that is **agentic stigmergy**.

## The bottleneck moved

For decades, building was the expensive step, so teams accepted a rough spec and spent their effort on implementation. Agents invert that. Execution is fast and cheap now; what's scarce is framing the problem, setting intent, and deciding what good looks like.

That breaks the usual shape of a team. When execution was slow, a lead could hand down a plan and answer questions one at a time, because engineers were busy building in between. When execution is fast, engineers finish and come back for the next decision faster than anyone can answer. Decisions live in one person's head, reachable one conversation at a time, and the work agents made parallel serializes on that person again.

## The model

Three moves.

**A shared space holds current truth.** What the team knows and has decided is written into a space every agent can read — the exobrain — instead of living in heads and being synced on demand. When the space and reality disagree, you fix the space. You don't hold a meeting.

**People work independently, in parallel.** Each person takes a piece and drives it end to end, consulting the space rather than a colleague. The answers they need are already there, so they read, decide, and write back.

**Agents reconcile the space, many to many.** Each person's agent reads the shared space, writes their results into it, reconciles conflicts, and surfaces what matters to them. Coordination happens through the medium: one writer, many readers, no central router.

## Why "stigmergy"

*Stigmergy* is coordination through traces left in a shared environment: one actor's mark prompts the next action, with no controller and no direct message. Ants run a colony on pheromone trails — the trail, not a conversation, says what to do next ([Wikipedia](https://en.wikipedia.org/wiki/Stigmergy)).

People already coordinate this way at scale. Mark Elliott's *stigmergic collaboration* describes Wikipedia and open source, where a poor article or an open issue is itself the signal that pulls in the next contribution ([Elliott](https://wiki.p2pfoundation.net/Stigmergic_Collaboration)). Kevin Crowston finds the same in distributed software teams: the code, the failing test and the TODO coordinate the work ([Crowston](https://crowston.syr.edu/stigmergy)).

What's new is the **agentic** part. A classical trace is passive: it sits there until a person notices it, reads it and decides. Agents lift that ceiling. They read the space continuously, synthesize across many traces, reconcile contradictions, and bring each person the part that concerns them. The trace becomes shared understanding that something actively maintains.

## Why a medium beats messages

The reflexive way to coordinate, for people or agents, is direct: A messages B, B messages C. It doesn't scale. Every new participant adds conversations with everyone else, so the overhead grows faster than the team ([CIO](https://www.cio.com/article/4143420/true-multi-agent-collaboration-doesnt-work.html)). A shared medium has the opposite shape. Each participant reconciles against one space, so the cost grows with the number of people, not the number of pairs.

## What changes for people

| Hierarchical human sync | Agentic stigmergy |
|---|---|
| Coordinate by meeting and roll-up | Coordinate by reading and writing the shared space |
| Knowledge in heads, synced on demand | Knowledge in the exobrain, reconciled continuously by agents |
| Plan handed down, questions handed up | Plan handed over; engineers resolve the unknowns themselves |
| Lead is a decision funnel | Lead is a curator of the space |
| Work serializes on shared people | Work runs in parallel; the medium absorbs the coordination |

The lead's job changes most. Instead of answering execution questions in series, the lead writes intent into the space once — what we're building, why, for whom, under which constraints, and what's already decided — and many people read it at the same time. Engineers take on judgment that used to be the lead's: with the *why* in front of them, they settle most open questions the way its author would have.

## What it takes

The model only works if people trust the space enough to act on it without re-checking. Everything below serves that.

- **Every write is treated like a deploy.** Whatever lands in the space becomes true for everyone, and an unverified write propagates as fact. Each change is grounded in a resolved question, a confirmed decision, or data; an agent proposes it and a person reviews it. ([How knowledge lands](/concepts/how-knowledge-lands/))
- **Truth and the work behind it live apart.** Durable knowledge is kept current. Investigations and drafts are point-in-time records, allowed to age. Agents reconcile against the first and dig into the second only when they need the trail. ([Knowledge and workspaces](/concepts/knowledge-and-workspaces/))
- **Questions climb a ladder.** Ask your agent first; most questions end there. If the space is silent, research it. If it needs someone's judgment, ask that one person, asynchronously. Then write the answer back, so nobody has to ask it twice.
- **Missing expertise is a named gap.** A question too big for the ladder becomes a gap, with one owner who needs it closed and one person who can close it. It ends with the answer written into the space, or with a changed plan. Hitting a gap is how work moves forward, not a failure.
- **Attention is the scarce resource.** An agent makes documents, questions and code nearly free to produce, and they cost just as much to read as before. So nobody dumps a large artifact with "thoughts?", nobody fires a generated barrage of questions, and a question is closed and addressed to one person: "A, B or C — I picked B, does that hold?"
- **Status isn't a meeting.** Live status lives in the tracker and current truth lives in the space. The only regular sync is short, between leads, about the contracts between their pieces.

## Running a build on it

A team build gets its own time-bound space — what's being built and why, the contracts between pieces, the decisions so far — which folds into durable knowledge when the build ships. Work moves through it in stages that overlap freely:

1. **Brain dump.** Everyone who knows an area writes down everything they know. Completeness over polish; this is not a spec.
2. **Grill.** An adversarial interview resolves the gaps and contradictions before engineering reads it ([grill](https://github.com/bo2/exobrain/blob/main/knowledge/exobrain/grill.md)).
3. **Source of truth.** The result becomes the one place that says what's true. Any spec is a view derived from it, never a second truth.
4. **Thin slices.** The work is cut small enough for one engineer or one agent run.

Each piece has exactly one person driving it; everyone else consults. Two drivers on one piece collide.

## Where it doesn't fit

It fits knowledge-heavy work that can run in parallel, where intent can be written down and people are willing to own the judgment. It doesn't replace synchronous decisions: a live incident, a genuine design dispute, the fast back-and-forth of a problem nobody has framed yet. And it fails quietly when the *why* never leaves one person's head. The model removes the bottleneck only if the curator actually curates.

## Where exobrain comes in

Exobrain is the shared space, built to run this model. It started as the way [a team at Automattic launched a new product](/maintainer/). The same mechanism works at smaller scale: sessions, machines and agents that never talk to each other stay in step because they read and write the same repository.
