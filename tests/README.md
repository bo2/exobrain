# tests — exobrain behavioral harness

Runs concrete agent tasks against a freshly-bootstrapped instance via
non-interactive `claude -p`, each task N times, and reports a k/N pass rate per
case. It answers: *dropped into a fresh instance of this seed, does an agent
actually behave the way the specs say?*

## Run it

```bash
tests/run.sh --smoke          # build one instance, run the trivial case (cheap self-test)
tests/run.sh                  # all cases, each at its configured N
tests/run.sh --cases worktree-first,no-secret-in-tracked-file --runs 3
tests/run.sh --build-only     # just build + validate the template instance
tests/run.sh --list           # list cases
```

Flags: `--cases <c1,c2>`, `--runs <N>` (override per-case N), `--smoke`,
`--keep` (retain instance copies for debugging), `--fresh-per-run` (rebuild via
exobrain-create every run instead of copying — slow), `--build-only`, `--list`.

Requires `claude` and `jq` on PATH, and a logged-in Claude session (the harness
runs as you and consumes normal usage). Exit: `0` all cases met their threshold,
`1` some below, `2` harness/setup error.

## How it works

1. **Build a template** (`lib/instance.sh`): clone the local seed under test into
   `tmp/test-runs/<ts>/template/src/exobrain-seed`, then run the real
   `exobrain-create` skill via `claude -p` to scaffold an instance there — so the
   bootstrap flow is itself tested. The template is then validated, committed (to
   establish a `main` base branch), hook-neutralized, and asserted to have **no
   github origin**. Behavior cases run against cheap `cp -r` copies.
2. **Run each case** (`run.sh`): copy the template, run optional `setup.sh`, invoke
   `claude -p` with the case's permission profile, capture the transcript, run
   `check.sh`, tally PASS/FAIL/ERROR, aggregate against `pass_threshold`.

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
  (`"all"` = N/N, or a fraction like `0.8`), `timeout_seconds`, optional `model`,
  `output_format`, `tags`.
- `prompt.md` — the task, piped to `claude -p` on stdin.
- `setup.sh` *(optional)* — seeds fixtures; receives `$1` = instance dir.
- `check.sh` — receives `$1` instance dir, `$2` transcript, `$3` claude exit code,
  plus env `CASE_DIR`, `BASE_COMMIT_COUNT`, `HARNESS_LIB`. Exit `0` pass / `1`
  fail / `2` error. Source `"$HARNESS_LIB/check-helpers.sh"` for assertions
  (`assert_main_untouched`, `worktree_with`, `find_run`, `grep_run`, `validate_at`,
  `judge_case`).
- `rubric.md` *(optional)* — PASS CRITERIA for the LLM judge, used by `judge_case`.
  The judge is strict (no `JUDGE-PASS` ⇒ fail) and runs only after the
  deterministic checks pass.
