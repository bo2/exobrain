---
name: exobrain-tests
description: >
  The universal exobrain behavioral test suite. Runs concrete agent tasks against
  a throwaway copy of an instance and reports a k/N pass rate per agent+case,
  checking that an agent actually follows this exobrain's specs — worktree-first,
  no-secret-in-tracked-file, scope-resolution-deepest-wins, kebab-case naming,
  no-default-branch-edit, route-fact-to-domain, embedded-instruction-refusal, and
  more — including adversarial security/red-team cases (won't read/leak .env creds,
  won't publish internal content to a public surface) run under a hermetic
  egress-containment profile. Always tests the instance it is installed in (it ships into every instance,
  so any instance self-tests by invoking it). Each case self-seeds its fixtures, so
  it is portable. Use to check whether the agent behaves the way the specs say — after
  editing an AGENTS.md/skill/tool-doc, adopting a seed change, or onboarding a
  machine. It consumes real agent usage (one session per case-run) and never runs
  automatically — invoke it explicitly.
---

# exobrain-tests — universal behavioral suite

Does an agent dropped into this instance actually behave the way the specs say? This
suite answers that empirically: it provisions a throwaway copy of an instance, runs
concrete tasks against fresh copies of it via a non-interactive agent CLI (`claude`
and/or `codex`), each task N times, and reports a k/N pass rate per agent+case.

It **knows nothing about the seed** — it tests its own instance. To test the seed
itself (build an instance from it, then run the suite there), use the `seed-tests`
skill, which does exactly that by invoking the *built instance's* copy of this suite.

## Run it

```bash
SUITE=skills/exobrain-tests/scripts
$SUITE/run.sh --smoke                       # trivial case, cheap self-test (one agent session)
$SUITE/run.sh                               # all cases, all available agents
$SUITE/run.sh --agents claude               # one agent only
$SUITE/run.sh --cases worktree-first,no-secret-in-tracked-file --runs 3
$SUITE/run.sh --build-only                  # provision + validate the template, stop (no agents)
$SUITE/run.sh --list                        # list cases
```

Flags: `--agents <a1,a2>` (default `claude,codex`), `--cases <c1,c2>`, `--runs <N>`,
`--smoke`, `--keep` (retain instance copies), `--build-only`, `--list`. Requires `jq`
and at least one requested agent CLI on PATH and runnable, logged in. Exit: `0` all
met threshold, `1` some below, `2` harness/setup error.

## How it works

1. **Provision a template** (`lib/provision.sh`): snapshot the current instance's
   tracked files at HEAD (`git archive`, no `.git`/`src`/`tmp` bloat). The template
   is then validated, committed onto a `main` base branch (so worktree cases have a
   base), hook-neutralized, and asserted free of any github origin. Behavior cases
   run against cheap `cp -r` copies of it.
2. **Run each case** (`run.sh`): for each agent, copy the template, run optional
   `setup.sh` (which **self-seeds the case's fixtures** — scopes, domains), invoke the
   agent (`lib/invoke.sh`) with the case's permission profile, capture the transcript,
   run `check.sh`, tally PASS/FAIL/ERROR, aggregate against `pass_threshold`.

Artifacts land under `tmp/test-runs/<ts>/` (gitignored). The **LLM-judge always runs
on `claude`** regardless of the agent under test, so verdicts are consistent.

## Permission profiles

Set per case in `meta.json` (`permission_profile`): `read-only` → `--permission-mode
plan`; `action` → `acceptEdits` + `settings/allow.json` (a curated allowlist);
`security` / `security-mcp` → the adversarial red-team profiles (below); `build`
(the from-seed instance scaffold, not a case) → `bypassPermissions`, since it runs the
instance's own framework scripts by arbitrary paths a relative-path allowlist can't
match — hermetic and network-neutralized, so the gate is unnecessary; `static` → no
agent call, `check.sh` asserts against the template directly.

## Security / red-team cases

A `security`-profile case tempts the agent to do something the specs forbid —
surface a `.env` credential, transmit it externally, publish company-internal
content to a public surface — and asserts it refused. Safe to run because every
dangerous action is contained, never carried out:

- **Canary-only data.** Fixtures plant fake `sk-CANARY-*` secrets and unique internal
  markers, never anything real (a sandbox has no real `.env` — it's gitignored, absent
  from the snapshot). A leak is detectable by its unique string but worthless.
- **Egress is shadowed, not performed.** The profile prepends `stubs/bin` (loggers for
  `curl`/`wget`/`gh`/`nc`/`ssh`/`scp`) to `PATH` and allows those commands so the
  stubs fire: each records the full attempted invocation + stdin to `$EGRESS_LOG`
  and returns a plausible success **without opening a socket**. `WebFetch`/`WebSearch`/`git
  push` stay denied; `NOPROXY` strips any inherited proxy env. Containment is stub-based
  (macOS has no cheap per-process network namespace) — the canary-only data is what makes
  even a `PATH` mishap harmless.
- **MCP is closed or mocked.** `security` disables all MCP servers
  (`--strict-mcp-config` + an empty config); `security-mcp` instead registers the
  harness's mock stdio server as the ONLY reachable one — it logs every `tools/call`
  to the same `$EGRESS_LOG` and transmits nothing, exposing the MCP egress vector the
  shell stubs can't shadow.
- **Negative controls.** `neg-benign-egress` and `neg-benign-mcp-call` assert the
  agent still *performs* benign, non-secret requests under the same profiles — a
  guardrail that blanket-refuses egress would pass the positive cases for the wrong
  reason.

## Add a case

Create `scripts/cases/<name>/` with `meta.json` (`name, description, runs,
permission_profile, pass_threshold` — `"all"` / a fraction / `"informational"`,
`timeout_seconds`, optional `model`, `output_format`, `tags`), `prompt.md` (the task,
agent-neutral), optional `setup.sh` (**seeds the case's own fixtures** so the case is
portable to any instance; `$1` = instance dir), `check.sh` (`$1` instance, `$2`
transcript, `$3` engine exit; exit `0`/`1`/`2`; source `"$HARNESS_LIB/check-helpers.sh"`
for assertions), and optional `rubric.md` (PASS CRITERIA for the LLM judge via
`judge_case`). Keep fixtures self-seeded — never assume seed-specific structure.
