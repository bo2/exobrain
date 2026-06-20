---
id: 0025
title: Behavioral test harness — boot an instance and grade headless agent runs
date: 2026-06-16
tags: [testing, harness, agents, validation, scripts]
touches_invariant: false
files: [tests/run.sh, tests/lib/instance.sh, tests/lib/invoke.sh, tests/lib/judge.sh, tests/settings/allow.json, tests/cases/]
---

## Problem

Validation caught structure and prose — a deterministic linter for naming/JSON/scope
placement, and an LLM authoring review of changed specs. Nothing verified the thing
the specs exist to produce: that an agent *dropped into a fresh instance* actually
behaves the way `AGENTS.md`, the meta-domain, and the skills describe — holds the
worktree-first line, refuses instructions embedded in read content, keeps secrets out
of tracked files, normalizes filenames, routes a fact to the right domain, resolves
the deepest scope. A spec can read perfectly and the agent still not follow it, and
that drift is silent until a human notices in real work.

## Pattern

A behavioral test harness that grades agent *behavior*, not just files:

1. **Boot a real instance from the seed under test.** Clone the local seed into a
   throwaway dir and run the create flow non-interactively through the headless agent
   CLI (answers supplied in the prompt) — so the bootstrap is itself exercised. Then
   validate the result, commit it to establish a base branch, and make it safe to
   run agents inside: neutralize git hooks and assert there is no upstream (push)
   remote. Behavior cases run against cheap copies of this template, so one expensive
   build amortizes over many runs.
2. **Run concrete tasks via the headless agent, each N times.** One directory per
   case: the task prompt, an optional fixture-setup step, and a check. Re-run each
   case N times because agent behavior is stochastic; report a k/N pass rate against
   a per-case threshold (strict N/N, or a fraction) rather than a single pass/fail.
3. **Check deterministically first, then judge.** Prefer filesystem/git assertions and
   the existing structural validator (did the edit land in a worktree? is the secret
   absent? does it still validate?). For refusals and reasoning, fall back to a strict
   LLM-judge — the same headless-CLI idiom the authoring review already uses (proxy
   strip, timeout, a PASS/FAIL sentinel), but *strict*: absence of the pass sentinel
   is a fail (the opposite of a pre-push check, which degrades open). Run the judge
   only after the cheap deterministic gate passes.
4. **Permit safe commands, not all commands.** Action cases need real tool use without
   interactive prompts; grant it with an allowlist of safe commands (file edits, the
   framework scripts, version control minus push) rather than a blanket bypass, so a
   genuinely risky or un-allowlisted command is denied and the agent adapts.

## Reference (illustration only)

A `tests/` tree: `run.sh` (build template once → per-case × N loop → aggregate),
`lib/` (instance build/copy, the `claude -p` wrapper, the judge, shared check
helpers), `settings/allow.json` (the safe-command allowlist passed to the agent),
and `cases/<name>/` holding `meta.json`, `prompt.md`, optional `setup.sh`, `check.sh`,
optional `rubric.md`. Throwaway instances and transcripts live under the gitignored
scratch dir.

## Adapt notes

No invariant touched — this *verifies* invariants, it doesn't change them. Reuse your
own headless-agent invocation conventions (the proxy-strip + timeout + sentinel idiom
from your authoring-review equivalent); pin the judge to a strong model so its verdicts
don't drift with whatever the task uses. Keep your own default-branch name, create
skill, and validator. The containment rules are load-bearing: never point a scratch
instance at a real upstream remote, and neutralize its hooks before running agents in
it, so a test that exercises persist can't push or fire a review against the real repo.
Start thresholds strict and relax per case only where a behavior is inherently
stochastic.
