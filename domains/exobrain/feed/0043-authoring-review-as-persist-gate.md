---
id: 0043
title: Run the LLM authoring review at the persist gate, not on every push
date: 2026-06-20
tags: [scripts, validation, authoring, persist, hooks]
touches_invariant: true
files: [skills/exobrain-persist/SKILL.md, scripts/authoring-review.sh, AGENTS.md, domains/exobrain/machinery.md]
---

## Problem

Card 0028 unwired the LLM authoring review from the `pre-push` hook because a per-push model round-trip taxes every push for an occasional payoff. That left the review purely manual — and a judgment gate nobody is reminded to run is a gate that quietly stops running. The deterministic validator still gates every push, but the authoring smells the LLM catches went unchecked unless an author happened to remember.

Refines card 0028: keeps the review off the per-push path, but gives it a reliable automatic trigger.

## Pattern

Attach the slow LLM judgment pass to the **deliberate land**, not to every push. The persist flow (worktree → commit → push → PR → merge) fires once per *completed logical change* — exactly the moment a spec/domain edit becomes durable, and far less often than a raw push. Run the review there, after commit and before push, so:

- it runs automatically without an author remembering;
- it costs a model round-trip only on real landings, not on every intermediate or unrelated push;
- the per-push hook stays fast and deterministic.

The script must stay cheap on the no-op path for this to be free: self-skip when no spec/domain file changed, and degrade open when no agent CLI is installed. Because it reviews committed changes (merge-base...HEAD), the natural slot is after the persist commit; on a flagged violation, fix and amend the still-unpushed commit before pushing (amending unpushed history is allowed; rewriting pushed history is not).

## Reference (illustration only)

Add a persist step between **Commit** and **Push**: run `scripts/authoring-review.sh`; on violations, fix and amend the unpushed commit, else continue. Reword the script header, the `AGENTS.md` validation section, and the machinery gate table so the review reads as *persist-triggered + manual*, no longer "on-demand only" — and still not a push-hook gate.

## Adapt notes

**Touches the validation contract** — but by *adding* a trigger, not weakening one: the deterministic validator still gates every push, the per-push hook is unchanged, and the script's diff-as-data prompt-injection safety is untouched. If your land flow isn't called "persist" or doesn't commit before pushing, attach the review to whatever step marks "this change is done and about to leave the machine," and make sure it reviews committed (not working-tree) changes if you keep the merge-base...HEAD diff. An instance that wants the review on every push can still wire it into the hook instead — this is a where-does-it-fire trade-off, not a correctness fix.
