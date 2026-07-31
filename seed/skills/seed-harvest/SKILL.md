---
name: seed-harvest
description: "Harvest universally useful improvements from this seed's downstream exobrain instances back up into the framework. Use when the user wants to pull good ideas up from their instances, backport an instance's improvement into the seed, see what the instances have diverged on, or check whether any instance has something worth generalizing. Scans the instances listed in .exobrain.json, proposes candidates as an interactive checkbox list, then re-synthesizes each pick into the seed's structure — genericized, card-backed, and recorded so declined candidates never come back."
---

# seed-harvest

The **instance → seed** direction of propagation. `exobrain-evolve` carries the
seed's changes *down* to an instance (that direction is called *adoption*); this
skill gathers an instance's own improvements *up* into the framework body, where
every future instance inherits them. Background: `knowledge/exobrain/propagation.md`.

Seed-only — an instance has no downstream to harvest from.

**Two hard rules frame everything below.** Instances are private and the seed is
public, so nothing crosses without genericization (§6). And an instance's
improvement is not automatically the framework's: most divergence is local fit,
not a universal pattern (§3).

## Sources

The instances to scan live in `.exobrain.json` under `instances` — gitignored and
per-machine, which is the only place they may live: an instance name can carry an
org, client, or person identity, and every tracked byte of this repo is public.

```json
{ "instances": ["acme/exobrain-alex", "/abs/path/to/a/checkout"] }
```

An entry is a **GitHub slug** (cached into the gitignored `src/<repo>/`, the same
convention `exobrain-evolve` uses for the seed) or an **absolute local path** (read
in place, never pulled or written). If the key is missing, ask the user for the
list and write it — don't guess from sibling directories.

## 1. Worktree, then resolve

Start the worktree first (`AGENTS.md` § Git workflow). Then:

```bash
seed/skills/seed-harvest/scripts/scan.sh --fetch     # clone-or-pull slugs, then list
seed/skills/seed-harvest/scripts/scan.sh --drift     # per-instance framework drift
```

`--fetch` touches the network only for slugs and only into `src/`. Report any
instance that comes back `absent`, `dirty`, `stale`, or `not-an-exobrain` — a dirty
checkout means you're reading uncommitted work, which is fine to harvest but worth
naming.

## 2. Build the candidate list

`--drift` gives you the mechanical half, in two signals:

- **`differs <path> +N/-M`** — a framework file this instance changed, sized against
  the seed: **`+N` is what the instance has and the seed doesn't**, so it's the
  harvest-relevant number; `-M` is usually just the instance lagging. Triage by `+N`
  and read those diffs. The changed hunk is the candidate, not the whole file.
- **`only-there`** — a skill or script the seed lacks entirely. The richest lane.

A file the instance simply lacks is not reported: that means it's behind, which is
adoption's business, not the harvest's.

Read the actual diffs for anything promising. Then add what the scan can't see:
conventions in the instance's root `AGENTS.md`, patterns in its meta-domain docs,
and helper structure inside its skills. Instances that restructured (older ones use
`domains/` and a differently-shaped person scope) are mapped by *role*, not path.

## 3. Filter for universal

This is the judgment that makes the skill worth running. A candidate qualifies only
if it would help an exobrain that shares **none** of this instance's content:

- It touches the **framework body** — `scripts/`, `skills/exobrain-*`,
  `knowledge/exobrain/`, the root spec, `skills.schema.json`, `tools/README.md`.
- It is a **pattern**, not a payload — a mechanism, gate, or convention rather than
  a fact about that instance's life or work.
- It survives **renaming everything** — if it only makes sense with that instance's
  scope names, tool set, or directory layout, it isn't universal yet; generalize it
  or drop it.

Reject outright, without proposing: the instance's knowledge domains and workspaces
(the seed carries only the `exobrain` meta-domain — never scaffold content domains
here), its `people/`/host scopes, its per-tool docs, its `skills.json`, its adoption
ledger, and any workaround for one machine. Reject anything whose value depends on
the instance's org, employer, client, or private repos — that's not a harvest, it's
a leak.

Rate each survivor **universal** (pre-checked in the menu) or **maybe** (offered
unchecked). When you're unsure, it's `maybe`.

## 4. Skip what the ledger already settled

Read `seed/harvest-ledger.md`. Drop any candidate already recorded as adopted, and
any recorded as declined whose source hasn't changed since. Without this the same
long-standing divergences resurface every run and the menu becomes noise.

## 5. Ask — the checkbox list

Write the survivors to a TSV (`<id>`, `<precheck 0|1>`, `<label>`; a line starting
`#` is a non-selectable header) under `tmp/`, then:

```bash
seed/skills/seed-harvest/scripts/pick.sh tmp/harvest-candidates.tsv
```

Type a number to toggle, `a` all, `n` none, Enter to accept, `q` to abort. It prints
the selected ids. Group the list by instance, and label each candidate with what
*changes in the seed* — not what the instance did. Never adopt an unpicked
candidate, and never widen a picked one beyond its label.

## 6. Apply — re-synthesize, never copy across

For each pick, in the seed's own structure and vocabulary:

- **Re-synthesize, don't paste.** The instance diverged; the seed's names, paths, and
  spec voice win. A pasted hunk carries the instance's shape and often its identity.
- **Genericize as you write.** Strip org, employer, client, and colleague names,
  internal hostnames and URLs, ticket prefixes, usernames, private repo/tool/project
  names, and any path embedding them. Examples become invented ones (`alex`, `acme`,
  `laptop`); functional fields use the role word `maintainer`.
- **Preserve invariants exactly** — security rules, scope-resolution order, the
  validation contract. A harvested change may extend them, never quietly reinterpret
  them (`propagation.md` § Invariants).
- **Audit the surface** (`AGENTS.md`) — a harvested skill needs a `skills.json`
  declaration and committed proof it earns its reach; a harvested script needs its
  `machinery.md` row and a unit harness under `skills/exobrain-tests/unit/`.

## 7. The depersonalization gate — do not skip

The one step where a mistake is public and permanent. Scan the whole outgoing diff
against the private denylist before anything lands:

```bash
scripts/validate-exobrain.sh
```

A worktree does **not** contain the gitignored `local/` scope, so that scope's leak
scan silently no-ops there. Run it explicitly against the main checkout's copy:

```bash
main="$(dirname "$(git rev-parse --git-common-dir)")"
"$main/local/scripts/validate-exobrain.sh" "$PWD"
```

Then read the diff yourself for what a denylist can't catch — a turn of phrase, an
internal product name, a scenario that only makes sense at one employer. When in
doubt whether something identifies the source, treat it as if it does. PR titles and
bodies pass through no hook: scan them the same way before `gh pr create`.

## 8. Publish a card

Everything harvested lands **outside `seed/`**, so it's a framework change and takes
a feed card under `seed/feed/` — one per durable pattern, describing the problem and
the pattern, never the instance it came from (`seed/feed/README.md`). That card is
how the *other* instances get it.

## 9. Validate, record, persist

```bash
scripts/validate-exobrain.sh
seed/skills/seed-harvest/tests/test-seed-harvest.sh
```

Append a row to `seed/harvest-ledger.md` for every candidate you **presented** —
adopted with its card id, or declined with a one-line reason.

Then land it the normal way (`exobrain-persist`).

## Notes

- **Read-only toward the instances.** The skill never commits, pushes, or edits a
  downstream checkout. An improvement flows up as a re-synthesis here; the instance
  gets it back later through its own `exobrain-evolve`.
- **Declining is a normal outcome.** Most divergence is local fit. A run that
  harvests nothing and records five declines did its job.
