#!/usr/bin/env bash
# fetch-external-skills.sh — install third-party skills declared in any
# scope's skills.json (scope=external entries) into the agent's skills folder.
#
# The script reads its plan from the resolved registry (via
# scripts/skills-registry.sh::skills_resolve_external_json), not from a
# separate manifest file.
#
# Usage:
#   fetch-external-skills.sh <skills-dir> --agent <name> \
#       --home-team <t> --username <u> --hostname <h> \
#       --connected-teams <csv> [--force]
#
# Behavior per resolved external entry:
#   tier=always — fetch into <skills-dir>/<name>.<owner>/ at the pinned ref.
#   tier=off    — remove <skills-dir>/<name>.<owner>/ if present.
#   skipAgents / agent  — applied at resolve time by skills_resolve_external_json;
#                         filtered entries never reach this loop.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=skills-registry.sh
source "$REPO_DIR/scripts/skills-registry.sh"

SKILLS_DIR=""
AGENT=""
HOME_TEAM=""
USERNAME=""
HOSTNAME_LOWER=""
CONNECTED_CSV=""
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent)            AGENT="$2"; shift 2 ;;
        --home-team)        HOME_TEAM="$2"; shift 2 ;;
        --username)         USERNAME="$2"; shift 2 ;;
        --hostname)         HOSTNAME_LOWER="$2"; shift 2 ;;
        --connected-teams)  CONNECTED_CSV="$2"; shift 2 ;;
        --force)            FORCE=true; shift ;;
        *)
            [[ -z "$SKILLS_DIR" ]] && SKILLS_DIR="$1"
            shift
            ;;
    esac
done

[[ -n "$SKILLS_DIR" ]]  || { echo "Usage: $0 <skills-dir> --agent <a> --home-team <t> --username <u> --hostname <h> --connected-teams <csv>" >&2; exit 2; }
[[ -n "$HOME_TEAM" ]]   || { echo "Error: --home-team is required" >&2; exit 2; }

IFS=',' read -ra CONNECTED_TEAMS <<<"$CONNECTED_CSV"
[[ ${#CONNECTED_TEAMS[@]} -eq 0 ]] && CONNECTED_TEAMS=("$HOME_TEAM")

command -v jq &>/dev/null || { echo "Error: jq is required." >&2; exit 1; }

mkdir -p "$SKILLS_DIR"

ENTRIES_JSON="$(skills_resolve_external_json "$REPO_DIR" "$HOME_TEAM" "$USERNAME" "$HOSTNAME_LOWER" "$AGENT" "${CONNECTED_TEAMS[@]}")"
count="$(jq 'length' <<<"$ENTRIES_JSON")"

if [[ "$count" -eq 0 ]]; then
    echo "  (no external skills declared in any scope)"
    exit 0
fi

# Optional-tier external skills go to a sibling dir that the agent does NOT
# auto-load; they're referenced by optional-skills.md and read on demand.
OPTIONAL_DIR="$(dirname "$SKILLS_DIR")/skills-optional"
echo "Fetching $count external skill(s) (always → $SKILLS_DIR, optional → $OPTIONAL_DIR) ..."
echo ""

errors=0

for i in $(seq 0 $((count - 1))); do
    entry="$(jq -c ".[$i]" <<<"$ENTRIES_JSON")"
    name="$(jq -r '.name' <<<"$entry")"
    owner="$(jq -r '.owner' <<<"$entry")"
    tier="$(jq -r '.tier' <<<"$entry")"
    repo="$(jq -r '.source.repo // empty' <<<"$entry")"
    spath="$(jq -r '.source.path // empty' <<<"$entry")"
    ref="$(jq -r '.source.ref  // empty' <<<"$entry")"

    install_name="${name}.${owner}"
    always_dir="$SKILLS_DIR/$install_name"
    optional_dir="$OPTIONAL_DIR/$install_name"

    # tier=off — remove from both locations if present and skip
    if [[ "$tier" == "off" ]]; then
        for d in "$always_dir" "$optional_dir"; do
            if [[ -d "$d" ]]; then
                rm -rf "$d"
                echo "  - $install_name (tier=off, removed from $(dirname "$d"))"
            fi
        done
        continue
    fi

    # Pick destination + cleanup any stale copy in the other location
    case "$tier" in
        always)   skill_dir="$always_dir"   ; stale_dir="$optional_dir" ;;
        optional) skill_dir="$optional_dir" ; stale_dir="$always_dir"   ;;
        *)        echo "  ✗ $install_name (unknown tier '$tier')"; errors=$((errors+1)); continue ;;
    esac
    [[ -d "$stale_dir" ]] && { rm -rf "$stale_dir"; echo "  ↗ $install_name (moved out of $(dirname "$stale_dir"))"; }
    [[ "$tier" == "optional" ]] && mkdir -p "$OPTIONAL_DIR"

    # Fetch
    if [[ -z "$repo" || -z "$spath" || -z "$ref" ]]; then
        echo "  ✗ $install_name (missing source.repo/path/ref — invalid registry entry)"
        errors=$((errors + 1))
        continue
    fi

    ref_file="$skill_dir/.source-ref"
    if [[ -f "$ref_file" ]] && ! $FORCE; then
        installed_ref="$(cat "$ref_file")"
        if [[ "$installed_ref" == "$ref" ]]; then
            echo "  ✓ $install_name (already at ${ref:0:12})"
            continue
        fi
    fi

    echo "  ⏳ $install_name (fetching from ${ref:0:12})..."
    tmpdir="$(mktemp -d)"

    if ! git clone --no-checkout --depth=1 --filter=tree:0 \
        --branch "$ref" "$repo" "$tmpdir/repo" 2>/dev/null; then
        # --branch doesn't accept raw SHAs; fall back to fetch
        rm -rf "$tmpdir/repo"
        git init -q "$tmpdir/repo"
        git -C "$tmpdir/repo" remote add origin "$repo"
        if ! git -C "$tmpdir/repo" fetch --depth=1 origin "$ref" 2>/dev/null; then
            echo "  ✗ $install_name (failed to fetch ref '$ref' from $repo)"
            rm -rf "$tmpdir"
            errors=$((errors + 1))
            continue
        fi
        git -C "$tmpdir/repo" checkout FETCH_HEAD -- "$spath" 2>/dev/null || true
    else
        git -C "$tmpdir/repo" checkout HEAD -- "$spath" 2>/dev/null || true
    fi

    if [[ ! -d "$tmpdir/repo/$spath" ]]; then
        echo "  ✗ $install_name (path '$spath' not found in repo at ref '$ref')"
        rm -rf "$tmpdir"
        errors=$((errors + 1))
        continue
    fi

    if [[ ! -f "$tmpdir/repo/$spath/SKILL.md" ]]; then
        echo "  ✗ $install_name (no SKILL.md at $spath — not a valid skill)"
        rm -rf "$tmpdir"
        errors=$((errors + 1))
        continue
    fi

    rm -rf "$skill_dir"
    cp -R "$tmpdir/repo/$spath" "$skill_dir"
    echo "$ref" > "$ref_file"
    rm -rf "$tmpdir"

    echo "  ✓ $install_name (installed at ${ref:0:12})"
done

# Cleanup pass: remove any <name>.<author>/ that has a .source-ref but is no
# longer declared in any scope. Handles renames or removed external entries.
# Scans both the always (skills/) and optional (skills-optional/) dirs.
declared_dirs="$(jq -r '.[] | "\(.name).\(.owner)"' <<<"$ENTRIES_JSON" | sort -u)"
for parent in "$SKILLS_DIR" "$OPTIONAL_DIR"; do
    [[ -d "$parent" ]] || continue
    for d in "$parent"/*/; do
        [[ -d "$d" ]] || continue
        [[ -f "$d/.source-ref" ]] || continue
        base="$(basename "$d")"
        if ! grep -qFx "$base" <<<"$declared_dirs"; then
            rm -rf "$d"
            echo "  - $base (removed — no longer declared)"
        fi
    done
done

echo ""
if [[ "$errors" -gt 0 ]]; then
    echo "Done with $errors error(s)."
    exit 1
fi
echo "Done."
