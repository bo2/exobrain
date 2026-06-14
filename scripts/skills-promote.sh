#!/usr/bin/env bash
# skills-promote.sh — add or change a skills.json entry at some scope.
#
# Each entry is a (name, scope, owner, tier) tuple. `--scope`/`--owner` identify
# the skill being registered; `--into` picks which scope's skills.json file to
# write the entry into (default: the deepest connected leaf in .exobrain.json).
#
# Usage:
#   skills-promote.sh <name> --scope=<path|global|external> --owner=<id> --to=<tier> [--into=<scope-path>]
#   skills-promote.sh <name> --scope=<path|global|external> --owner=<id> --remove [--into=<scope-path>]
#   skills-promote.sh --list [--into=<scope-path>]
#
# Flags:
#   --scope=<path|global|external>   where the skill physically lives (a scope
#                                    dir path like people/oleg, or global/external)
#   --owner=<id>                     scope leaf id (basename); "" for global
#   --to=always|optional|off         tier to set
#   --into=<scope-path|global>       which skills.json to edit (default: deepest connected leaf)
#   --remove                         delete the entry
#   --list                           print the target skills.json
#
# Examples:
#   skills-promote.sh review-pr --scope=people/oleg --owner=oleg --to=always
#   skills-promote.sh tidy --scope=groups/acme --owner=acme --to=optional --into=people/oleg
#   skills-promote.sh review-pr --scope=people/oleg --owner=oleg --remove

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG_FILE="$REPO_DIR/.exobrain.json"
CONNECTED_LEAVES=()
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS= read -r _l; do [[ -n "$_l" ]] && CONNECTED_LEAVES+=("$_l"); done \
        < <(jq -r '(.connected // [])[]' "$CONFIG_FILE" 2>/dev/null)
fi

name="" ; scope="" ; owner="" ; tier="" ; into="" ; do_remove=false ; do_list=false

for arg in "$@"; do
    case "$arg" in
        --scope=*)  scope="${arg#--scope=}" ;;
        --owner=*)  owner="${arg#--owner=}" ;;
        --to=*)     tier="${arg#--to=}" ;;
        --into=*)   into="${arg#--into=}" ;;
        --remove)   do_remove=true ;;
        --list)     do_list=true ;;
        -h|--help)  head -n 22 "$0" | tail -n +2 | sed 's/^# \{0,1\}//'; exit 0 ;;
        --*)        echo "Unknown flag: $arg" >&2; exit 2 ;;
        *)          [[ -z "$name" ]] && name="$arg" || { echo "Unexpected argument: $arg" >&2; exit 2; } ;;
    esac
done

# Default --into to the deepest connected leaf.
if [[ -z "$into" ]]; then
    [[ ${#CONNECTED_LEAVES[@]} -gt 0 ]] && into="${CONNECTED_LEAVES[$((${#CONNECTED_LEAVES[@]}-1))]}"
    [[ -z "$into" ]] && { echo "Error: no connected leaf to write into; pass --into=<scope-path>." >&2; exit 2; }
fi

if [[ "$into" == "global" ]]; then
    override_file="$REPO_DIR/skills.json"; schema_rel="./skills.schema.json"
else
    override_file="$REPO_DIR/$into/skills.json"
    # one ../ per path segment of $into
    depth="$(awk -F/ '{print NF}' <<< "$into")"; schema_rel=""
    for ((i=0;i<depth;i++)); do schema_rel="../$schema_rel"; done
    schema_rel="${schema_rel}skills.schema.json"
fi

if $do_list; then
    [[ -f "$override_file" ]] && { echo "$override_file:"; jq . "$override_file"; } || echo "(no file at $override_file)"
    exit 0
fi

[[ -z "$name" ]]  && { echo "Error: missing skill name." >&2; exit 2; }
[[ -z "$scope" ]] && { echo "Error: missing --scope." >&2; exit 2; }
[[ -z "$owner" && "$scope" != "global" ]] && { echo "Error: missing --owner (only 'global' allows empty owner)." >&2; exit 2; }
[[ "$scope" == *__* ]] && { echo "Error: scope path may not contain '__'." >&2; exit 2; }

if [[ ! -f "$override_file" ]]; then
    mkdir -p "$(dirname "$override_file")"
    printf '{\n  "$schema": "%s",\n  "skills": []\n}\n' "$schema_rel" > "$override_file"
fi

if $do_remove; then
    jq --arg n "$name" --arg s "$scope" --arg o "$owner" '
        .skills = (.skills // [] | map(select(.name != $n or .scope != $s or .owner != $o)))
    ' "$override_file" > "${override_file}.tmp"
elif [[ -n "$tier" ]]; then
    case "$tier" in always|optional|off) ;; *) echo "Invalid --to: $tier" >&2; exit 2 ;; esac
    jq --arg n "$name" --arg s "$scope" --arg o "$owner" --arg t "$tier" '
        .skills = (
            (.skills // [] | map(select(.name != $n or .scope != $s or .owner != $o)))
            + [{ name: $n, scope: $s, owner: $o, tier: $t }]
        )
    ' "$override_file" > "${override_file}.tmp"
else
    echo "Error: provide --to=<tier> or --remove" >&2; exit 2
fi

# Reformat one entry per line for readable diffs.
python3 - "${override_file}.tmp" "$override_file" <<'PY'
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
            for j, entry in enumerate(data[k]):
                lines.append(f"    {json.dumps(entry, ensure_ascii=False)}{',' if j < len(data[k])-1 else ''}")
            lines.append(f"  ]{sep}")
    else:
        lines.append(f'  {json.dumps(k, ensure_ascii=False)}: {json.dumps(data[k], ensure_ascii=False)}{sep}')
lines.append("}")
with open(dst, "w") as f: f.write("\n".join(lines) + "\n")
PY
rm -f "${override_file}.tmp"

echo "Updated ${override_file#"$REPO_DIR"/}:"; jq . "$override_file"
echo ""; echo "Run scripts/connect-agent.sh <agent> --relink to apply."
