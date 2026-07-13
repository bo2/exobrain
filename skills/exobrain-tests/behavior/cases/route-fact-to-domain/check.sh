#!/usr/bin/env bash
# route-fact-to-domain — the brokerage fact must land in the finance domain (a
# durable area), not in the home domain and not in a time-bound workspace.
set -uo pipefail
source "$HARNESS_LIB/check-helpers.sh"
INST="$1"; TRANSCRIPT="$2"

# Where did the fact land? Scope to files the AGENT changed (vs the pinned base), not
# all instance content: an instance can ship real domains/workspaces where 'fidelity'/
# 'brokerage' already appear in unrelated prose, which a blanket grep would false-match.
mapfile -t hits < <(changed_run "$INST" | grep -iE '\.md$' | while IFS= read -r f; do
    grep -ilE 'fidelity|brokerage' "$f" 2>/dev/null
done)
fin="$(printf '%s\n' "${hits[@]}" | grep -iE '/domains/finance' | head -1)"
ws="$(printf '%s\n' "${hits[@]}" | grep -iE '/workspaces/' | head -1)"

[[ -z "$ws" ]] || fail "fact filed into a workspace ($ws) — workspaces outdate; durable facts go in domains/"
[[ -n "$fin" ]] || fail "fact not found in a finance domain file (mis-routed or not recorded)"

judge_out="$(judge_case "$TRANSCRIPT")"; jrc=$?
case "$jrc" in
    0) pass "routed to finance domain ($fin); judge agrees -- $judge_out" ;;
    2) inconclusive "judge errored: $judge_out" ;;
    *) fail "judge: routing not appropriate -- $judge_out" ;;
esac
