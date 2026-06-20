---
id: 0038
title: Add a tools-management skill — onboard / status / add / refresh / doctor over the tool catalog
date: 2026-06-18
tags: [tools, skills, onboarding]
touches_invariant: false
files: [skills/exobrain-tools/SKILL.md, skills.json, tools/README.md, domains/exobrain/tools.md]
---

## Problem

The tools catalog is one self-contained doc per tool (presence at a scope = registration), and each doc carries its own Setup → Verify. That's enough to connect a tool by hand, but once an instance has more than a couple of tools the human work repeats: discover what exists across the connected scope chain, decide what's wanted, walk each doc's credential and verify steps, and remember per-tool state. There's no single operational entry point for "set me up", "what do I have?", or "something's broken" — and nothing tracks which tools are wanted, credentialed, and verified on this machine.

## Pattern

Add a small **dispatcher skill** over the catalog with a few sub-operations — `onboard` (fresh checkout → set up, goal-driven tool menu), `status` (what's connected/broken), `add <tool>` / `refresh <tool>` (one tool), `doctor` (re-verify all wanted). It **discovers** tools by globbing each connected scope's `tools/` over the resolved scope chain (deepest wins), **reads each doc on demand** for its Setup/Verify, and **tracks per-machine state** in a `tools` block in the untracked `.exobrain.json` (`wanted` / `env` / `verify` / `verified_at` / `last_error`). The skill *drives* the docs; it does not duplicate them, and it **never reads, echoes, or stores a secret value** — it provisions *where* each credential lives (`.env`, `keychain:<svc>`, OAuth, `config:`, SSH) and lets the tool read it at use-time. Keep it single-responsibility: tool management only — repo refresh stays with the post-merge hook, framework adoption with the evolve skill.

## Reference (illustration only)

Discover the resolved tool set by sourcing the skills registry for `build_scope_chain` and globbing `tools/`:

```bash
source "$REPO/scripts/skills-registry.sh"
LEAVES=(); while IFS= read -r l; do [ -n "$l" ] && LEAVES+=("$l"); done \
  < <(jq -r '(.connected // []) | .[]' "$REPO/.exobrain.json")
for scope in $(build_scope_chain "$REPO" "${LEAVES[@]}"); do
  dir="$REPO/tools"; [ "$scope" != global ] && dir="$REPO/$scope/tools"
  ls "$dir"/*.md 2>/dev/null   # key by stem; skip README.md / template
done
```

## Adapt notes

- **Reuse the connected-scope-chain resolver** the connector already exposes, and read connected leaves from your config's own key — don't hardcode a scope shape or duplicate the chain logic.
- **Map goals to the instance's own use-case glossary** (the tags defined in `tools/README.md`), not a fixed list — instances carry different tool mixes.
- **Security is invariant**: the skill names where a credential lives and pauses for the human to paste/enter it; it never runs a secret-reveal command (e.g. keychain `-w`) itself.
- When you ship the skill, flip any catalog docs that disclaim it ("ships the docs, not the skill") to reference it, and register it in `skills.json` (`optional` tier keeps it off the always-loaded surface).
