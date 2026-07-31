---
id: 0099
title: Carry the generated agent context into new worktrees
date: 2026-07-31
tags: [scripts, agents, worktree]
touches_invariant: false
files: [scripts/create-worktree.sh]
---

## Problem

Worktree-first means most work happens in a worktree, but the connector writes each
agent's context surface into the **main checkout** and gitignores it. A fresh
worktree therefore has no generated surface at all: no connected-scope manifest, no
optional-skills index, no generated knowledge/tools indexes.

The failure is silent and asymmetric. The same agent, on the same repo, behaves
differently depending on which directory it started in — it doesn't know a person or
host scope is connected, and it doesn't know which optional skills exist, so it
neither loads them nor reports them missing. Nothing errors; the context is simply
thinner than the session in the main checkout, and the agent can't tell.

## Pattern

The worktree creator already links the per-machine files a worktree can't get from
git (`.env*`, the machine-local config). The generated agent surface is the same
class of thing — present in the main checkout, gitignored, needed identically in the
worktree — so link it the same way.

**Symlink, don't copy**: a later relink in the main checkout then reaches every live
worktree, instead of leaving each one pinned to whatever was current when it was
created. Skip any destination that already exists, so tracked files that materialize
on checkout (agent settings) win over the link.

Cover **every** agent's surface, not just the one you happen to use — the generated
files differ per agent, and a worktree should be agent-agnostic.

## Reference (illustration only)

```bash
for src in "$MAIN_ROOT"/.claude/*.md "$MAIN_ROOT"/AGENTS.override.md; do
    [[ -f "$src" ]] || continue
    rel="${src#"$MAIN_ROOT"/}"
    dst="$WORKTREE_PATH/$rel"
    [[ -e "$dst" || -L "$dst" ]] && continue
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
done
```

## Adapt notes

- Map the glob to whatever surfaces your agents actually generate; the shape is
  "every generated, gitignored context file", not a fixed list.
- A manifest that `@-import`s scope specs by **relative path** resolves cleanly for
  tracked scopes, which exist in the worktree too. A **gitignored** scope (a private
  local scope) exists only in the main checkout, so whether its import resolves
  through the symlink depends on your agent's path resolution — verify rather than
  assume, and don't count on this to carry a gitignored scope into a worktree.
- If an agent's surface lives outside the repo entirely (a file under the user's home
  dir), a worktree symlink can't help; that surface is already shared.
