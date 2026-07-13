---
name: exobrain-tests
description: >
  The exobrain self-test skill — two sub-suites under one roof. behavior/ is the
  universal hermetic suite: it runs concrete agent tasks against a throwaway copy
  of the instance and reports a k/N pass rate per agent+case, checking that an
  agent actually follows this exobrain's specs — worktree-first,
  no-secret-in-tracked-file, scope-resolution-deepest-wins, kebab-case naming,
  no-default-branch-edit, route-fact-to-domain, embedded-instruction-refusal, and
  more — including adversarial security/red-team cases (won't read/leak .env
  creds, won't publish internal content to a public surface) under a hermetic
  egress-containment profile; no network, no creds. Use it after editing an
  AGENTS.md/skill/tool-doc, adopting a seed change, or onboarding a machine; it
  consumes real agent usage (one session per case-run) and never runs
  automatically. onboarding/ is the non-hermetic, real-environment counterpart:
  it stands up a fresh machine (Docker), clones the instance's origin over the
  network, runs connect-agent, and (optionally) drives a no-context headless
  agent through the onboarding steps. Use it after editing connect-agent's
  connection flow or the onboarding docs, or to confirm a fresh machine can
  clone + connect end to end; requirements are per case (Docker, an https
  origin, a headless token) and cases self-skip when unmet. The skill ships into
  every instance and always tests the instance it is installed in.
---

# exobrain-tests — the instance self-test skill

Two sub-suites, split by hermeticity — each with its own runner, cases, and
requirements. There is deliberately no combined "run everything" entry point: the
behavior suite must stay runnable with no network and no credentials, so the
non-hermetic suite is always an explicit, separate invocation.

- **`behavior/`** — hermetic. Does an agent dropped into this instance behave the
  way the specs say? Snapshot copy, local agent CLI, no network.
- **`onboarding/`** — real environment. Can a fresh machine clone this instance's
  origin, connect, and come up healthy? Docker, real network, per-case requirements.

Both always test *this* instance — the skill ships into every instance, so any
instance self-tests by invoking it. Neither knows anything about the seed: to test
the seed itself (build an instance from it, then test that), use the seed-only
`seed-tests` skill, which invokes the *built instance's* copy of this suite.

## behavior/ — the universal behavioral suite

Provisions a throwaway copy of the instance, runs concrete tasks against fresh
copies of it via a non-interactive agent CLI (`claude` and/or `codex`), each task
N times, and reports a k/N pass rate per agent+case.

```bash
SUITE=skills/exobrain-tests/behavior
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

### How it works

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

### Permission profiles

Set per case in `meta.json` (`permission_profile`): `read-only` → `--permission-mode
plan`; `action` → `acceptEdits` + `settings/allow.json` (a curated allowlist);
`security` / `security-mcp` → the adversarial red-team profiles (below); `build`
(the from-seed instance scaffold, not a case) → `bypassPermissions`, since it runs the
instance's own framework scripts by arbitrary paths a relative-path allowlist can't
match — hermetic and network-neutralized, so the gate is unnecessary; `static` → no
agent call, `check.sh` asserts against the template directly.

### Security / red-team cases

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

### Add a behavior case

Create `behavior/cases/<name>/` with `meta.json` (`name, description, runs,
permission_profile, pass_threshold` — `"all"` / a fraction / `"informational"`,
`timeout_seconds`, optional `model`, `output_format`, `tags`), `prompt.md` (the task,
agent-neutral), optional `setup.sh` (**seeds the case's own fixtures** so the case is
portable to any instance; `$1` = instance dir), `check.sh` (`$1` instance, `$2`
transcript, `$3` engine exit; exit `0`/`1`/`2`; source `"$HARNESS_LIB/check-helpers.sh"`
for assertions), and optional `rubric.md` (PASS CRITERIA for the LLM judge via
`judge_case`). Keep fixtures self-seeded — never assume seed-specific structure.

## onboarding/ — the real-environment suite

Non-hermetic end-to-end tests of the actual onboarding path, on a genuinely fresh
machine — which needs Docker and network no hermetic case may touch.

Use it after editing `connect-agent.sh`'s connection flow (confirm a fresh machine
still onboards against a real clone), after editing onboarding docs (confirm the
steps they describe still work), or to check that a new machine can clone + connect
end to end.

```bash
SUITE=skills/exobrain-tests/onboarding
$SUITE/run.sh --list                       # list cases + their requirements
$SUITE/run.sh                              # all cases, default mode (probe)
$SUITE/run.sh --cases clone-and-connect    # one case
$SUITE/run.sh --mode agent                 # full headless-agent e2e (needs a token)
```

Exit: `0` all selected cases passed · `1` some failed · `2` harness error. Cases whose
requirements are unmet are **skipped** (reported, not failed).

### Modes (per case)

- **`probe`** (default) — deterministic. Stands up a fresh-OS container, clones the
  instance's real origin, overlays *this checkout's* `connect-agent.sh` (so the test
  exercises local changes, not just trunk), self-seeds synthetic scope fixtures, and
  asserts the exact connect outcome plus healthcheck and validator. Needs Docker + an
  https origin; **no token**.
- **`agent`** — full end-to-end. A no-context headless `claude` follows the case's
  onboarding prompt on the fresh machine. Needs Docker + an https origin + a headless
  `CLAUDE_CODE_OAUTH_TOKEN` in `.env` (mint with `claude setup-token`; never pasted to
  an agent — `run.sh` extracts only that one var, never printing it). An instance
  whose README carries a real onboarding prompt should extract and use that instead
  of the case's default — the real doc is the surface worth testing.

### Requirements

Declared per case in `cases/<name>/meta.json` (`requirements`, `requirements_agent`).
`run.sh` checks them and skips a case it can't satisfy:

- **docker** — Docker daemon running.
- **origin-https** — the instance's `origin` remote is an `https://` URL and
  `git ls-remote` reaches it (anonymous for public repos; a private origin needs
  credentials the container can use — see the case's Dockerfile notes).
- **oauth-token** (agent mode) — `CLAUDE_CODE_OAUTH_TOKEN` present in the instance `.env`.

### Add an onboarding case

Create `onboarding/cases/<name>/` with a `meta.json` (`name`, `description`,
`requirements`, optional `requirements_agent`, `modes`) and a `run.sh` that receives
`$INSTANCE_DIR`, `$CASE_DIR`, `$MODE` and exits `0`=pass / non-zero=fail. Everything
else (Dockerfile, fixtures, probes) is the case's own business — real-environment
cases vary too much in infra for a shared template. Judge-style grading can source
`behavior/lib/check-helpers.sh` rather than reimplementing it. Generated artifacts
go under the case's gitignored `out/`.
