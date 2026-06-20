---
id: 0036
title: Give each agent its own context surface — reference live specs via an @-import manifest
date: 2026-06-18
tags: [connect-agent, agents, scopes]
touches_invariant: false
files: [scripts/connect-agent.sh, CLAUDE.md]
---

## Problem

An earlier improvement (card 0030) composed each connected scope's spec plus the agent-filtered optional-skills index into one generated file per agent, **inlining** the content — a copy. Two costs. First, inlined copies go stale between relinks: editing a connected scope's `AGENTS.md` isn't reflected in the agent's surface until the next recompose. Second, the composed content is **agent-specific** — the optional-skills index is filtered per agent (some skills are agent-scoped), and fetched-skill paths point into per-agent directories. So the moment two agents share one generated file, any relink of one agent (e.g. the post-merge hook relinking every connected agent in turn) makes the **last writer win** and silently corrupts the others' view: wrong skills, paths into another agent's dirs. A single shared file can't represent two agents' filtered views at once.

## Pattern

Give each agent its **own** context surface; never let two agents write the same generated file. Deliver by the lowest mechanism each agent's runtime supports:

- An agent with a **recursive file-import directive** references the source spec files through a small generated **manifest** of imports (no content copy) — one import line per connected deeper scope's `AGENTS.md` (and its per-agent sidecar) — plus a separate per-agent skills-index file. Its surface therefore carries its own filtered view, references the specs **live**, and has correct per-agent paths by construction.
- An agent with **no import mechanism** gets everything **inlined** into its own single self-contained file, read natively.

Because no two agents write the same file, relink order stops mattering and no agent can clobber another's view.

## Reference (illustration only)

```sh
# import-capable agent (resolves @-imports): a manifest of source specs, by reference
compose_scope_manifest() {                      # emits, relative to .claude/:
    for scope in "${CHAIN[@]}"; do
        [[ "$scope" == "global" ]] && continue  # global loads via the checked-in root CLAUDE.md
        # `if`, not trailing `&& echo` — see the set -e adapt note below
        if [[ -f "$REPO_DIR/$scope/AGENTS.md" ]];      then echo "@../$scope/AGENTS.md"; fi
        if [[ -f "$REPO_DIR/$scope/$AGENT_SIDECAR" ]]; then echo "@../$scope/$AGENT_SIDECAR"; fi
    done
}
compose_scope_manifest > .claude/connected-scopes.md
{ echo "@connected-scopes.md"; if [[ -f "$INDEX_FILE" ]]; then echo "@optional-skills.md"; fi; } > .claude/CLAUDE.md

# import-less agent: inline the same context into its own file via marker block
compose_context > "$TARGET_DIR/AGENTS.md"       # or USER.md
```

## Adapt notes

- **Manifest paths must be relative** (`@../<scope>/AGENTS.md`), not absolute — a copied or relocated checkout (test sandbox, worktree) won't resolve absolute paths that point back at the original tree.
- **Verify the import directive's limits first** — that it resolves *nested* imports (the entry point imports the manifest, which imports the specs), arbitrary filenames, and the path depth your manifest needs — before relying on a manifest instead of inlining.
- The import-capable agent must tolerate a **missing** generated file on a fresh clone (regenerate on first connect).
- **Watch `set -e`** when the emitter is a shell function: end every loop branch with an `if` block, not a trailing `[[ … ]] && echo`. A conditional that tests false returns 1, becoming the function's exit status, which trips `set -e` at the `func > file` call site — so the manifest writes but the next steps (the entry-point file, cleanup of the old surface) silently never run. Assert the exit code, not just the file contents, when verifying.
- This **supersedes card 0030's "one composed file" compromise** — sharing was only ever safe while the content was truly agent-neutral. Once any part is agent-filtered, a shared file corrupts whichever agent didn't write last, so split per agent. Keep emitting any per-scope agent sidecars the inlined form carried.
- Preserve the **agent-isolation** rule: each agent's filtered view lives in a surface only that agent reads.
