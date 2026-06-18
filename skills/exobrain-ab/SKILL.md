---
name: exobrain-ab
description: "A/B-test whether a change to this exobrain's auto-loaded context (an AGENTS.md/CLAUDE.md edit, a skill, or a tool doc) actually moves agent behavior — before shipping on intuition. Runs real headless agents (claude or codex) on control (trunk) vs treatment (trunk + the change) in hermetic sandboxes — each wired by the connector's own --render-specs-only, so it loads context like a real session — and measures which tool/command the agent reaches for. Use to eval / validate / A-B-test a spec/skill/tool-doc change, or to check whether a context change improves or harms agent behavior."
---

# exobrain-ab — behavioral A/B testing for exobrain changes

Most exobrain changes — an `AGENTS.md` line, a skill tweak, a tool-doc edit — ship on
intuition: *"this will help the agent."* Often it doesn't, or helps far less, or only in
narrow cases. This skill measures the behavioral delta **before** shipping, by running
real agents on control vs treatment and counting what they actually do.

Intuition is unreliable here: the single most-favorable task always overstates a change,
and effects are strongly model-dependent. A change that reads as a near-total fix on one
task and one model can be safe-but-narrow — or a wash — once held-out tasks and a stronger
model are added. Measure, don't guess.

## Core method

- **Measure the decision, not the outcome.** Real tools hit live systems; you can't and
  shouldn't run them. Measure *which tool/command the agent reaches for* — captured by
  PATH-shadow stubs that log the invocation and return canned output.
- **Faithful auto-load = the agent's own headless mode** (`claude -p`, `codex exec`) in a
  copied repo dir whose context surface was wired by *the copy's own* connector
  (`connect-agent.sh <agent> --render-specs-only` — `REPO_DIR` resolves to the copy, so it
  points at the patched files, side-effect-free). That loads the copy's
  `CLAUDE.md`/`AGENTS.md`/scope chain like a real session, for whichever agent — no
  hand-rolled rewrite to drift. In-session sub-agents do **not** replicate the auto-load
  and silently invalidate the test.
- **A/B by content only.** control = trunk; treatment = trunk + the one change. Both carry
  everything else (including the doc the change surfaces) — the hypothesis is that
  *surfacing in auto-loaded context* beats *available-but-must-be-pulled*.
- **Discriminator constraint.** A task only measures the change if its target is
  (a) affected *only* by the change — not discoverable another way (absent from the rest
  of auto-loaded context, and not findable on the filesystem by control), and
  (b) observable — a *bare* shell command a PATH stub can shadow. MCP-invoked and
  full-path tools need a transcript capture this harness doesn't have.
- **Dev + held-out tasks, with negatives.** Iterate treatment variants on a dev set;
  report on a held-out set you touch **once**. Always include negative / no-tool tasks: a
  change that improves discovery but causes *over-reaching* is not a win. The held-out +
  negative tasks are what catch overfitting.
- **Run the production model.** Effects are strongly model-dependent — testing the wrong
  model gives the wrong verdict.
- **Concurrency:** default parallel **2**. Several concurrent headless agents can fail with
  empty stdout; the runner retries when stdout is empty (a real failure), distinct from a
  legit no-tool run (empty stublog but real stdout), so negatives aren't corrupted.

## Sandbox scope

Sandboxes render **guest** (global scope only) — root `AGENTS.md`/`CLAUDE.md` plus global
skills and tool docs, which is what most framework changes touch. A change to a *deeper*
scope (person/host/group) needs that scope's connected leaf wired into the sandbox, which
this harness doesn't set up — test those by hand or extend the harness.

## Procedure

1. **Frame it.** Express the change as a diff vs trunk:
   `git diff <trunk> -- <changed files> > tmp/change.diff`. control = trunk; treatment =
   trunk + this diff. (An empty diff / `-` / `/dev/null` is an A/A noise-floor run.)
2. **Design tasks** per the rules above — discriminating positives + negatives, split
   dev/held-out — in a tasks file (`scripts/tasks.example.sh` is the template). Prompts
   must **not** name the target tool; graders are deterministic regexes on the stub log
   (or "no stub fired" for negatives).
3. **Add stubs** for every tool a task measures: a one-line shadow in `scripts/stubs/`
   (copy `scripts/stubs/example-tool`) that appends its invocation to `$STUB_LOG`. The
   stub's name must be the bare command the agent would type.
4. **Run** the harness — it builds the sandboxes and runs the matrix:
   ```bash
   AGENT=claude skills/exobrain-ab/scripts/run.sh tmp/change.diff <tasks.sh> [N=12] [parallel=2] [model] [dev|holdout|all|<id>]
   ```
   Inspect the rendered sandboxes first with `BUILD_ONLY=1` (builds + renders, no agent
   runs). Output: per-arm `control correct` vs `treatment correct` k/N, and per-run CSVs
   under `tmp/exobrain-ab/results/`.
5. **Read the verdict honestly.** A real win shows on held-out tasks, on the production
   model, *without* lifting the negatives. If only the single best dev task moves, the
   change is narrow — say so.

## Files

- `scripts/run.sh` — builds control/treatment sandboxes, renders each via its own
  `--render-specs-only`, runs the task matrix, prints the summary.
- `scripts/run_one.sh` — one graded run (PATH-shadow stubs → stublog → verdict); spawned
  in parallel by `run.sh`.
- `scripts/stubs/` — PATH-shadow tool stubs (ship `example-tool`; add one per measured tool).
- `scripts/tasks.example.sh` — the `TASKS=()` format and discriminator constraint.

All sandboxes and results land under the repo's gitignored `tmp/`; nothing touches global
state (the connector's `--render-specs-only` stops before any out-of-dir write).
