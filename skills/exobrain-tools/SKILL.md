---
name: exobrain-tools
description: "Manage this machine's exobrain tool installation — onboard a fresh setup, show tool status, add or refresh one tool, or diagnose what's broken. Use when the user wants to set up exobrain, connect/add an external data source or tool, see what's connected, or fix a not-connected or failing tool. Drives the per-tool docs under tools/ and the per-machine state in .exobrain.json; it never reads or stores secret values."
---

# Exobrain Tools

Manage this machine's exobrain tool installation. A **tool** is an external system the agent reads from or acts on (see [`tools/README.md`](../../tools/README.md) and [`domains/exobrain/tools.md`](../../domains/exobrain/tools.md)). This skill is a small dispatcher; the per-tool docs under `tools/` are the source of truth for each tool's Setup/Verify — the skill drives them and records per-machine state, it does not duplicate them.

| Sub-op | What it does | When |
|--------|--------------|------|
| `onboard` *(default)* | Walk a fresh checkout from "just cloned" to "everything the user needs is set up". | First-time setup; default if no sub-op given. |
| `status` | Print which tools are connected, which aren't, and what's broken. | *"What tools do I have?"* / *"what's set up here?"* |
| `add <tool>` | Set up one specific tool (the per-tool slice of `onboard`). | User names a tool to add without re-running everything. |
| `refresh <tool>` | Re-provide credentials and re-verify one tool. | A token expired or a verify started failing. |
| `doctor` | Re-verify every wanted tool; report failures with the likely cause. | *"Something's broken."* |

Dispatch on the request: *"set me up"* / *"I'm new"* → `onboard`; *"what do I have?"* → `status`; a named tool → `add`/`refresh`; *"something's broken"* → `doctor`.

## Principles

- **Never read, echo, or store a secret value.** You provision *where a credential lives*, never its contents; the tool reads it at use-time. Say once, before any paste: *"I won't read or repeat this back."* (Root `AGENTS.md` § Security is invariant.)
- **Don't assume the user knows the jargon.** Gloss terms like MCP, OAuth, keychain, or tunnel in a sentence, and say *why* a step exists before asking for it. Read the root `README.md` so your vocabulary matches the user's mental model.
- **Scratch files go in `<repo>/tmp/`** (gitignored), under a `tmp/exobrain-tools/` subdir — never `~/.cache`, `/tmp`, or `~/Downloads`. Preserve-worthy artifacts go in `workspaces/`; credentials in `.env`.
- **Read-modify-write `.exobrain.json`** — merge your changes into the existing file; never overwrite it (the connector and other skills own other keys).

## Data model

**Catalog (tracked).** One self-contained markdown file per tool, `tools/<name>.md` — a file's presence at a scope *is* its registration; there is no JSON registry. The file shape, scope rules, and use-case glossary live in [`tools/README.md`](../../tools/README.md); read it rather than re-deriving them. Discover the resolved tool set by walking the connected scope chain (shallow→deep, deepest wins on a name collision), the same chain the connector resolves:

```bash
bash -c '
  REPO="$(git rev-parse --show-toplevel)"
  source "$REPO/scripts/skills-registry.sh"           # provides build_scope_chain
  LEAVES=(); while IFS= read -r l; do [ -n "$l" ] && LEAVES+=("$l"); done \
    < <(jq -r "(.connected // []) | .[]" "$REPO/.exobrain.json" 2>/dev/null)
  for scope in $(build_scope_chain "$REPO" "${LEAVES[@]}"); do
    dir="$REPO/tools"; [ "$scope" != global ] && dir="$REPO/$scope/tools"
    for f in "$dir"/*.md; do
      [ -e "$f" ] || continue
      case "$(basename "$f")" in README.md|example-tool.md) ;; *) echo "$f" ;; esac
    done
  done
'
```

Key by filename stem; a deeper scope's file shadows a shallower one of the same name.

**State (untracked, per-machine).** Connection state lives in `.exobrain.json` under a `tools` block, alongside the connector's `connected` / `agents` keys:

```json
{
  "connected": ["people/<id>/hosts/<host>"],
  "agents": ["claude"],
  "tools": {
    "<name>": { "wanted": true, "env": "done", "verify": "done", "verified_at": "2026-06-18T..." }
  }
}
```

Per-tool fields: `wanted` (does the user want it) · `env` (`done`/`pending`/`not_needed`/`skipped`) · `verify` (`done`/`pending`/`failed`/`not_applicable`/`skipped`) · `verified_at` (ISO8601 of last success) · `last_error` (short string when `verify == failed`).

## Pre-flight (every sub-op)

1. Confirm cwd is an exobrain repo: `git rev-parse --show-toplevel` resolves to a path containing `tools/` and `skills.schema.json`.
2. Read `.exobrain.json`. If it's missing, the only valid sub-op is `onboard` — for anything else, say *"exobrain isn't set up on this machine yet — run onboard first."*
3. Detect the platform (`uname`); respect each tool doc's **Platforms** line.
4. Build the resolved tool set (snippet above) once; cache it for the run.
5. Ensure `git` and `jq` are available (install via the OS package manager if missing). Only check a tool-specific dependency when a wanted tool's doc requires it.

## Sub-op: `onboard`

Take a fresh checkout from "just cloned" to "set up". Default sub-op.

**Phase 1 — Connect the agent.** If `.exobrain.json` doesn't exist, run `scripts/connect-agent.sh <agent>` (the interactive wizard) and tell the user what it will ask first. If it exists, summarize the current choices in one sentence and offer `--configure` if they're wrong. Confirm the agent marker (`.claude/` · `.codex` · `.openclaw`) was created. If the user only wanted a connected agent (no external tools), jump to the summary.

**Phase 2 — Goal-driven tool menu** (no setup yet). Ask what they want to *do* first — e.g. *"look things up, work with code, run analytics, or manage personal life admin?"* — then map the answer to the use-case tags defined in [`tools/README.md`](../../tools/README.md) (`general` / `engineering` / `analytics` / `personal`, extend as the catalog grows). Propose a starter set: tools whose **Use cases** overlap their tags ("recommended"), plus `general` tools ("useful regardless"); don't surface plumbing-only tools (no use-case tags) — they get pulled in as prerequisites. Skip platform-incompatible tools. Show one-line purposes; let them trim or add. Set `tools.<name>.wanted` for each, and auto-mark any prerequisite tools `wanted` (tell the user).

**Phase 3 — Credentials + verify, per wanted tool** (prerequisites first). For each: ensure its prerequisites are `verify: done` first; then read the doc's **At a glance → Credentials** and **Setup**, and provision each credential *by where it lives* —
- **`.env`** — check the named variable is set and non-placeholder; if not, explain where to fetch it, pause for the paste, write it with a targeted edit (no full-file dump).
- **`keychain:<service>`** — check existence with `security find-generic-password -s <service> -a <name>` (metadata only — never `-w`); if missing, show the doc's command for the user to run themselves (single-quote the secret).
- **`config:<path>`** — check the path exists and holds the value; else point at the doc's setup.
- **OAuth (browser)** — no static value; the **Verify** step triggers the flow.
- **SSH** — confirm the key/host access exists; setup is in the doc.

Mark `env: done` once a tool's credentials are in place. Then run the doc's **Verify**: on success `verify: done` + `verified_at`; on failure walk **Troubleshooting** once, then `verify: failed` + `last_error` and ask how to proceed. A credential-only tool with no **Verify** section gets `verify: not_applicable`.

**Phase 4 — Summary.** Print a compact tool / status / next-step table and remind the user of `status`, `add <tool>`, `refresh <tool>`.

## Sub-op: `status`

Print a connection summary (the repo is always browsable; the agent is connected if `.exobrain.json`'s `connected` is non-empty; N tools verified), then one row per resolved tool: name · wanted (`yes`/`no`/`unset`) · env · verify · last verified (relative) · notes (`last_error`, or "template" for `example-tool`). Suggest the next action for anything `pending`/`failed`.

## Sub-op: `add <tool>`

Resolve `<tool>` in the tool set (if absent, list available names and stop). Set `tools.<tool>.wanted = true`, run the Phase-3 slice (prerequisites → credentials → verify) for just that tool, print its summary row.

## Sub-op: `refresh <tool>`

Confirm `tools.<tool>.wanted`. For each credential, ask whether the current value is still good; re-provision only what changed. Re-run **Verify** and update `verify` / `verified_at`.

## Sub-op: `doctor`

Re-run **Verify** for every `wanted` tool. For each failure print: tool, what failed, the likely cause from its **Troubleshooting**, and the fix. Don't auto-fix — the user runs `refresh <tool>` for the ones they want redone.

## What this skill does NOT do

- **Add or edit tool docs** under `tools/` — those are human-curated through PRs. To add a tool, follow [`tools/README.md`](../../tools/README.md) § Adding a tool, then run `add <name>` to confirm discovery and the flow.
- **Install the agent CLI** — the user already has one running to invoke this.
- **Configure scopes/skills** — `connect-agent.sh` is the single source of truth for scope linking; this skill only calls it.
- **Update the repo or adopt framework changes** — `git pull` + relink is the post-merge hook's job; adopting the seed's improvements is the `exobrain-evolve` skill's.
- **Store secrets anywhere but `.env`** (or a keychain the user manages); it never runs `security … -w` itself.
