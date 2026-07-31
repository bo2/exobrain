# Harvest ledger

What `seed-harvest` has already settled, so a later run doesn't re-propose it. One
row per candidate **presented** — adopted or declined. Declines carry the weight:
without them, the same long-standing divergences resurface every run until the menu
is noise and the skill stops being run.

Seed-local; never copied into an instance. The mirror image of an instance's
`adopted-feed.md`, which records the other direction.

**Keep it generic.** Never name an org, employer, client, internal host, or private
project. That covers the `Instance` column too: an instance's own name is often a
personal handle, so fall back to a count ("three instances") whenever the name is
itself an identifier. If a candidate can't be described without one of these, it was
never harvestable.

| Date | Instance | Candidate | Outcome | Note |
|------|----------|-----------|---------|------|
| 2026-07-31 | exobrain-bo2dev | `create-worktree.sh` links the generated agent context into new worktrees | adopted (0099) | Generalized past the source's Claude-only list to every agent surface. |
| 2026-07-31 | work instance | skills.md § Choosing placement, tier, and force | adopted (0100) | Kept only the decision heuristics; the mechanics were already stated in § Declaration vs override. |
| 2026-07-31 | work instance | exobrain-tools § Adding a new tool | already-present | `tools/README.md` § Adding a tool already carries it, already genericized. Took only the "confirm the catalog discovers it" check. |
| 2026-07-31 | exobrain-bo2dev | `board-surface.sh` + person-scope `board.md` at SessionStart | declined | Adds a new framework concept rather than improving one; revisit if a second instance grows the same need. |
| 2026-07-31 | four instances | `only-there skills/exobrain-domains`, `exobrain-update`, `exobrain-reader-lens` | declined | Pre-rename ancestors of `exobrain-knowledge` / `exobrain-evolve` / `exobrain-authoring-audit` — the instances lagging, not improving. |
| 2026-07-31 | work instance | `only-there` setup scripts for internal systems | declined | Names private tools and hosts; unharvestable by construction. |
| 2026-07-31 | work instance | AGENTS.md expansion (+121) | declined | Rules already present in tighter form, or instance-specific (ticket prefixes, team scope). The seed keeps auto-loaded specs tight by convention. |
| 2026-07-31 | work instance | domains.md scope-design examples (+99) | declined | Examples are named products/systems; the generic pattern beneath them is already covered. |

`Outcome` is `adopted` (with the feed card id that published it) or `declined`
(with the reason — usually "local fit, not universal"). A declined row holds until
the instance changes that area; re-propose only when the source actually moves.
