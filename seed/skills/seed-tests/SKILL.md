---
name: seed-tests
description: >
  Test the canonical seed end to end. Seed-only — this skill exists only in the
  seed, never in a rendered instance. Builds a fresh instance from the seed via
  create-instance (a builder agent), verifies the bootstrap with the create-valid
  static checks, then runs the universal exobrain-tests behavioral suite against
  the built instance. Also houses the deterministic connector/registry harness
  (test-connect-agent.sh) — hermetic unit tests for connect-agent.sh and the
  skills registry, no agents involved. Use to test the seed's bootstrap and
  framework after changing create-instance, the connector, or the registry.
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
`seed/` leaked, connection established), then (3) delegates to the universal
[`exobrain-tests`](../../../skills/exobrain-tests/) suite with `--instance <built>`
for the behavioral cases. Consumes real agent usage; never auto-runs.

## Connector / registry harness (deterministic)

```bash
seed/skills/seed-tests/scripts/test-connect-agent.sh            # all
seed/skills/seed-tests/scripts/test-connect-agent.sh <pattern>  # filter by name
```

Hermetic: builds fake exobrains in temp dirs and asserts scope-chain resolution,
opt-in skill tiers, flag-driven identity, the per-agent surfaces, the tools index,
and validator/fetcher plumbing — exercising the framework scripts in `<repo>/scripts/`.
No agent CLIs, no usage; run it first when changing the connector or the registry.
