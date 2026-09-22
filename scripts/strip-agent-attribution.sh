#!/usr/bin/env bash
# strip-agent-attribution.sh — remove agent attribution from a commit message, so
# this repo's history stays agent-neutral (CLAUDE.md § Git history hygiene) whatever
# the committing agent was told to append. The connector's commit-msg hook runs it
# on every commit; validate-exobrain.sh rejects the same lines in a commit that
# bypassed the hook.
#
#   scripts/strip-agent-attribution.sh <message-file>   # rewrite the file in place
#
# A line is attribution when it is a Co-Authored-By trailer naming an agent, or a
# "Generated with <agent>" footer (optionally 🤖-prefixed). Matching is
# line-anchored and case-insensitive, so prose describing the rule stays, and so
# does a human co-author's trailer. Blank lines the removal leaves at the end go too.

set -euo pipefail

# Kept identical to AGENT_ATTRIBUTION_RE in validate-exobrain.sh (the unit suite checks).
AGENT_ATTRIBUTION_RE='^(co-authored-by:[[:space:]]*(claude|codex|openclaw)|(🤖[[:space:]]*)?generated with[[:space:]]+\[?(claude|codex|openclaw))'

[[ $# -eq 1 && -f "$1" ]] || { echo "Usage: $0 <commit-message-file>" >&2; exit 2; }
msg="$1"

grep -q -i -E "$AGENT_ATTRIBUTION_RE" "$msg" || exit 0

tmp="$msg.strip.$$"
grep -v -i -E "$AGENT_ATTRIBUTION_RE" "$msg" \
    | awk '{ line[NR] = $0 } END { n = NR; while (n > 0 && line[n] ~ /^[[:space:]]*$/) n--; for (i = 1; i <= n; i++) print line[i] }' \
    > "$tmp" || true
mv -f "$tmp" "$msg"
echo "commit-msg: removed agent attribution (CLAUDE.md § Git history hygiene)" >&2
