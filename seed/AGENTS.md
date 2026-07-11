# seed — canonical-seed scope

This checkout is the **canonical seed**, not a rendered instance. The **framework
body** — everything in this tree *except* `seed/` (`scripts/`, the global `skills/`,
the root specs, the `exobrain` meta-domain) — is what every instance inherits:
`create-instance` copies it at birth, and `exobrain-evolve` carries later changes
downstream by copy or re-synthesis. `seed/` is the one directory that never ships —
the generator, the feed, this scope flag — excluded by exactly that one rule.
Seed-local tooling lives under `seed/` — see [`README.md`](README.md).

Because it's a generator and not anyone's personal knowledge base, this checkout
carries only the `exobrain` meta-domain — never real content domains (`health`,
`finances`, `home`, …). Those exist only in instances. Don't scaffold example
domains here; demonstrate domain machinery through the meta-domain itself.

A change **outside `seed/`** is therefore a framework change: when persisting one,
**publish a feed card** under [`feed/`](feed/) so instances can adopt it — one card
per durable pattern (zero, one, or several per PR). Format:
[`feed/README.md`](feed/README.md). The exceptions take no card: a change **under
`seed/`** is seed-local tooling, and a change to a person/host scope is
instance-specific. A framework file lives at the repo root, not under `seed/`, so
the absence of a `seed/` copy never makes a change instance-local. Publishing lives
only on the seed; the shared `exobrain-persist` flow carries no publish step.

## Public repo — depersonalization gate

Every tracked byte here is public. Keep tracked files, commit messages, PR
titles/bodies, and branch names free of personal identifiers and of any
downstream instance's org or work specifics — provenance hygiene applied to the
whole repo, not only to feed cards. The concrete term list is itself private:
it lives in the gitignored `local/` scope (`local/denylist.txt`), and
`validate-exobrain.sh` enforces it over tracked content, outgoing commit
messages, and the branch name at every push. PR titles and bodies pass through
no git hook — scan them against the same list before `gh pr create`, and again
after editing a PR body.
