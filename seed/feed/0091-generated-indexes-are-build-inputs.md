---
id: 0091
title: Write a generated index only to the surface that reads it
date: 2026-07-28
tags: [connect-agent, agents, codex, openclaw]
touches_invariant: false
files: [scripts/connect-agent.sh, seed/skills/seed-tests/scripts/test-connect-agent.sh]
---

## Problem

A connector that generates intermediate artifacts — an optional-skills index, a tools index, a domains index — naturally writes them to one path per agent and lets each delivery branch pick them up. That works while every agent is *delivered* the same way. Once one agent's context arrives as a single composed file with the indexes inlined, its copies on disk are read by nothing, and the path they land on is the agent's **home config dir**: shared across every checkout on the machine.

Three costs follow. Two exobrains on one machine overwrite each other's copies, so whichever relinked last wins a file neither agent consults. Every copy goes stale the moment any other instance relinks. And a render advertised as side-effect-free stops being one: rendering a throwaway sandbox rewrites files in the human's home dir.

## Pattern

**A generated artifact belongs only on the surface that reads it.** When an agent's context is delivered as one composed file, the intermediate indexes are *build inputs*, not deliverables — they exist to be inlined and then discarded.

Generate them into temp files, clean up on exit, and let each agent's delivery branch decide what to persist. An agent whose surface resolves imports by filename needs durable copies, so its branch writes them — into a repo-local, gitignored dir that travels with the checkout. An agent that receives the same content inlined persists nothing.

The test for where a generated file goes: *which surface reads it?* Not *which dir belongs to this agent?* — the agent's home dir is a plausible-looking answer that no consumer ever opens.

Persisting is per-branch, so it must handle the empty case too: when nothing was generated this run, clear whatever an earlier relink left at the destination, or the surface keeps importing an index that no longer describes the checkout.

On relink, migrate: remove the copies the previous model left in the home dir. Delete only files this connector would have written — match on the generated heading, so a same-named file of the human's own survives.

## Reference (illustration only)

```sh
# build inputs, not deliverables — temp files, cleaned up on exit
INDEX_FILE="$(mktemp)"; TOOLS_INDEX_FILE="$(mktemp)"; DOMAINS_INDEX_FILE="$(mktemp)"
trap 'rm -f "$INDEX_FILE" "$TOOLS_INDEX_FILE" "$DOMAINS_INDEX_FILE"' EXIT
# an index with nothing to list removes its temp, so `[[ -f … ]]` reads as
# "was anything generated?" for both the composer and the import manifest

install_index() {                      # only the import-manifest agent's branch calls this
    local tmp="$1" dest="$2"
    if   [[ -f "$tmp"  ]]; then cp "$tmp" "$dest"
    elif [[ -f "$dest" ]]; then rm -f "$dest"   # source went away — drop the stale copy
    fi
}

prune_home_indexes() {                 # migration, in the inlined-delivery branches
    while IFS='|' read -r file heading; do
        [[ -f "$HOME_CFG/$file" ]] || continue
        [[ "$(head -n 1 "$HOME_CFG/$file")" == "$heading" ]] || continue   # ours, not theirs
        rm -f "$HOME_CFG/$file"
    done <<'LEGACY'
optional-skills.md|# Optional skills
tools-index.md|# Tools
domains-index.md|# Domains
LEGACY
}
```

## Adapt notes

Check the *source of truth for where each artifact lives* before changing code: if the machinery docs already describe the indexes as inlined for the composed-file agents and as files only for the import-manifest agent, the docs are right and only the code drifted — fix the code and leave the docs alone.

An agent that uses an `@-import` manifest still needs the real files on disk, so this is not "stop writing the indexes" — it's "write them once, on the one surface that resolves them by name." Keep that write repo-local and gitignored so a worktree or sandbox render carries its own copy.

Watch for a stale assignment when moving the paths: if a later line still points a variable at the destination, the persist step copies a file onto itself, which fails and aborts under `set -e`. Prove the fix both ways — assert the home dir holds nothing but the memory-disable config after a render, and assert the composed surfaces still carry every inlined index, so the dead write is gone without losing context. A byte-level diff of the import-manifest agent's generated surface, rendered before and after, confirms that agent is untouched.

No scope-resolution or security invariant changes — chain order, deepest-wins, and the content delivered to every agent are identical; only where an intermediate file is stored moves.
