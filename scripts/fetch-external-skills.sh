#!/usr/bin/env bash
# fetch-external-skills.sh — install third-party skills declared in any
# connected scope's skills.json (external declarations) into the agent's
# skills folder.
#
# The plan comes from the resolved registry (skills-registry.sh ::
# skills_resolve_external_json), not a separate manifest.
#
# Usage:
#   fetch-external-skills.sh <skills-dir> --agent <name> --leaves <csv> [--force]
#       <csv> — comma-separated connected scope paths (from .exobrain.json
#               `connected`); empty for guest.
#
# Behavior per resolved external entry:
#   tier=always — fetch into <skills-dir>/<name>.<suffix>/ at the pinned ref.
#   tier=optional — fetch into <skills-dir>/../skills-optional/<name>.<suffix>/
#                   (agent does NOT auto-load; referenced by the optional-skills index).
#   tier=unlisted — same install as optional (into skills-optional/), but the index
#                   builder omits it: present on disk and invocable, just unadvertised.
#   tier=off    — remove from both locations.
#   skipAgents / agent — applied at resolve time; filtered entries never appear here.
# <suffix> = sanitize_suffix(owner) (the external author), matching the link
# suffix connect-agent.sh uses.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=skills-registry.sh
source "$SCRIPT_DIR/skills-registry.sh"

SKILLS_DIR="" ; AGENT="" ; LEAVES_CSV="" ; FORCE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent)  AGENT="$2"; shift 2 ;;
        --leaves) LEAVES_CSV="$2"; shift 2 ;;
        --force)  FORCE=true; shift ;;
        *)        [[ -z "$SKILLS_DIR" ]] && SKILLS_DIR="$1"; shift ;;
    esac
done

[[ -n "$SKILLS_DIR" ]] || { echo "Usage: $0 <skills-dir> --agent <a> --leaves <csv> [--force]" >&2; exit 2; }
command -v jq &>/dev/null || { echo "Error: jq is required." >&2; exit 1; }

LEAVES=()
IFS=',' read -ra LEAVES <<< "$LEAVES_CSV"
# drop empty fields (empty CSV → guest)
_filtered=() ; for l in "${LEAVES[@]:-}"; do [[ -n "$l" ]] && _filtered+=("$l"); done ; LEAVES=("${_filtered[@]:-}")

mkdir -p "$SKILLS_DIR"
OPTIONAL_DIR="$(dirname "$SKILLS_DIR")/skills-optional"

ENTRIES_JSON="$(skills_resolve_external_json "$REPO_DIR" "$AGENT" "${LEAVES[@]:-}")"
count="$(jq 'length' <<< "$ENTRIES_JSON")"
if [[ "$count" -eq 0 ]]; then
    echo "  (no external skills declared in any connected scope)"
    exit 0
fi

echo "Fetching $count external skill(s) (always → $SKILLS_DIR, optional → $OPTIONAL_DIR) ..."
echo ""
errors=0

for i in $(seq 0 $((count - 1))); do
    entry="$(jq -c ".[$i]" <<< "$ENTRIES_JSON")"
    name="$(jq -r '.name' <<< "$entry")"
    owner="$(jq -r '.owner' <<< "$entry")"
    tier="$(jq -r '.tier' <<< "$entry")"
    repo="$(jq -r '.source.repo // empty' <<< "$entry")"
    spath="$(jq -r '.source.path // empty' <<< "$entry")"
    ref="$(jq -r '.source.ref  // empty' <<< "$entry")"

    install_name="${name}.$(sanitize_suffix "$owner")"
    always_dir="$SKILLS_DIR/$install_name"
    optional_dir="$OPTIONAL_DIR/$install_name"

    if [[ "$tier" == "off" ]]; then
        for d in "$always_dir" "$optional_dir"; do
            [[ -d "$d" ]] && { rm -rf "$d"; echo "  - $install_name (tier=off, removed from $(dirname "$d"))"; }
        done
        continue
    fi

    case "$tier" in
        always)            skill_dir="$always_dir"   ; stale_dir="$optional_dir" ;;
        optional|unlisted) skill_dir="$optional_dir" ; stale_dir="$always_dir"   ;;
        *)        echo "  ✗ $install_name (unknown tier '$tier')"; errors=$((errors+1)); continue ;;
    esac
    [[ -d "$stale_dir" ]] && { rm -rf "$stale_dir"; echo "  ↗ $install_name (moved out of $(dirname "$stale_dir"))"; }
    [[ "$tier" == "optional" || "$tier" == "unlisted" ]] && mkdir -p "$OPTIONAL_DIR"

    if [[ -z "$repo" || -z "$spath" || -z "$ref" ]]; then
        echo "  ✗ $install_name (missing source.repo/path/ref — invalid registry entry)"
        errors=$((errors + 1)); continue
    fi

    ref_file="$skill_dir/.source-ref"
    if [[ -f "$ref_file" ]] && ! $FORCE && [[ "$(cat "$ref_file")" == "$ref" ]]; then
        echo "  ✓ $install_name (already at ${ref:0:12})"; continue
    fi

    echo "  ⏳ $install_name (fetching from ${ref:0:12})..."
    tmpdir="$(mktemp -d)"
    if ! git clone --no-checkout --depth=1 --filter=tree:0 --branch "$ref" "$repo" "$tmpdir/repo" 2>/dev/null; then
        rm -rf "$tmpdir/repo"; git init -q "$tmpdir/repo"; git -C "$tmpdir/repo" remote add origin "$repo"
        if ! git -C "$tmpdir/repo" fetch --depth=1 origin "$ref" 2>/dev/null; then
            echo "  ✗ $install_name (failed to fetch ref '$ref' from $repo)"; rm -rf "$tmpdir"; errors=$((errors + 1)); continue
        fi
        git -C "$tmpdir/repo" checkout FETCH_HEAD -- "$spath" 2>/dev/null || true
    else
        git -C "$tmpdir/repo" checkout HEAD -- "$spath" 2>/dev/null || true
    fi

    if [[ ! -d "$tmpdir/repo/$spath" ]]; then
        echo "  ✗ $install_name (path '$spath' not found at ref '$ref')"; rm -rf "$tmpdir"; errors=$((errors + 1)); continue
    fi
    if [[ ! -f "$tmpdir/repo/$spath/SKILL.md" ]]; then
        echo "  ✗ $install_name (no SKILL.md at $spath — not a valid skill)"; rm -rf "$tmpdir"; errors=$((errors + 1)); continue
    fi

    rm -rf "$skill_dir"; cp -R "$tmpdir/repo/$spath" "$skill_dir"; echo "$ref" > "$ref_file"; rm -rf "$tmpdir"
    echo "  ✓ $install_name (installed at ${ref:0:12})"
done

# Cleanup: remove any <name>.<suffix>/ with a .source-ref no longer declared.
declared_dirs="$(jq -r '.[] | .name + "." + (.owner)' <<< "$ENTRIES_JSON" | while IFS= read -r no; do
    n="${no%.*}"; o="${no##*.}"; echo "${n}.$(sanitize_suffix "$o")"; done | sort -u)"
for parent in "$SKILLS_DIR" "$OPTIONAL_DIR"; do
    [[ -d "$parent" ]] || continue
    for d in "$parent"/*/; do
        [[ -d "$d" && -f "$d/.source-ref" ]] || continue
        base="$(basename "$d")"
        grep -qFx "$base" <<< "$declared_dirs" || { rm -rf "$d"; echo "  - $base (removed — no longer declared)"; }
    done
done

echo ""
[[ "$errors" -gt 0 ]] && { echo "Done with $errors error(s)."; exit 1; }
echo "Done."
