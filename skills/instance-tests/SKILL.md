---
name: instance-tests
description: >
  End-to-end tests of a real exobrain instance against a real environment — the
  non-hermetic counterpart to exobrain-tests. Where exobrain-tests runs hermetic
  behavioral cases over a snapshot copy with the local agent CLI (no network, no
  creds), instance-tests stands up a fresh machine (Docker) and exercises the
  actual onboarding path: cloning the instance's origin over the network, running
  connect-agent, and (optionally) a no-context headless agent walking the
  onboarding steps. Use after editing connect-agent's connection flow or the
  onboarding docs, or to confirm a fresh machine can clone + connect end to end.
  Requirements are per case (Docker, an https origin, a headless token); cases
  self-skip when unmet.
tier: optional
---

# instance-tests — real-environment onboarding suite

Non-hermetic, real-environment end-to-end tests of *this* exobrain instance. The
sibling of [`exobrain-tests`](../exobrain-tests/SKILL.md): that suite verifies agent
**behavior over context** in a hermetic sandbox; this one verifies the **real
clone + connect flow** on a genuinely fresh machine, which needs Docker and network
no hermetic case may touch.

## When to use

- After editing `connect-agent.sh`'s connection flow — confirm a fresh machine
  still onboards correctly against a real clone.
- After editing onboarding docs — confirm the steps they describe still work.
- To check that a new machine can clone + connect end to end.

## Run

```bash
SUITE=skills/instance-tests/scripts
$SUITE/run.sh --list                       # list cases + their requirements
$SUITE/run.sh                              # all cases, default mode (probe)
$SUITE/run.sh --cases clone-and-connect    # one case
$SUITE/run.sh --mode agent                 # full headless-agent e2e (needs a token)
```

Exit: `0` all selected cases passed · `1` some failed · `2` harness error. Cases whose
requirements are unmet are **skipped** (reported, not failed).

## Modes (per case)

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

## Requirements

Declared per case in `cases/<name>/meta.json` (`requirements`, `requirements_agent`).
`run.sh` checks them and skips a case it can't satisfy:

- **docker** — Docker daemon running.
- **origin-https** — the instance's `origin` remote is an `https://` URL and
  `git ls-remote` reaches it (anonymous for public repos; a private origin needs
  credentials the container can use — see the case's Dockerfile notes).
- **oauth-token** (agent mode) — `CLAUDE_CODE_OAUTH_TOKEN` present in the instance `.env`.

## Adding a case

Create `cases/<name>/` with a `meta.json` (`name`, `description`, `requirements`,
optional `requirements_agent`, `modes`) and a `run.sh` that receives `$INSTANCE_DIR`,
`$CASE_DIR`, `$MODE` and exits `0`=pass / non-zero=fail. Everything else (Dockerfile,
fixtures, probes) is the case's own business — instance tests vary too much in infra
for a shared template. Judge-style grading can source
`../exobrain-tests/scripts/lib/check-helpers.sh` rather than reimplementing it.
Generated artifacts go under the case's gitignored `out/`.
