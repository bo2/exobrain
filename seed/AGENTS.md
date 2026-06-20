# seed — canonical-seed scope

This checkout is the **canonical seed**, not a rendered instance: this scope exists
only here (`seed/` is never copied into an instance). Seed-local tooling lives
alongside this file under `seed/` — see [`README.md`](README.md).

Changes here are framework changes. When persisting one, **publish a feed card**
under [`feed/`](feed/) — one card per durable pattern another instance could adopt
(zero, one, or several per PR), skipping `seed/`-local tooling and instance-specific
content. Format: [`feed/README.md`](feed/README.md). Publishing lives only on the
seed; the shared `exobrain-persist` flow carries no publish step.
