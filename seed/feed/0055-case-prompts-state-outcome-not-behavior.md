---
id: 0055
title: Behavioral-case prompts must state the outcome, never the behavior under test
date: 2026-06-21
tags: [tests]
touches_invariant: false
files: [skills/exobrain-tests/scripts/cases/]
---

## Problem

Several behavioral-suite prompts coached the agent toward the very behavior they
grade. The kebab-case-naming prompt told the agent to "follow the repo's file-naming
conventions" and substitute "the conventional form"; the scope-resolution prompt named
the connected leaf and said the doc was "overridden at my person scope". An agent can
satisfy those by obeying the prompt, not by following the specs — so the case stops
measuring whether the auto-loaded context actually drives behavior, and a regression in
the specs passes anyway. Separately, the route-fact-to-domain prompt asked the agent to
file a financial fact "in the most appropriate place", but the base instance ships no
domains — there was no finance-vs-home choice to route between, so the case couldn't
exercise the routing it claimed to.

## Pattern

A case prompt states the **outcome a real user would ask for** plus the concrete target
detail a user would naturally give (which file, the fake key, the tool's name) — and
never the **policy under test** (use a worktree, follow kebab-case, the deepest scope
wins, file it in finance). Keep target detail; cut policy. The grader, not the prompt,
encodes the expected behavior.

A routing case also **self-seeds its own choice landscape**: both the correct target and
a plausible-but-wrong one, so picking right is a real decision. Seed it **committed to
the base branch**, because a worktree-first agent branches off the base and an
uncommitted seed never reaches its worktree.

De-leaking shifts the burden to the fixture: whatever precondition the prompt used to
*assert*, the setup must now actually *build*. A scope-precedence case can't just plant a
tool doc under `people/<id>/` and have the prompt claim that scope is connected — once the
prompt stops saying so, a rigorous agent checks, finds no `AGENTS.md` scope flag and no
`.exobrain.json`, and correctly rules the override inert (global wins). Flag the scope and
record the connected leaf so the intended answer follows from the specs alone.

## Reference (illustration only)

```diff
- Add a doc … called `RETIREMENT.md`, following the repo's file-naming conventions —
- if that filename doesn't comply, use the conventional form instead.
+ Add a doc … Call the file `RETIREMENT.md`. Go ahead and create it now.
```

```sh
# route-fact-to-domain/setup.sh — seed both targets, then commit so a worktree sees them
mkdir -p "$INST/domains/finance" "$INST/domains/home"   # correct home + too-generic decoy
# …write a minimal valid README into each…
git -C "$INST" add -A && git -C "$INST" commit -q -m "case: seed routing targets"
```

## Adapt notes

Keep the seed's wording clear of the check's match tokens — a finance seed that mentioned
"brokerage" would satisfy a `grep -E 'fidelity|brokerage'` check with no agent action at
all, turning a routing test into a no-op pass. One case stays deliberately over-specified:
no-default-branch-edit explicitly orders the agent to skip the worktree, because its whole
point is adversarial — does the agent hold the line against an instruction? That's the
exception that proves the rule: leak the behavior only when refusing the leak *is* the
behavior under test.

Expect a wall-clock cost: a prompt that no longer hands over the file paths forces real
discovery, so a case that sat comfortably under its timeout can start flaking right at the
ceiling. Re-tune `timeout_seconds` after de-leaking a prompt, not before.
