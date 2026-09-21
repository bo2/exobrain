---
title: Proving a change
description: How a change to what the agent reads gets tested before it ships — real agents, the same task with and without the change, and a count of what they actually do.
---

The [evidence](/evidence/) page answers one question: does the agent follow the rules? This page is about the other one. When you change what the agent reads — a line in `AGENTS.md`, a skill, a tool doc — does the agent actually behave differently?

## Intuition is the default, and it's often wrong

Most changes to agent context ship on a feeling that they'll help. Often they don't, or they help far less than it seemed, or only in a narrow case. The most favorable task always overstates a change, and effects vary strongly between models: a change that looks like a near-total fix on one task and one model can turn out narrow, or a wash, once held-out tasks and a stronger model are added.

## The duel

So the change has to beat the identical setup without it.

- **Control** is the repository as it is. **Treatment** is the same repository plus the one change. Nothing else differs.
- **Real agents, real auto-load.** Each arm runs the agent's own headless mode in a copy of the repository, wired by that copy's own connector, so the agent loads its context exactly as a normal session would. A sub-agent inside a running session doesn't reproduce that, and quietly invalidates the test.
- **Measure the decision, not the outcome.** Real tools touch live systems, so they're replaced with stubs that log the call and return canned output. What gets counted is which command the agent reached for — or, for a change about wording or structure, what the agent itself wrote.
- **Count, don't judge.** Graders are deterministic: a pattern in the stub log or in the agent's output. No model rules on the result.

## What keeps the test honest

- **The task has to depend on the change.** If the control agent could find the answer another way — elsewhere in its context, or on the filesystem — the task measures nothing.
- **Negatives are mandatory.** Every run includes tasks where the right move is to do nothing. A change that improves discovery but makes the agent over-reach is not a win.
- **Held-out tasks, touched once.** A change is tuned on one set of tasks and reported on another, which runs a single time; looking at it again leaks it into the next edit.
- **The production model.** The verdict is only as good as the model it ran on. Testing a weaker one gives the wrong answer.
- **A noise floor.** Running control against itself shows how much the numbers move by chance, before anyone reads meaning into a difference.

The doctrine behind this: [behavioral testing](/reference/harness-engineering/behavioral-testing/).

## Where it's required

Two gates tie the duel to how changes land.

- **Changes to shared machinery must be verified before they land** — the root scripts, the registries, a skill everyone gets, the spec every agent loads. The persist flow runs the deterministic unit tests itself, and refuses to land until the agent asserts it has run the behavioral checks. That assertion is the agent's word, recorded with the landing; the duel is how it earns it.
- **A skill that reaches beyond its author must carry proof.** A skill declared for a whole scope loads for everyone in it, so it commits its evidence inside its own directory: a test, an eval, or — for a skill meant to change behavior — an A/B result showing that it does. Without proof it lives in its author's own scope, where it imposes on no one. The authoring review blocks the land until the proof is there.

Both follow one principle: anything imposed on people beyond its author has to earn that reach ([principles](/reference/harness-engineering/principles/)).

## What it doesn't show

- **Decisions, not correctness.** The duel shows the agent reached for the right command more often. It doesn't show that the command's result was right.
- **Only the shared scope.** Sandboxes load the shared spec and shared skills, which is what most framework changes touch. A change to one person's or one machine's scope needs that scope wired in by hand.
- **Only shell commands.** A tool the agent reaches through MCP, or by full path, doesn't pass through a stub, so it can't be counted.
- **Real agent runs cost real usage.** Every task runs on both arms with a real agent. It's for changes worth measuring, not every edit.
