#!/usr/bin/env bash
# skills-validate.sh — verify each registry entry's directory exists at the
# declared (scope, owner) location, and warn about skill directories that no
# skills.json references. Scope-shape-agnostic: discovers scopes by walking the
# tree for skills.json / skills/ rather than assuming a fixed ladder.
#
# Usage:
#   skills-validate.sh           # warn on missing/orphan
#   skills-validate.sh --strict  # exit 1 if any orphan or missing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=skills-registry.sh
source "$SCRIPT_DIR/skills-registry.sh"

# .exobrain.json is gitignored per-machine state — absent on a fresh clone before
# connect-agent.sh, in a worktree made without create-worktree.sh, or in CI. It
# only supplies identity to resolve the current user's person/host scopes; the
# registry-integrity and orphan checks below don't need it. So degrade to those
# rather than failing — a validator must not block a push over absent local state.
CONFIG_FILE="$REPO_DIR/.exobrain.json"
CONNECTED_LEAVES=()
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS= read -r _l; do [[ -n "$_l" ]] && CONNECTED_LEAVES+=("$_l"); done \
        < <(jq -r '(.connected // [])[]' "$CONFIG_FILE" 2>/dev/null)
else
    echo "Note: $CONFIG_FILE not present — validating registry integrity and orphans only (per-user scope resolution skipped)." >&2
fi

strict=false
for arg in "$@"; do case "$arg" in --strict) strict=true ;; esac; done

errors=0
warnings=0

# Shared find prune for repo-wide scans. seed/ is seed-local tooling outside the
# skills registry (the create-instance generator and the test harness), so it is
# excluded from both the declaration scan and the orphan walk below.
_find_jsons() { find "$REPO_DIR" -name "$1" \
    -not -path "$REPO_DIR/.claude/*" -not -path "$REPO_DIR/src/*" \
    -not -path "$REPO_DIR/seed/*" \
    -not -path "$REPO_DIR/.worktrees/*" -not -path "$REPO_DIR/.git/*" \
    -not -path '*/node_modules/*' 2>/dev/null; }

# 1a. Each non-external entry in the connected chain must have a SKILL.md at its
#     declared (scope, owner). Empty agent param disables filtering.
resolved="$(skills_resolve "$REPO_DIR" "" "${CONNECTED_LEAVES[@]:-}")"
while IFS= read -r _row; do
    [[ -n "$_row" ]] || continue
    name="${_row%%$'\t'*}";  _row="${_row#*$'\t'}"
    scope="${_row%%$'\t'*}"; _row="${_row#*$'\t'}"
    owner="${_row%%$'\t'*}"; _row="${_row#*$'\t'}"
    tier="${_row%%$'\t'*}";  _row="${_row#*$'\t'}"
    declared_by="$_row"
    [[ "$scope" == "external" ]] && continue
    src="$(skills_dir_for "$REPO_DIR" "$scope" "$owner" "$name")"
    if [[ -z "$src" || ! -f "$src/SKILL.md" ]]; then
        echo "  ✗ MISSING: $name ($scope:$owner) declared by $declared_by — expected $src/SKILL.md"
        errors=$((errors + 1))
    fi
done <<< "$resolved"

# 1b. External always entries must carry source.{repo,path,ref}.
ext_json="$(skills_resolve_external_json "$REPO_DIR" "" "${CONNECTED_LEAVES[@]:-}")"
while IFS=$'\t' read -r name owner tier has_source; do
    [[ -z "$name" ]] && continue
    if [[ "$tier" == "always" && "$has_source" != "true" ]]; then
        echo "  ✗ MISSING SOURCE: $name (external:$owner) tier=always but no source declared"
        errors=$((errors + 1))
    fi
done < <(jq -r '.[] | [.name, .owner, .tier, (.source != null)] | @tsv' <<< "$ext_json")

# 2. Aggregate every (name, scope, owner) declared in any skills.json repo-wide.
all_declared="$(
    while IFS= read -r f; do
        jq -r '(.skills // []) | .[] | [.name, .scope, .owner] | @tsv' "$f" 2>/dev/null
    done < <(_find_jsons skills.json) | sort -u
)"

# 3. Walk every skills/ directory; report skills not declared anywhere. The
#    owning scope of a skills/ dir is its parent path ("global" at the repo
#    root); owner is the leaf id (empty for global).
while IFS= read -r skills_dir; do
    parent="$(dirname "$skills_dir")"
    if [[ "$parent" == "$REPO_DIR" ]]; then
        scope="global"; owner=""
    else
        scope="${parent#"$REPO_DIR"/}"; owner="${scope##*/}"
    fi
    for skill_dir in "$skills_dir"/*/; do
        [[ -d "$skill_dir" ]] || continue
        name="$(basename "$skill_dir")"
        if ! grep -qFx -- "$name	$scope	$owner" <<< "$all_declared"; then
            echo "  ⚠ ORPHAN:  ${skills_dir#"$REPO_DIR"/}/$name — not declared in any skills.json (would be $scope:$owner)"
            warnings=$((warnings + 1))
        fi
    done
done < <(find "$REPO_DIR" -type d -name skills \
    -not -path "$REPO_DIR/.claude/*" -not -path "$REPO_DIR/src/*" \
    -not -path "$REPO_DIR/seed/*" \
    -not -path "$REPO_DIR/.worktrees/*" -not -path "$REPO_DIR/.git/*" \
    -not -path '*/node_modules/*' 2>/dev/null)

echo ""
echo "Errors: $errors  Warnings: $warnings"

if [[ $errors -gt 0 ]]; then exit 1; fi
if $strict && [[ $warnings -gt 0 ]]; then exit 1; fi
exit 0
