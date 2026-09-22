---
name: exobrain-evolve
description: >
  Evolve this exobrain by adopting framework improvements from the canonical
  seed (github.com/bo2/exobrain). Use when the user wants to adopt or borrow
  from the seed specifically — sync this exobrain's framework with the seed,
  take the seed's latest framework cards or fixes, see what's new in the seed,
  or pull a recent seed improvement. Not for refreshing this repo's own
  checkout (that's a plain git pull). Reads the seed's feed (its changelog),
  decides which changes apply here (permissive), copies what's needed and
  rewires what diverged, then records what was adopted.
---

# exobrain-evolve

Update this instance from the canonical seed. The model: the seed's **feed is a
changelog** — dated cards, each describing a change (a framework fix, a feature,
or a pattern) with notes on how to adopt it. Read the new cards since this
instance last updated, decide what's useful here, and apply each change the right
way — **copy** the seed's files where this instance hasn't diverged them,
**rewire** (re-synthesize) where it has or where structure differs. Background:
this instance's `knowledge/exobrain/propagation.md`.

**Be permissive by default** — prefer to take improvements, adapting as needed.
This is a procedure; follow it — the user picks what's adopted (step 3).

## Framework files

The files that arrived in this instance as verbatim copies of the seed — the ones
"copy" applies to: `scripts/*`, `skills.schema.json`, the framework skills
(`skills/exobrain-evolve/`, `skills/exobrain-persist/`, `skills/exobrain-authoring-audit/`,
`skills/exobrain-knowledge/`, `skills/exobrain-ab/`), `tools/README.md`,
`knowledge/exobrain/*` (the concept), and the root spec (`AGENTS.md`, agent
sidecars). Everything else (`people/*`, your knowledge domains, `scopes.json`, your per-tool
docs under `tools/`, `skills.json`, `workspaces/*`, the adoption ledger) is
**instance-owned — never overwrite it from the seed**.

## 1. Fetch the seed

Read the seed repository URL from this instance's adoption-ledger header
(`adopted-feed.md`, at the repo root); fall back to
`https://github.com/bo2/exobrain` if it's absent. Cache the seed in a gitignored
`src/exobrain-seed/` and set `$SRC` to that path: if the cache exists, `git -C
src/exobrain-seed pull --ff-only`; otherwise `git clone <url> src/exobrain-seed`.
The cache is local and per-machine — a fresh checkout of this instance won't have
it, so always pull-or-clone rather than assuming it's there.

## 2. Find what's new since last update

- Read this instance's adoption ledger: `adopted-feed.md` (repo root) — the card IDs already settled here, adopted or declined.
- Read `$SRC/seed/feed/` — every card. **New** = cards whose `id` is not in the ledger, oldest first.
- If there are no new cards, say so — but still run the drift check (step 5), then stop.

## 3. Triage — sort, then ask once per category

Sort every new card into one of four categories, by reading it against this setup:

| Category | What lands here |
|---|---|
| **Mandatory** | A card this instance breaks or drifts without: `touches_invariant: true`, a fix to a framework file this instance carries, or one a later card in the list depends on. |
| **Recommended** | The seed's default — a change that plausibly applies here. |
| **Optional** | `optional: true` in the frontmatter (a preference the seed offers without recommending), or one you judge to be a preference here. |
| **Probably not needed** | A feature for a scope type, tool, or agent this instance doesn't use. |

Show the sorted list — id · title · one line of what changes, under its category
heading — then ask **one question**: for each non-empty category, does the user
want it **applied automatically**, **confirmed card by card**, or **skipped**?
Propose: mandatory and recommended applied, optional confirmed, probably-not-needed
skipped. **Wait for the answer** — this step is never skipped, and a card is
applied only under a category the user chose to apply or confirmed one by one.
Then walk the confirm-by-card categories, one pick per card.

A skipped category's cards are recorded as declined (step 7); tell the user so
when asking. The user can move a card between categories at either step.

## 4. Apply each adopted card

For each card you're taking:

- **Understand** the change — Problem, Pattern, and which files it touches (the
  optional `files:` frontmatter lists the seed paths).
- **Copy where undiverged:** if the change touches framework files and this
  instance's copies still match the seed's *prior* version, copy the seed's current
  version of those files in. Map paths if you restructured scopes.
- **Rewire where diverged:** if you've locally modified those files, or the card is
  a structural/pattern change that doesn't map 1:1, re-synthesize it into your setup
  per the card's Pattern + Adapt notes. Don't clobber local changes — reconcile them.
- **Verify before skipping as already-present:** a card may already be satisfied here.
  "Already present" is a verdict, not a default — back it by reading the files the card
  `touches` and confirming none *contradicts* the card (a partial concept match isn't
  enough; check the specifics, including the card's Adapt-notes caveats). A contradiction
  is **not** adoption — it's a latent bug wearing an adopted label: fix it and record the
  card as rewired.
- **Preserve invariants exactly** for `touches_invariant: true` cards (security,
  scope-resolution order, validation semantics).

## 5. Drift check (safety net)

Compare this instance's framework files (the list above) against `$SRC` for
differences *not* explained by an adopted card — e.g. a fix the seed shipped without
a card. Surface them; copy the ones that are clearly upstream improvements and that
you haven't locally diverged. Leave instance-owned files alone.

## 6. Verify

```bash
scripts/validate-exobrain.sh
scripts/connect-agent.sh <agent> --relink
```

Fix anything that breaks before recording.

## 7. Record

Append each card the user decided to `adopted-feed.md` (repo root): id, title, today's
date, and the outcome — how you applied it (copied / rewired / already-present), or
**declined** with the reason — the user's, or the category it was skipped under. An "already-present" row must cite the
concrete artifact it was verified against (a file, a helper, a behavior) — a vague
citation is a smell that the check was shallow. A declined row is what keeps the card
out of the next run's list; a card deferred without a decision gets no row and
comes back. That ledger is your provenance — it's how the next
update knows where you left off.

## Notes

- **The ledger is the provenance.** No upstream git remote, no merge — just the
  card IDs you've absorbed. Independent instances, tracked changes.
- **Copying is consistent here.** Framework files arrived as copies from
  `create-instance`; refreshing them by copy is the same operation. Re-synthesis is
  for where your instance genuinely diverged in names or structure.
- This is the single "bring me up to date" entry point — it covers both plain
  framework refreshes and pattern borrows.
