---
id: 0065
title: Deliver Codex context as an in-repo AGENTS.override.md, not a home-dir block
date: 2026-07-11
tags: [connect-agent, agents, codex]
touches_invariant: false
files: [scripts/connect-agent.sh, .gitignore, CLAUDE.md, domains/exobrain/agents.md, domains/exobrain/machinery.md]
---

## Problem

Delivering an agent's composed context by injecting a marker block into a file under the agent's *home* config dir (e.g. `~/.codex/AGENTS.md`) has two costs: the context lives outside the repo, so it doesn't travel with a worktree or a hermetic sandbox render (the agent in a copied checkout reads stale or absent context), and it pollutes a shared global config the human may also hand-edit. If the agent natively reads a repo-local override file that outranks its base spec, the home-dir block is the wrong transport.

## Pattern

When an agent reads an override spec natively at the repo root — a file that *outranks* the base `AGENTS.md` at the same directory level — deliver its whole composition there, as an in-repo, **gitignored** generated file. The context then travels with the checkout: worktrees, test sandboxes, and side-effect-free renders all load it natively, with nothing written to the agent's home dir except its memory-disable config.

The decisive subtlety: because the override **replaces** the base spec rather than layering on it, the generated file must be **self-contained**. Inline the global/root spec (and the root sidecar) into it — the agent no longer inherits anything from the bare base file once the override exists. This is a third delivery model beyond "import-directive agent `@-imports` a manifest" and "inline-only agent writes a marker block into its memory file": a *native-override* agent gets one composed file the agent reads in place of the base spec.

On relink, migrate off the old transport: strip the legacy marker block the previous scheme injected into the home-dir config, so an upgrade is seamless.

## Reference (illustration only)

```sh
# native-override agent: the override supersedes the base AGENTS.md, so carry the
# root spec + root sidecar ahead of the shared deeper-scope composition.
{
  echo "<!-- scope: global -->"; cat "$REPO/AGENTS.md"
  [ -f "$REPO/$SIDECAR" ] && { echo "<!-- root ($AGENT) -->"; cat "$REPO/$SIDECAR"; }
  compose_context                       # deeper scopes (+ sidecars) + indices
} > "$REPO/AGENTS.override.md"           # gitignored; read natively, outranks AGENTS.md

# migrate off the old home-dir block
awk 'BEGIN{s=0} /<!-- BEGIN exobrain -->/{s=1} /<!-- END exobrain -->/{s=0;next} !s' \
  "$HOME_CFG/AGENTS.md" > t && mv t "$HOME_CFG/AGENTS.md"
```

## Adapt notes

Add the generated override to `.gitignore` — it's per-machine, never committed. Verify the convention validator won't flag the filename: an `AGENTS.override.md` is mixed-case (not an all-uppercase reserved name) and isn't the exact `AGENTS.md` the scope-flag check looks for, so it passes both — confirm your validator's file-name and scope-placement rules agree before shipping. This differs from card 0030's two delivery models: there, the global scope stayed *out* of the composition because the agent auto-loaded it from the checked-in entry point; here it must be inlined, because the override replaces the file that would have carried it. No scope-resolution invariant changes — chain order and deepest-wins are untouched; only the transport to one agent's surface changes. Keep the home-dir write limited to the agent's memory-disable config so a side-effect-free render stays faithful.
