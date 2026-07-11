---
id: 0064
title: Track person/group scopes; reserve a gitignored local/ scope for private context
date: 2026-07-11
tags: [scopes, privacy, gitignore]
touches_invariant: false
files: [.gitignore, AGENTS.md, domains/exobrain/scopes.md]
---

## Problem

Gitignoring `people/` and `groups/` wholesale conflates *instance-specific* with *private*. An exobrain that syncs across machines (or is shared by a family or team) wants its person and group scopes committed — that's the point of the repo. Meanwhile genuinely private context — org identifiers, internal hostnames, anything that must never land in the repo — had no sanctioned home: every tracked layer is visible to anyone with repo access, so "put it in your person scope" quietly publishes it.

## Pattern

Separate the two axes:

- **Person and group scopes are tracked**, like any other content. Whether a scope is instance-specific says nothing about whether it may be committed.
- **`local/` at the repo root is the private layer**: a standalone gitignored scope. It is an ordinary scope in every other way — an `AGENTS.md` dir, connected as a leaf in `connected_scopes`, resolved through the standard shallow→deep walk. Only its git status differs.
- A setup that connects only `local/` (no person scope in the chain) sets `person` in `.exobrain.json` so skill owner-match keeps working — the id is location-independent.

Private data plugs into shared machinery only through gitignored files; anything tracked is public to the repo's audience.

## Reference (illustration only)

```gitignore
# Private local scope — context that must never land in the repo (person/group
# scopes are committed like any other content).
/local/
```

```json
{ "connected_scopes": ["local"], "person": "alex", "agents": ["claude"] }
```

## Adapt notes

- Remove any `people/` / `groups/` ignore rules; add the anchored `/local/` rule so only the root dir is ignored.
- An instance that keeps its person scopes private-by-omission (public repo, personal content elsewhere) can still adopt `local/` as the private layer and simply not create person scopes.
- No invariant touched: scope-resolution semantics are unchanged — `local/` joins the walk like any other leaf.
