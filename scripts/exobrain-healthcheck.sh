#!/usr/bin/env bash
# exobrain-healthcheck.sh — read-only check that exobrain is connected for the
# running agent in this checkout. It detects two failure modes and SUGGESTS the
# fix; it never writes and never runs connect-agent.sh itself (see AGENTS.md →
# "Setup and relink safety" — relink is human-driven):
#
#   - not connected  → suggest: scripts/connect-agent.sh <agent>
#   - links stale    → suggest: scripts/connect-agent.sh <agent> --relink
#
# The agent connection (the generated CLAUDE.md and skill symlinks) lives in the
# MAIN checkout, so this resolves to it via the shared git dir and reports its
# state even when invoked from a linked worktree (which only carries the tracked
# .claude/settings.json, not the generated links).
#
# Usage:
#   scripts/exobrain-healthcheck.sh [claude|codex|openclaw] [-v]
#
# With no agent argument it checks every connected agent (or reports none).
# Always exits 0 — advisory, safe to wire into a session-start hook where a
# non-zero exit could block the session.

set -uo pipefail

VERBOSE=false
AGENT=""
for a in "$@"; do
    case "$a" in
        -v|--verbose)          VERBOSE=true ;;
        claude|codex|openclaw)  AGENT="$a" ;;
    esac
done

here="$(cd "$(dirname "$0")/.." && pwd)"
# Resolve the MAIN checkout: parent of the shared git dir. From the main
# checkout that's itself; from a worktree it's the original checkout, where
# connect-agent.sh writes the generated links.
common="$(git -C "$here" rev-parse --git-common-dir 2>/dev/null || echo "$here/.git")"
case "$common" in /*) ;; *) common="$here/$common" ;; esac
MAIN="$(cd "$(dirname "$common")" 2>/dev/null && pwd || echo "$here")"

# Generated proof that connect-agent.sh connected each agent — distinct from the
# committed .claude/settings.json, which is present in every checkout.
connected() {
    case "$1" in
        claude)   [[ -f "$MAIN/.claude/CLAUDE.md" ]] ;;
        codex)    [[ -e "$MAIN/.codex" ]] ;;
        openclaw) [[ -e "$MAIN/.openclaw" ]] ;;
    esac
}

# Where connect-agent.sh links skills/sidecars for each agent.
target_dir() {
    case "$1" in
        claude)   printf '%s' "$MAIN/.claude" ;;
        codex)    printf '%s' "${CODEX_HOME:-$HOME/.codex}" ;;
        openclaw) printf '%s' "${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}" ;;
    esac
}

problems=()

# 1. Configured at all?
if [[ ! -f "$MAIN/.exobrain.json" ]]; then
    echo "⚠ exobrain isn't set up in this checkout (no .exobrain.json)."
    echo "  Run: scripts/connect-agent.sh <claude|codex|openclaw>"
    exit 0
fi

# 2. Which agents to check — the named one, else every connected agent.
agents=()
if [[ -n "$AGENT" ]]; then
    agents=("$AGENT")
else
    for a in claude codex openclaw; do
        connected "$a" && agents+=("$a")
    done
fi

if [[ ${#agents[@]} -eq 0 ]]; then
    echo "⚠ exobrain is configured but no agent is connected here."
    echo "  Run: scripts/connect-agent.sh <claude|codex|openclaw>"
    exit 0
fi

# 3. Per agent: connected? then check its links for staleness.
for a in "${agents[@]}"; do
    if ! connected "$a"; then
        problems+=("$a: not connected — run: scripts/connect-agent.sh $a")
        continue
    fi
    td="$(target_dir "$a")"
    # Dangling symlinks among the linked skills/sidecars = stale links (a
    # skills.json change without a relink, a moved source, a partial relink).
    broken="$(find -L "$td/skills" "$td" -maxdepth 1 -type l 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${broken:-0}" -gt 0 ]]; then
        problems+=("$a: $broken stale link(s) under $td — run: scripts/connect-agent.sh $a --relink")
    fi
done

if [[ ${#problems[@]} -gt 0 ]]; then
    echo "⚠ exobrain connection needs attention:"
    for p in "${problems[@]}"; do echo "  - $p"; done
    echo "  Suggestions only — connect-agent.sh is run by you, the human, not the agent."
    exit 0
fi

$VERBOSE && echo "✓ exobrain: ${agents[*]} connected and linked ($MAIN)."
exit 0
