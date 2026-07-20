---
name: seed-tests
description: >
  Test the canonical seed end to end. Seed-only — this skill exists only in the
  seed, never in a rendered instance. Builds a fresh instance from the seed via
  create-instance (a builder agent), verifies the bootstrap with the create-valid
  static checks, then runs the universal exobrain-tests behavioral suite against
  the built instance. Also houses deterministic hermetic unit tests (no agents):
  test-connect-agent.sh (connect-agent.sh + the skills registry) and
  test-authoring-review.sh (authoring-review.sh's engine call). Use to test the
  seed's bootstrap and framework after changing create-instance, the connector,
  the registry, or authoring-review.sh.
---

# seed-tests — test the canonical seed

This skill is **seed-only** (owned by the `seed/` scope; never copied into an
instance). It tests the seed two ways: the **bootstrap + behavioral** pipeline
(agent-driven) and the **connector/registry** logic (deterministic, hermetic).

## Bootstrap + behavioral

```bash
seed/skills/seed-tests/scripts/run.sh                  # build via claude, verify, run all cases
seed/skills/seed-tests/scripts/run.sh --builder codex  # build via a different agent
seed/skills/seed-tests/scripts/run.sh --agents claude  # pass-through to exobrain-tests
seed/skills/seed-tests/scripts/run.sh --list           # list the behavioral cases
```

It (1) builds a fresh instance from the seed by running the real `create-instance`
skill via a builder agent — so the **bootstrap flow is itself exercised** — then
(2) runs the `create-valid` static checks on the result (well-formed instance, no
`seed/` leaked, connection established), commits it, then (3) runs the **built
instance's own** [`exobrain-tests`](../../../skills/exobrain-tests/) for the
behavioral cases — exactly as any instance self-tests. Consumes real agent usage;
never auto-runs.

## Deterministic harnesses

Hermetic unit tests — fake exobrains in temp dirs, no agent CLIs, no usage. Run the
relevant one when changing the script it covers.

```bash
seed/skills/seed-tests/scripts/test-connect-agent.sh       # connector + registry
seed/skills/seed-tests/scripts/test-authoring-review.sh    # authoring-review.sh engine call
# each takes an optional <pattern> to filter tests by name
```

`test-connect-agent.sh` asserts scope-chain resolution, opt-in skill tiers,
flag-driven identity, the per-agent surfaces, the tools index, and validator/fetcher
plumbing. `test-authoring-review.sh` asserts the review's engine call strips inherited
proxy env (else a proxied push silently skips the review) and that a reported
violation exits non-zero. Both exercise the framework scripts in `<repo>/scripts/`.
