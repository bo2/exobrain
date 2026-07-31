---
id: 0102
title: A side-effect-free mode refuses defaults that break its contract
date: 2026-07-31
tags: [connect-agent, codex, openclaw, scripts]
touches_invariant: false
files: [scripts/connect-agent.sh, skills/exobrain-tests/unit/test-connect-agent.sh]
---

## Problem

`--render-specs-only` promises no writes outside the checkout, and its exit banner
says so. But two agents deliver part of their surface into a target dir that
defaults to the **real home config** (`~/.codex`, `~/.openclaw/workspace`) when the
`CODEX_HOME` / `OPENCLAW_WORKSPACE` override isn't set. Render a throwaway sandbox
without remembering the env var and the "side-effect-free" run appends to your real
`config.toml` — then prints "(no out-of-dir writes)".

The contract held only by caller discipline: the docs said "point the override at a
throwaway dir", and every scripted caller did. The one-off human invocation is
exactly the caller that forgets.

## Pattern

**A mode that advertises a guarantee enforces it; it doesn't delegate the guarantee
to the caller's environment.** Where honoring the contract is impossible under a
default (the fallback target is the real home config), refuse up front — naming the
override to set and a copy-pasteable form of the fixed command — rather than
proceed and let the banner lie.

Guard at the point where the target is chosen, scoped to the advertising mode only:
a full connect legitimately writes the home config, so the guard tests the mode
flag, not the destination alone.

## Reference (illustration only)

```bash
if $RENDER_ONLY; then
    case "$AGENT" in
        codex) [[ -n "${CODEX_HOME:-}" ]] || {
            echo "--render-specs-only for codex writes config.toml into CODEX_HOME (default ~/.codex)." >&2
            echo "Set CODEX_HOME to a throwaway dir first, e.g.: CODEX_HOME=\$(mktemp -d) $0 codex --render-specs-only" >&2
            exit 1
        } ;;
    esac
fi
```

## Adapt notes

- Sweep the callers before landing: any script that renders these agents must
  already set the override, or the guard breaks it. (In the seed, the ab-eval
  runner sets `CODEX_HOME` per sandbox; the unit harness sets both.)
- An empty-but-set override reads as unset here — that's the desired reading, since
  an empty target dir is not a usable render destination.
- The refusal must name the fix, not just the rule: the caller who hits it is
  mid-task with no context on the connector's delivery model.
- Update the docs that describe the override as advice — it's now a requirement.
