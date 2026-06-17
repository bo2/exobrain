# seed/ — seed-local tooling

Everything under `seed/` operates on **the canonical seed itself**, not on the
exobrain instances it generates. It is **never copied into a rendered instance** —
an instance has nothing to generate and nothing to test against the seed — so the
exclusion is one rule: `create-instance` never copies `seed/`.

| Path | What it is |
|------|-----------|
| [`skills/create-instance/`](skills/create-instance/) | **The generator** — interviews the user and scaffolds a fresh instance. Invoked from an empty directory via the bootstrap prompt (it reads this `SKILL.md` directly), so it's outside the skills registry. |
| [`tests/`](tests/) | **The behavioral harness** — boots a throwaway instance from the seed and runs concrete agent tasks (claude / codex) to check the agent follows the specs. See [`tests/README.md`](tests/README.md). |

Seed-local skills carry no `skills.json` entry and are excluded from
`skills-validate`'s scans; they are not surfaced through the agent's Skill tool.
A rendered instance has no `seed/` at all.
