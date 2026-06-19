---
id: 0042
title: A side-effect-free connector/registry test harness
date: 2026-06-19
tags: [testing, connector, skills, registry]
touches_invariant: false
files: [scripts/test-connect-agent.sh, scripts/fetch-external-skills.sh]
---

## Problem

The connector and skills registry carry the trickiest logic in the repo — scope-chain resolution, the opt-in declaration/override rule, per-agent surface composition, the tools index, the external fetcher. It's exactly the code where a quiet regression (a `set -e` abort that writes a half-migrated surface; a resolver that enables the wrong skills) ships silently, because the only "test" is connecting a real agent and eyeballing the result. Manual spot-checks also miss exit codes — the bug that shipped a stale Claude surface passed a render that *looked* right but exited non-zero.

## Pattern

Ship a fast, hermetic **test harness** that builds isolated fake exobrains in temp dirs and exercises the connector end to end without touching the real repo or `$HOME`. Two layers:

- **Function-level** — source the registry library and assert resolution directly: chain order shallow→deep; a declaration enables only when forced or owned (a non-owned, non-forced skill is off for others); overrides opt in/out; deepest wins; the tools catalog dedupes deepest-scope-wins.
- **Integration** — render each agent surface side-effect-free (the connector's own render flag, with `HOME`/`CODEX_HOME`/`OPENCLAW_WORKSPACE` pointed at temp dirs) and assert the *output*: the import-capable agent's manifest carries relative imports that each resolve to a real file; the import-less agent's marker block is inlined; an absent index isn't imported; an always skill links but an unlisted one doesn't. **Assert the exit code, not just the files** — a render that aborts mid-way can leave plausible-looking output.

Keep it a plain shell harness (a tiny `run_test` + `assert_*` kit), so it runs anywhere the connector does and needs no test framework. Run it as the first step of verifying any connector/registry change, ahead of the live render and the deterministic validator.

## Reference (illustration only)

```sh
run_test "owner-gated off for others" test_owner_gated_off_for_others
# fixture: declare a skill owned by bob (no force); connect as alice;
# assert tier_of(resolve) == ABSENT.
test_render_no_sidecar_exit0() {           # regression: the set -e abort
    add_person "$r" people/alice           # scope with no per-agent sidecar
    render "$r" claude >/dev/null 2>&1
    assert_eq 0 "$?" "render exits 0 when scopes lack sidecars"
}
```

## Adapt notes

Fixtures must match *your* scope shapes (collections from `scopes.json`) and config key (the connected-leaves field). Point every agent-home env var at a temp dir so an integration render writes nothing outside the sandbox. Don't try to network-test the external fetcher — assert its plan resolution and arg plumbing (it accepts the connected leaves and reports an empty plan cleanly); leave the actual clone to manual or CI runs. This harness is the executable half of the validation-contract invariant: extend it when you add a resolution rule or a surface, never silently drop a case.
