#!/usr/bin/env bash
# skills-promote.sh — manage skill tiers under the declaration/override model.
#
# Two operations:
#
#   OVERRIDE — opt a skill in or out for a scope. Writes an override entry
#   {name, from, tier} (+ owner for external) into the chosen scope's skills.json.
#   `from` is the skill's home scope (where it is declared); the entry's own
#   location sets its priority. Overrides win over declarations (deepest scope).
#
#     skills-promote <name> --from=<home-scope|global|external> [--owner=<author>] \
#                    --to=always|optional|unlisted|off [--into=<scope>]
#     skills-promote <name> --from=<home-scope|global|external> [--owner=<author>] \
#                    --remove [--into=<scope>]
#
#   FORCE — bless or unbless a declaration so its recommended tier reaches the
#   whole scope, not just the owner. Edits the declaration in its home scope.
#
#     skills-promote <name> --in=<home-scope> --force[=true|false]
#
#   LIST — print a scope's skills.json.
#     skills-promote --list [--into=<scope>]
#
# --into / --in default to the deepest connected leaf in .exobrain.json.
#
# Examples:
#   skills-promote review-pr --from=groups/acme --to=always       # opt in for your deepest scope
#   skills-promote review-pr --from=groups/acme --to=off          # opt out
#   skills-promote skill-creator --from=external --owner=anthropic --to=off  # disable external
#   skills-promote review-pr --in=groups/acme --force             # bless for everyone in the group

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=skills-registry.sh
source "$SCRIPT_DIR/skills-registry.sh"

CONFIG_FILE="$REPO_DIR/.exobrain.json"
CONNECTED_LEAVES=()
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS= read -r l; do [[ -n "$l" ]] && CONNECTED_LEAVES+=("$l"); done \
        < <(jq -r '(.connected_scopes // [])[]' "$CONFIG_FILE" 2>/dev/null)
fi
deepest_leaf() { [[ ${#CONNECTED_LEAVES[@]} -gt 0 ]] && echo "${CONNECTED_LEAVES[$((${#CONNECTED_LEAVES[@]}-1))]}"; }

name="" ; from="" ; owner="" ; tier="" ; into="" ; in_scope="" ; force="" ; do_remove=false ; do_list=false
for arg in "$@"; do
    case "$arg" in
        --from=*)   from="${arg#--from=}" ;;
        --owner=*)  owner="${arg#--owner=}" ;;
        --to=*)     tier="${arg#--to=}" ;;
        --into=*)   into="${arg#--into=}" ;;
        --in=*)     in_scope="${arg#--in=}" ;;
        --force)    force="true" ;;
        --force=*)  force="${arg#--force=}" ;;
        --remove)   do_remove=true ;;
        --list)     do_list=true ;;
        -h|--help)  head -n 31 "$0" | tail -n +2 | sed 's/^# \{0,1\}//'; exit 0 ;;
        --*)        echo "Unknown flag: $arg" >&2; exit 2 ;;
        *)          [[ -z "$name" ]] && name="$arg" || { echo "Unexpected argument: $arg" >&2; exit 2; } ;;
    esac
done

target_file()    { [[ "$1" == "global" ]] && echo "$REPO_DIR/skills.json" || echo "$REPO_DIR/$1/skills.json"; }
schema_rel_for() {
    [[ "$1" == "global" ]] && { echo "./skills.schema.json"; return; }
    local depth rel="" i; depth="$(awk -F/ '{print NF}' <<< "$1")"
    for ((i=0; i<depth; i++)); do rel="../$rel"; done
    echo "${rel}skills.schema.json"
}
ensure_file() {
    [[ -f "$1" ]] && return 0
    mkdir -p "$(dirname "$1")"
    printf '{\n  "$schema": "%s",\n  "skills": []\n}\n' "$(schema_rel_for "$2")" > "$1"
}
# one-entry-per-line reformat for readable diffs
reformat() {
    python3 - "$1" "$2" <<'PY'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f: data = json.load(f)
keys = list(data.keys()); lines = ["{"]
for i, k in enumerate(keys):
    sep = "," if i < len(keys) - 1 else ""
    if k == "skills" and isinstance(data[k], list):
        if not data[k]: lines.append(f'  "skills": []{sep}')
        else:
            lines.append('  "skills": [')
            for j, e in enumerate(data[k]):
                lines.append(f"    {json.dumps(e, ensure_ascii=False)}{',' if j < len(data[k])-1 else ''}")
            lines.append(f"  ]{sep}")
    else:
        lines.append(f'  {json.dumps(k, ensure_ascii=False)}: {json.dumps(data[k], ensure_ascii=False)}{sep}')
lines.append("}")
with open(dst, "w") as f: f.write("\n".join(lines) + "\n")
PY
}

# ---- LIST ----
if $do_list; then
    [[ -z "$into" ]] && into="$(deepest_leaf)"
    f="$(target_file "${into:-global}")"
    [[ -f "$f" ]] && { echo "$f:"; jq . "$f"; } || echo "(no file at $f)"
    exit 0
fi

[[ -z "$name" ]] && { echo "Error: missing skill name." >&2; exit 2; }

# ---- FORCE (edit a declaration in its home scope) ----
if [[ -n "$force" ]]; then
    case "$force" in true|false) ;; *) echo "Invalid --force: $force (use true|false)" >&2; exit 2 ;; esac
    [[ -z "$in_scope" ]] && in_scope="$(deepest_leaf)"
    [[ -z "$in_scope" ]] && { echo "Error: --force needs --in=<home-scope>." >&2; exit 2; }
    file="$(target_file "$in_scope")"
    [[ -f "$file" ]] || { echo "Error: no skills.json at $in_scope (skill not declared there)." >&2; exit 2; }
    if ! jq -e --arg n "$name" '(.skills // []) | any(.name == $n and (has("from") | not))' "$file" >/dev/null; then
        echo "Error: no declaration for '$name' in $in_scope/skills.json." >&2; exit 2
    fi
    if [[ "$force" == "true" ]]; then
        jq --arg n "$name" '.skills |= map(if (.name==$n and (has("from")|not)) then .force=true else . end)' "$file" > "$file.tmp"
    else
        jq --arg n "$name" '.skills |= map(if (.name==$n and (has("from")|not)) then del(.force) else . end)' "$file" > "$file.tmp"
    fi
    reformat "$file.tmp" "$file"; rm -f "$file.tmp"
    echo "Set force=$force on declaration '$name' in ${file#"$REPO_DIR"/}:"; jq . "$file"
    echo ""; echo "Run scripts/connect-agent.sh <agent> --relink to apply."
    exit 0
fi

# ---- OVERRIDE (write into --into scope) ----
[[ -z "$from" ]] && { echo "Error: missing --from=<home-scope|global|external> (or use --force / --list)." >&2; exit 2; }
[[ "$from" == "external" && -z "$owner" ]] && { echo "Error: --from=external requires --owner=<author>." >&2; exit 2; }
[[ "$from" == *__* ]] && { echo "Error: --from path may not contain '__'." >&2; exit 2; }
[[ -z "$into" ]] && into="$(deepest_leaf)"
[[ -z "$into" ]] && { echo "Error: no connected leaf to write into; pass --into=<scope>." >&2; exit 2; }

file="$(target_file "$into")"
ensure_file "$file" "$into"

# An existing override matches on (name, from) plus owner when from=external.
if $do_remove; then
    jq --arg n "$name" --arg f "$from" --arg o "$owner" '
        .skills = (.skills // [] | map(select(
            ((.from // null) != $f) or (.name != $n) or ($f == "external" and (.owner // "") != $o)
        )))
    ' "$file" > "$file.tmp"
elif [[ -n "$tier" ]]; then
    case "$tier" in always|optional|unlisted|off) ;; *) echo "Invalid --to: $tier" >&2; exit 2 ;; esac
    jq --arg n "$name" --arg f "$from" --arg o "$owner" --arg t "$tier" '
        ( { name: $n, from: $f, tier: $t } + (if $f == "external" then { owner: $o } else {} end) ) as $entry
        | .skills = (
            (.skills // [] | map(select(
                ((.from // null) != $f) or (.name != $n) or ($f == "external" and (.owner // "") != $o)
            )))
            + [ $entry ]
          )
    ' "$file" > "$file.tmp"
else
    echo "Error: provide --to=<tier> or --remove." >&2; exit 2
fi
reformat "$file.tmp" "$file"; rm -f "$file.tmp"
echo "Updated ${file#"$REPO_DIR"/}:"; jq . "$file"
echo ""; echo "Run scripts/connect-agent.sh <agent> --relink to apply."
