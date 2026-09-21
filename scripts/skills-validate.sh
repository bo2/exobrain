#!/usr/bin/env bash
# skills-validate.sh — verify the skill registry under the declaration/override
# model. Discovers scopes by walking the tree for skills.json, not a fixed ladder.
#
# Checks (repo-wide; needs no .exobrain.json):
#   1. every in-tree DECLARATION (entry without `from`/`source`) has its skill
#      directory + SKILL.md at <home-scope>/skills/<name>/;
#   2. every external declaration (has `source`) carries source.{repo,path,ref};
#   3. every OVERRIDE (`from` set) references a declaration that exists somewhere;
#   4. skill directories with no declaration are reported as info — under the
#      opt-in model "available but undeclared" just means off, not a problem.
#
# Usage:
#   skills-validate.sh           # errors fail (exit 1); undeclared dirs = info
#   skills-validate.sh --strict  # also fail (exit 1) on undeclared dirs

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=skills-registry.sh
source "$SCRIPT_DIR/skills-registry.sh"

strict=false
for arg in "$@"; do case "$arg" in --strict) strict=true ;; esac; done
errors=0; infos=0

# _find_repo <find-expr...> — repo paths matching the expression, PRUNING the
# directories below so find never descends into them. A plain -not -path only
# hides their contents while find still walks every entry, and src/ clones and
# tmp/ worktrees run to tens of thousands. Pruned: every agent backend's
# linker-output dir (.claude, .agents — codex's repo-local skills), so generated
# symlinks never read as orphans; seed/, seed-local tooling (the create-instance
# generator + test harness) kept outside the registry; and clones, worktrees,
# agent runtime dirs and caches — each one .gitignore excludes, so nothing pruned
# here can be committed content the registry check should see.
_find_repo() {
    find "$REPO_DIR" \
        \( -path "$REPO_DIR/.claude" -o -path "$REPO_DIR/.agents" -o -path "$REPO_DIR/seed" \
           -o -path "$REPO_DIR/src" -o -path "$REPO_DIR/tmp" \
           -o -path "$REPO_DIR/.worktrees" -o -path "$REPO_DIR/.agent-worktrees" \
           -o -path "$REPO_DIR/.agent-runs" -o -path "$REPO_DIR/.agent-control" \
           -o -path "$REPO_DIR/.git" -o -name node_modules -o -name __pycache__ -o -name _cache \) -prune \
        -o "$@" -print 2>/dev/null || true
}
skills_jsons="$(_find_repo -name skills.json)"

# Home scope of a skills.json = its directory relative to the repo ("global" at root).
_scope_of() { local d; d="$(dirname "$1")"; d="${d#"$REPO_DIR"}"; d="${d#/}"; [[ -z "$d" ]] && echo "global" || echo "$d"; }

# Gather declarations (scope<TAB>name<TAB>owner<TAB>in|ext) and overrides
# (declaring-scope<TAB>from<TAB>name<TAB>owner) across every skills.json.
decls=""; ovrs=""
while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    s="$(_scope_of "$f")"
    decls+="$(jq -r --arg s "$s" '(.skills//[])[] | select(has("from")|not) | [$s, .name, (.owner//""), (if .source then "ext" else "in" end)] | @tsv' "$f" 2>/dev/null)"$'\n'
    ovrs+="$(jq -r --arg s "$s" '(.skills//[])[] | select(has("from")) | [$s, .from, .name, (.owner//"")] | @tsv' "$f" 2>/dev/null)"$'\n'
done <<< "$skills_jsons"

decl_intree="$(awk -F'\t' '$1!="" && $4=="in" {print $1"\t"$2}' <<< "$decls" | sort -u)"
decl_ext="$(awk    -F'\t' '$1!="" && $4=="ext"{print $2"\t"$3}' <<< "$decls" | sort -u)"   # name<TAB>owner

# 1 — in-tree declaration integrity. The rows are split by awk, not by
# `IFS=$'\t' read`: tab is IFS whitespace, so read collapses the empty owner of an
# owner-less declaration and shifts its kind out of place.
while IFS=$'\t' read -r scope name; do
    [[ -z "$name" ]] && continue
    src="$REPO_DIR/$scope/skills/$name"; [[ "$scope" == "global" ]] && src="$REPO_DIR/skills/$name"
    if [[ ! -f "$src/SKILL.md" ]]; then
        echo "  ✗ MISSING: declaration '$name' in $scope — expected ${src#"$REPO_DIR"/}/SKILL.md"
        errors=$((errors + 1))
    fi
done < <(awk -F'\t' '$4=="in" {print $1"\t"$2}' <<< "$decls")

# 2 — external declarations carry source.{repo,path,ref}.
while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    while IFS= read -r nm; do
        [[ -z "$nm" ]] && continue
        echo "  ✗ MISSING SOURCE: external declaration '$nm' in $(_scope_of "$f") lacks source.{repo,path,ref}"
        errors=$((errors + 1))
    done < <(jq -r '(.skills//[])[] | select((has("from")|not) and .source) | select((.source.repo and .source.path and .source.ref)|not) | .name' "$f" 2>/dev/null)
done <<< "$skills_jsons"

# 3 — every override references a real declaration.
while IFS=$'\t' read -r dscope from name owner; do
    [[ -z "$name" ]] && continue
    if [[ "$from" == "external" ]]; then
        grep -qFx -- "$name	$owner" <<< "$decl_ext" || {
            echo "  ✗ DANGLING OVERRIDE: '$name' (from external, owner '$owner') in $dscope — no matching external declaration"
            errors=$((errors + 1)); }
    else
        grep -qFx -- "$from	$name" <<< "$decl_intree" || {
            echo "  ✗ DANGLING OVERRIDE: '$name' (from $from) in $dscope — no declaration there"
            errors=$((errors + 1)); }
    fi
done <<< "$ovrs"

# 4 — skill dirs with no declaration are info (available, undeclared = off).
while IFS= read -r skills_dir; do
    parent="$(dirname "$skills_dir")"
    if [[ "$parent" == "$REPO_DIR" ]]; then scope="global"; else scope="${parent#"$REPO_DIR"/}"; fi
    for skill_dir in "$skills_dir"/*/; do
        [[ -d "$skill_dir" ]] || continue
        name="$(basename "$skill_dir")"
        grep -qFx -- "$scope	$name" <<< "$decl_intree" || {
            echo "  • undeclared: ${skills_dir#"$REPO_DIR"/}/$name (available; no declaration → off for everyone)"
            infos=$((infos + 1)); }
    done
done < <(_find_repo -type d -name skills)

echo ""
echo "Errors: $errors  Info: $infos"
if [[ $errors -gt 0 ]]; then exit 1; fi
if $strict && [[ $infos -gt 0 ]]; then exit 1; fi
exit 0
