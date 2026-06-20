---
id: 0021
title: Cache the seed in gitignored src/; record its URL in the adoption ledger
date: 2026-06-14
tags: [propagation, scripts, conventions]
touches_invariant: false
files: [AGENTS.md, scripts/connect-agent.sh, domains/exobrain/propagation.md, domains/exobrain/feed/README.md, skills/exobrain-update/SKILL.md, skills/exobrain-create/SKILL.md]
---

## Problem

Three small frictions around how an instance finds and fetches its seed:

- **The clone was thrown away every update.** `exobrain-update` cloned the seed to
  a temp dir each run — repeated full fetches, nothing reused.
- **The seed address lived only in skill prose.** The URL was hardcoded in
  `exobrain-update`/`exobrain-create` text, not recorded as instance data — so an
  instance seeded from an *intermediate* seed (a fork-of-fork) had nowhere to say so.
  The tempting home, `.exobrain.json`, is wrong: it's gitignored and per-machine,
  but the seed address is shared instance data that must travel with the repo.
- **No standard home for cloned code.** Checkouts an agent makes to read other repos
  had no conventional, ignored, validator-safe place to land.

## Pattern

- **`src/` is the standing home for cloned external code** — gitignored and pruned
  by the validator, so a clone never bloats the repo, registers as a phantom scope,
  or pollutes search. General form: `src/<repo>/`. The seed's update-cache is the one
  **fixed name**, `src/exobrain-seed/`, so it never collides with an instance that is
  itself named "exobrain".
- **The seed repository URL is instance data in the adoption-ledger header**
  (`adopted-feed.md`) — committed, shared across machines, and overridable for
  fork-of-fork lineages. Not `.exobrain.json` (per-machine, gitignored).
- **`exobrain-update` pull-or-clones the cache.** It reads the URL from the ledger
  header (canonical fallback), then `git pull` if `src/exobrain-seed/` exists else
  `git clone` — self-healing on a fresh checkout that doesn't carry the local cache.
- **`exobrain-create` keeps the clone it already makes** as `src/exobrain-seed/`, and
  writes the seed URL into the ledger header it generates.
- **Still a cache, not a remote.** No upstream remote, no merge — propagation stays
  copy-where-undiverged + re-synthesize. Only the clone's location and lifetime change.

## Reference (illustration only)

Pull-or-clone the cache from the recorded URL:

```bash
url="$(read seed url from adopted-feed.md header; default https://github.com/bo2/exobrain)"
if [ -d src/exobrain-seed/.git ]; then git -C src/exobrain-seed pull --ff-only
else git clone "$url" src/exobrain-seed; fi
SRC=src/exobrain-seed
```

Tree-walks for scope flags must skip the cache (alongside `tmp/`, `node_modules`):

```sh
find "$repo_dir" \( -path '*/.git' -o -path '*/node_modules' -o -path '*/tmp' \
  -o -path '*/src' -o -path '*/.src' \) -prune -o -type d ... -print
```

## Adapt notes

- **Scope-resolution hygiene (not an invariant change, but adjacent):** any script
  that scans the tree for `AGENTS.md` scope flags must prune `src/` (and `.src/`), so
  a cached clone never registers as a scope. The validator already prunes them;
  `connect-agent.sh`'s person-scope discovery now does too. Skill/scope resolution
  driven by the *connected leaf's ancestor chain* (not a tree scan) needs no change —
  a clone under `src/` is never an ancestor of the connected leaf.
- The ledger lives at `<your-durable-dir>/exobrain/adopted-feed.md` if you renamed
  `domains/`.
- If your instance was built from an intermediate seed, record *that* URL in the
  header — `exobrain-update` follows it, not the canonical one.
