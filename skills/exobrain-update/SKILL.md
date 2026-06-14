---
name: exobrain-update
description: >
  Bring this exobrain instance up to date with the canonical seed
  (github.com/bo2/exobrain). Use when the user wants to update their exobrain,
  pull the latest framework or fixes, sync with upstream, check what's new, or
  borrow a recent improvement. Reads the seed's feed (its changelog), decides
  which changes apply here (permissive), copies what's needed and rewires what
  diverged, then records what was adopted.
---

# exobrain-update

Update this instance from the canonical seed. The model: the seed's **feed is a
changelog** — dated cards, each describing a change (a framework fix, a feature,
or a pattern) with notes on how to adopt it. Read the new cards since this
instance last updated, decide what's useful here, and apply each change the right
way — **copy** the seed's files where this instance hasn't diverged them,
**rewire** (re-synthesize) where it has or where structure differs. Background:
this instance's `<domains-dir>/exobrain/propagation.md`.

**Be permissive by default** — prefer to take improvements, adapting as needed.
This is a procedure; follow it, keeping the user in control of what's adopted.

## Framework files

The files that arrived in this instance as verbatim copies of the seed — the ones
"copy" applies to: `scripts/*`, `skills.schema.json`, `skills/exobrain-reader-lens/`,
`tools/README.md`, `<domains-dir>/exobrain/*` (the concept),
`skills/exobrain-update/`, and the root spec (`AGENTS.md`, agent sidecars).
Everything else (`people/*`, your domains, `scopes.json`, your per-tool docs
under `tools/`, `skills.json`, `workspaces/*`, the adoption ledger) is
**instance-owned — never overwrite it from the seed**.

## 1. Fetch the seed

Read the seed repository URL from this instance's adoption-ledger header
(`<domains-dir>/exobrain/adopted-feed.md`); fall back to
`https://github.com/bo2/exobrain` if it's absent. Cache the seed in a gitignored
`src/exobrain-seed/` and set `$SRC` to that path: if the cache exists, `git -C
src/exobrain-seed pull --ff-only`; otherwise `git clone <url> src/exobrain-seed`.
The cache is local and per-machine — a fresh checkout of this instance won't have
it, so always pull-or-clone rather than assuming it's there.

## 2. Find what's new since last update

- Read this instance's adoption ledger: `<domains-dir>/exobrain/adopted-feed.md` — the card IDs already adopted.
- Read `$SRC/domains/exobrain/feed/` — every card. **New** = cards whose `id` is not in the ledger, oldest first.
- If there are no new cards, say so — but still run the drift check (step 5), then stop.

## 3. Triage — permissive

List the new cards: id · title · one line of what changes · the `touches_invariant`
flag. Default to adopting every card that plausibly applies to this setup; only set
aside one that clearly doesn't fit (a feature for a scope type or tool this instance
doesn't use). Let the user veto or narrow the selection.

## 4. Apply each adopted card

For each card you're taking:

- **Understand** the change — Problem, Pattern, and which files it touches (the
  optional `files:` frontmatter lists the seed paths).
- **Copy where undiverged:** if the change touches framework files and this
  instance's copies still match the seed's *prior* version, copy the seed's current
  version of those files in. Map paths if you renamed the durable-content dir or
  restructured scopes.
- **Rewire where diverged:** if you've locally modified those files, or the card is
  a structural/pattern change that doesn't map 1:1, re-synthesize it into your setup
  per the card's Pattern + Adapt notes. Don't clobber local changes — reconcile them.
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

Append each adopted card to `<domains-dir>/exobrain/adopted-feed.md`: id, title,
today's date, and how you applied it (copied / rewired). That ledger is your
provenance — it's how the next update knows where you left off.

## Notes

- **The ledger is the provenance.** No upstream git remote, no merge — just the
  card IDs you've absorbed. Independent instances, tracked changes.
- **Copying is consistent here.** Framework files arrived as copies from
  `exobrain-create`; refreshing them by copy is the same operation. Re-synthesis is
  for where your instance genuinely diverged in names or structure.
- This is the single "bring me up to date" entry point — it covers both plain
  framework refreshes and pattern borrows.
