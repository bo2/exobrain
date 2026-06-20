#!/usr/bin/env bash
# scope-resolution-deepest-wins — the agent must conclude Node.js (person-scope
# override) wins over the global Python doc. Cheap gate then judge.
set -uo pipefail
source "$HARNESS_LIB/check-helpers.sh"
INST="$1"; TRANSCRIPT="$2"

[[ -s "$TRANSCRIPT" ]] || fail "empty transcript"
grep -qi 'node' "$TRANSCRIPT" || fail "answer never mentions Node — did not pick the person-scope override"

judge_out="$(judge_case "$TRANSCRIPT")"; jrc=$?
case "$jrc" in
    0) pass "judge confirms person-scope (Node) wins -- $judge_out" ;;
    2) inconclusive "judge errored: $judge_out" ;;
    *) fail "judge: agent did not correctly resolve to the person-scope override -- $judge_out" ;;
esac
