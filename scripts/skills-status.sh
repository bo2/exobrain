#!/usr/bin/env bash
# skills-status.sh — show the effective skills registry for the current connection.
#
# Usage:
#   skills-status.sh                # auto-detect connected leaves from .exobrain.json
#   skills-status.sh --tier=always  # filter to one tier
#   skills-status.sh --plain        # TSV (name, scope, owner, tier, declared-by)
#   skills-status.sh --all          # catalog every declared skill repo-wide (discovery)

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

filter_tier="" ; filter_agent="" ; plain=false ; show_all=false
for arg in "$@"; do
    case "$arg" in
        --tier=*)  filter_tier="${arg#--tier=}" ;;
        --agent=*) filter_agent="${arg#--agent=}" ;;
        --plain)   plain=true ;;
        --all)     show_all=true ;;
        -h|--help) head -n 8 "$0" | tail -n +2 | sed 's/^# \{0,1\}//'; exit 0 ;;
    esac
done

# --all: the discovery catalog. Under the opt-in model a non-forced skill is
# invisible to non-owners, so list every DECLARATION (entry without `from`)
# repo-wide — name, home scope, owner, recommended tier, whether forced, and a
# one-line description — so a teammate can find one and opt in.
if $show_all; then
    {
        printf 'NAME\tSCOPE\tOWNER\tTIER\tFORCE\tDESCRIPTION\n'
        while IFS= read -r jf; do
            dir="$(dirname "$jf")"; scope="${dir#"$REPO_DIR"}"; scope="${scope#/}"; [[ -z "$scope" ]] && scope="global"
            while IFS=$'\t' read -r n own tr frc ext; do
                [[ -z "$n" ]] && continue
                if [[ "$ext" == "ext" ]]; then
                    desc="(external)"
                else
                    sd="$(skills_dir_for "$REPO_DIR" "$scope" "$own" "$n")"
                    desc=""; [[ -n "$sd" && -f "$sd/SKILL.md" ]] && desc="$(skills_extract_description "$sd/SKILL.md")"
                fi
                printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$scope" "${own:--}" "$tr" "$frc" "${desc:0:64}"
            done < <(jq -r '(.skills // [])[] | select(has("from") | not)
                        | [.name, (.owner // ""), .tier, (if .force then "force" else "-" end), (if .source then "ext" else "" end)] | @tsv' "$jf" 2>/dev/null)
        done < <(find "$REPO_DIR" -name skills.json \
                    -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/src/*' \
                    -not -path "$REPO_DIR/seed/*" -not -path '*/tmp/*' | sort)
    } | column -t -s$'\t'
    exit 0
fi

resolved="$(skills_resolve "$REPO_DIR" "$filter_agent" "${CONNECTED_LEAVES[@]:-}")"
[[ -n "$filter_tier" ]] && resolved="$(awk -F'\t' -v t="$filter_tier" '$4==t' <<< "$resolved")"

if $plain; then printf '%s\n' "$resolved"; exit 0; fi

# Pretty table — substitute "-" for empty fields so column -t doesn't collapse
# adjacent tabs (global-scope rows have an empty owner).
{
    printf 'NAME\tSCOPE\tOWNER\tTIER\tDECLARED-BY\n'
    printf '%s\n' "$resolved"
} | awk -F'\t' 'BEGIN{OFS="\t"} {for(i=1;i<=NF;i++) if($i=="") $i="-"} 1' | column -t -s$'\t'

echo ""
total="$(printf '%s\n' "$resolved"    | grep -c . || true)"
always="$(printf '%s\n' "$resolved"   | awk -F'\t' '$4=="always"'   | grep -c . || true)"
optional="$(printf '%s\n' "$resolved" | awk -F'\t' '$4=="optional"' | grep -c . || true)"
unlisted="$(printf '%s\n' "$resolved" | awk -F'\t' '$4=="unlisted"' | grep -c . || true)"
off_n="$(printf '%s\n' "$resolved"    | awk -F'\t' '$4=="off"'      | grep -c . || true)"
echo "Total: $total  (always: $always, optional: $optional, unlisted: $unlisted, off: $off_n)"
echo "Connected: ${CONNECTED_LEAVES[*]:-<guest: global only>}"
