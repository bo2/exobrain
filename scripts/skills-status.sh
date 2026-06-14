#!/usr/bin/env bash
# skills-status.sh — show the effective skills registry for the current user/host.
#
# Usage:
#   skills-status.sh                # auto-detect from .exobrain.json
#   skills-status.sh --tier=always  # filter to one tier
#   skills-status.sh --plain        # TSV output (name, scope, owner, tier, declared-by)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=skills-registry.sh
source "$SCRIPT_DIR/skills-registry.sh"

CONFIG_FILE="$REPO_DIR/.exobrain.json"
CONNECTED_LEAVES=()
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS= read -r _l; do [[ -n "$_l" ]] && CONNECTED_LEAVES+=("$_l"); done \
        < <(jq -r '(.connected // [])[]' "$CONFIG_FILE" 2>/dev/null)
fi

filter_tier=""
filter_agent=""
plain=false
for arg in "$@"; do
    case "$arg" in
        --tier=*)  filter_tier="${arg#--tier=}" ;;
        --agent=*) filter_agent="${arg#--agent=}" ;;
        --plain)   plain=true ;;
        -h|--help)
            head -n 7 "$0" | tail -n +2 | sed 's/^# \{0,1\}//'
            exit 0 ;;
    esac
done

resolved="$(skills_resolve "$REPO_DIR" "$filter_agent" "${CONNECTED_LEAVES[@]:-}")"

if [[ -n "$filter_tier" ]]; then
    resolved="$(awk -F'\t' -v t="$filter_tier" '$4==t' <<<"$resolved")"
fi

if $plain; then
    printf '%s\n' "$resolved"
    exit 0
fi

# Pretty table — substitute "-" for empty fields so column -t doesn't collapse
# adjacent tabs (global-scope entries have an empty owner).
{
    printf 'NAME\tSCOPE\tOWNER\tTIER\tDECLARED-BY\n'
    printf '%s\n' "$resolved"
} | awk -F'\t' 'BEGIN{OFS="\t"} {for(i=1;i<=NF;i++) if($i=="") $i="-"} 1' \
  | column -t -s$'\t'

echo ""
total="$(printf '%s\n' "$resolved"   | grep -c . || true)"
always="$(printf '%s\n' "$resolved"  | awk -F'\t' '$4=="always"'   | grep -c . || true)"
optional="$(printf '%s\n' "$resolved" | awk -F'\t' '$4=="optional"' | grep -c . || true)"
off_n="$(printf '%s\n' "$resolved"   | awk -F'\t' '$4=="off"'      | grep -c . || true)"
echo "Total: $total  (always: $always, optional: $optional, off: $off_n)"
echo "Connected: ${CONNECTED_LEAVES[*]:-<guest: global only>}"
