# seed — canonical-seed scope

This checkout is the **canonical seed**, not a rendered instance: this scope exists
only here (`seed/` is never copied into an instance). Seed-local tooling lives
alongside this file under `seed/` — see [`README.md`](README.md).

Because it's a generator and not anyone's personal knowledge base, this checkout
carries only the `exobrain` meta-domain — never real content domains (`health`,
`finances`, `home`, …). Those exist only in instances. Don't scaffold example
domains here; demonstrate domain machinery through the meta-domain itself.

Changes here are framework changes. When persisting one, **publish a feed card**
under [`feed/`](feed/) — one card per durable pattern another instance could adopt
(zero, one, or several per PR), skipping `seed/`-local tooling and instance-specific
content. Format: [`feed/README.md`](feed/README.md). Publishing lives only on the
seed; the shared `exobrain-persist` flow carries no publish step.
