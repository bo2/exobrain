#!/usr/bin/env bash
# route-fact-to-domain — the brokerage fact must land in the finance domain (a
# durable area), not in the home domain and not in a time-bound workspace.
set -uo pipefail
source "$HARNESS_LIB/check-helpers.sh"
INST="$1"; TRANSCRIPT="$2"

# Where did the fact land? (search across instance + worktrees)
fin="$(grep -rilE 'fidelity|brokerage' "$(run_dir "$INST")" --include='*.md' 2>/dev/null \
        | grep -iE '/domains/finance' | grep -v '/src/' | head -1)"
ws="$(grep -rilE 'fidelity|brokerage' "$(run_dir "$INST")" --include='*.md' 2>/dev/null \
        | grep -iE '/workspaces/' | grep -v '/src/' | head -1)"

[[ -z "$ws" ]] || fail "fact filed into a workspace ($ws) — workspaces outdate; durable facts go in domains/"
[[ -n "$fin" ]] || fail "fact not found in a finance domain file (mis-routed or not recorded)"

judge_out="$(judge_case "$TRANSCRIPT")"; jrc=$?
case "$jrc" in
    0) pass "routed to finance domain ($fin); judge agrees -- $judge_out" ;;
    2) inconclusive "judge errored: $judge_out" ;;
    *) fail "judge: routing not appropriate -- $judge_out" ;;
esac
