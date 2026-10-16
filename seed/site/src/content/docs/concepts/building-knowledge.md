---
title: Building knowledge
description: How a knowledge domain gets made and kept current — four ways in, an interview that challenges instead of transcribing, and a test that says when it's good enough.
---

A domain is only useful if it's right, and most of the work of making it right happens before anything is written down. In an exobrain, building knowledge is a procedure your agent runs, not a document you type.

## Four ways in

Which one you use depends on what already exists, and whether a person is in the loop.

| You have | Mode | What the agent does |
|---|---|---|
| Nothing written down; the knowledge is scattered | **create** | Scopes the domain, scaffolds its files, sweeps your sources in parallel over a year or more of history, walks the code, and synthesizes. |
| A pile already collected — notes, transcripts, docs | **distill** | Drafts the domain from the pile, then interviews you until the two of you understand it identically. |
| A domain, plus one new thing — a decision, a document, a thread | **curate** | Folds it into the right files, replacing what it contradicts instead of appending, and asks you only what it can't look up. |
| A domain that should stay current without you | **update** | On a schedule, sweeps the domain's sources for recent activity, keeps what passes the horizon test, and flags anything uncertain instead of asking. It never deletes. |

Every mode ends the same way as any other change: a pull request through the same gates ([How knowledge lands](/concepts/how-knowledge-lands/)).

## The grill

The interview in `distill` and `curate` is a *grill*: an adversarial interview whose goal is shared **correct** understanding. An interview that politely records every answer aligns the agent with the person's blind spots too, so the grill pushes on weak reasoning instead of collecting it. It generalizes Matt Pocock's *grill-me*.

- **Explore before asking.** A person's attention is the most expensive thing in the session. Whatever the agent can look up in code or documents, it looks up. Whatever a convention or a reversible default settles, it decides, and lists those calls so you can veto any of them by number. Only judgment reaches you: taste, history, intent, risk tolerance, a genuine trade-off.
- **One question at a time**, each carrying the evidence behind it, the agent's recommended answer, and what changes downstream if you choose differently.
- **Prove it was understood.** An empty list of questions proves they were answered, not that the answers were understood. So the session closes with a read-back of the whole picture and a quiz of scenario questions aimed at exactly what was contested. It's done when you sign off.

The full discipline: [the grill](/reference/exobrain/grill/).

## What gets written

Every line in a domain meets the same rules ([authoring](/reference/exobrain/authoring/)):

- **The horizon test.** *Will this still matter in three months?* A switched bank account does; a paid bill doesn't. Routine events stay in raw notes.
- **Current state, not history.** A domain says what's true now. How it got that way belongs to the workspace that did the work.
- **Synthesize, don't transcribe.** Six receipts about a project become one paragraph on its status. If deleting a passage loses nothing a reader couldn't recover from the source in one step, it goes.
- **The shape, not the snapshot.** A value that drifts — a balance, a rate, a count — freezes a moment that won't stay frozen. The domain states the durable shape ("about four months of expenses") and points at where the live number lives.
- **Contradictions stay visible.** When sources disagree, or newer evidence contradicts the text, it goes to the domain's open questions instead of being quietly settled either way.

## Knowing when it's good

A domain can read well and still be wrong. The way to find out is to test it the way you'd test a model: a labeled set of real questions plays the role of the spec, and the domain plays the role of the weights. An agent answers each question from the domain alone, and the answers are scored.

The loop is the same for any text an agent reads at decision time ([eval loops](/reference/harness-engineering/eval-loops/)). Split the questions before editing anything, improve against one part, stop when the gains flatten, then score the held-out part exactly once. When the practice score moves and the held-out score doesn't, the domain has learned the test rather than the subject. That's the most useful thing the loop can tell you, and every serious attempt runs into it at least once.
