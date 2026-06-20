# seed/ — seed-local tooling

Everything under `seed/` operates on **the canonical seed itself**, not on the
exobrain instances it generates. It is **never copied into a rendered instance** —
an instance has nothing to generate and nothing to test against the seed — so the
exclusion is one rule: `create-instance` never copies `seed/`.

| Path | What it is |
|------|-----------|
| [`AGENTS.md`](AGENTS.md) | The `seed/` **scope flag** — marks this checkout as the canonical seed (the seed scope auto-joins the chain here, never in an instance). |
| [`feed/`](feed/) | **The change feed** — dated pattern-cards, one per durable framework change, published for instances to adopt via `exobrain-evolve`. Public and generic; instances read it from the seed cache and never carry a copy. |
| [`skills/create-instance/`](skills/create-instance/) | **The generator** — interviews the user and scaffolds a fresh instance. Invoked from an empty directory via the bootstrap prompt (it reads this `SKILL.md` directly), so it stays outside the skills registry. |
| [`skills/seed-tests/`](skills/seed-tests/) | **The seed test driver** — builds an instance from the seed, verifies the bootstrap, runs the universal suite against it, and houses the deterministic connector harness (`test-connect-agent.sh`). Declared in `seed/skills.json`, owned by the seed scope. |

The **universal behavioral suite** is *not* seed-local — it's the global
[`skills/exobrain-tests/`](../skills/exobrain-tests/) skill, which ships into
instances so any instance can self-test; `seed-tests` invokes it against the seed's
built instance.

`create-instance` carries no `skills.json` entry (it bootstraps before any registry
exists); `seed-tests` is registered in `seed/skills.json` and resolves only here,
where the seed scope is active. A rendered instance has no `seed/` at all.
