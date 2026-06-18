# seed/tests — behavioral harness

This harness is **seed-local** (it lives under `seed/`, never copied into rendered
instances). It runs concrete agent tasks against a freshly-bootstrapped instance
via a non-interactive agent CLI (`claude` and/or `codex`), each task N times, and
reports a k/N pass rate per agent+case. It answers: *dropped into a fresh
instance of this seed, does an agent actually behave the way the specs say?*

## Run it

```bash
seed/tests/run.sh --smoke               # build one instance, run the trivial case (cheap self-test)
seed/tests/run.sh                       # all cases, all available agents, each at its configured N
seed/tests/run.sh --agents claude       # one agent only
seed/tests/run.sh --cases worktree-first,no-secret-in-tracked-file --runs 3
seed/tests/run.sh --build-only          # just build + validate the template instance
seed/tests/run.sh --list                # list cases
```

Flags: `--agents <a1,a2>` (default `claude,codex`), `--cases <c1,c2>`,
`--runs <N>` (override per-case N), `--smoke`, `--keep` (retain instance copies
for debugging), `--fresh-per-run` (rebuild via create-instance every run instead
of copying — slow), `--build-only`, `--list`.

Requires `jq` and at least one requested agent CLI on PATH and runnable, logged
in (the harness runs as you and consumes normal usage). Exit: `0` all met their
threshold, `1` some below, `2` harness/setup error.

## Agents

`--agents` selects which agent CLIs run the cases; the matrix is agents × cases ×
N. An agent whose CLI is missing or not runnable is **skipped with a notice**, so
a run doesn't fail just because, e.g., `codex` isn't installed.

- **claude** — `claude -p`; profiles map to `--permission-mode` (see below). Loads
  the instance context via the generated `.claude/`.
- **codex** — `codex exec -s <sandbox> -` (prompt on stdin); profiles map to
  sandbox modes (`read-only` / `workspace-write`). codex auto-loads the instance's
  root `AGENTS.md` from the working directory, so no connect step is needed for the
  rules under test — though per-scope sidecars (loaded for claude via `.claude/`)
  are not injected, a fidelity gap that matters only for scope-sidecar-specific
  behavior, not the current cases.

The **template is built once** (agent-neutral content) by a builder agent
(claude when available) and every agent runs against copies. The **LLM-judge
always runs on `claude`** regardless of the agent under test, so verdicts are
consistent — judge cases need `claude` available.

## How it works

1. **Build a template** (`lib/instance.sh`): clone the local seed under test into
   `tmp/test-runs/<ts>/template/src/exobrain-seed`, then run the real
   `create-instance` skill via the builder agent to scaffold an instance there — so
   the bootstrap flow is itself tested. The template is then validated, committed (to
   establish a `main` base branch), hook-neutralized, and asserted to have **no
   github origin**. Behavior cases run against cheap `cp -r` copies.
2. **Run each case** (`run.sh`): for each agent, copy the template, run optional
   `setup.sh`, invoke the agent (`lib/invoke.sh` dispatches on agent) with the
   case's permission profile, capture the transcript, run `check.sh`, tally
   PASS/FAIL/ERROR, aggregate against `pass_threshold`.

Artifacts land under `tmp/test-runs/<ts>/` (gitignored): per-run `stdout.txt`,
`result.json`, and `summary.{txt,json}`.

## Permission profiles

Set per case in `meta.json` (`permission_profile`):

- `read-only` → `--permission-mode plan` (no writes; reasoning/refusal cases).
- `action` / `build` → `--permission-mode acceptEdits` + `settings/allow.json`, a
  curated allowlist that auto-approves safe file ops and the specific commands
  cases need (git, the exobrain scripts) while denying network and
  history-mutating commands. Genuinely risky/un-allowlisted commands are denied
  and the agent adapts.
- `static` → no agent call; `check.sh` asserts against the template directly
  (used by `create-valid`).

## Add a case

Create `cases/<name>/` with:

- `meta.json` — `name, description, runs, permission_profile, pass_threshold`
  (`"all"` = N/N, a fraction like `0.8`, or `"informational"` = reports its k/N
  but never gates the exit code — for aspirational probes of debatable behavior),
  `timeout_seconds`, optional `model`, `output_format`, `tags`.
- `prompt.md` — the task, piped to the agent on stdin (keep it agent-neutral).
- `setup.sh` *(optional)* — seeds fixtures; receives `$1` = instance dir.
- `check.sh` — receives `$1` instance dir, `$2` transcript, `$3` engine exit code,
  plus env `CASE_DIR`, `BASE_COMMIT_COUNT`, `HARNESS_LIB`. Exit `0` pass / `1`
  fail / `2` error. Source `"$HARNESS_LIB/check-helpers.sh"` for assertions
  (`assert_main_untouched`, `worktree_with`, `find_run`, `grep_run`, `validate_at`,
  `judge_case`).
- `rubric.md` *(optional)* — PASS CRITERIA for the LLM judge, used by `judge_case`.
  The judge is strict (no `JUDGE-PASS` ⇒ fail) and runs only after the
  deterministic checks pass.
