---
name: seed-tests
description: >
  Test the canonical seed end to end. Seed-only — this skill exists only in the
  seed, never in a rendered instance. Builds a fresh instance from the seed via
  create-instance (a builder agent), verifies the bootstrap with the create-valid
  static checks, then runs the built instance's own exobrain-tests sub-suites
  against it — unit (free, deterministic) and behavioral (agent-driven). Use to
  test the seed's bootstrap after changing create-instance or anything the
  generated instance depends on.
---

# seed-tests — test the canonical seed

This skill is **seed-only** (owned by the `seed/` scope; never copied into an
instance). It tests one thing no instance can: that the seed **generates a working
instance**. Everything downstream of that — the framework scripts, the agent's
behavior — is tested by the built instance's own
[`exobrain-tests`](../../../skills/exobrain-tests/), which this pipeline invokes.

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
instance's own** `exobrain-tests` sub-suites — `unit` first (free, and a failure
there explains a behavioral failure), then `behavior` — exactly as any instance
self-tests. Consumes real agent usage; never auto-runs.

## Testing the framework scripts

Framework-script harnesses live with the scripts they cover, in
[`skills/exobrain-tests/unit/`](../../../skills/exobrain-tests/unit/). The seed is a
checkout like any other, so run them against it directly — no instance build needed:

```bash
skills/exobrain-tests/unit/run.sh                        # every harness
skills/exobrain-tests/unit/run.sh --harnesses connect-agent
```
