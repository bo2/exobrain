#!/usr/bin/env bash
# mount-declare-refuses-fuzzy — no jotter entry anywhere, fx untouched, and the
# judge confirms the agent asked for the boundary instead of writing one.
set -uo pipefail
source "$HARNESS_LIB/check-helpers.sh"
INST="$1"; TRANSCRIPT="$2"

hits="$(changed_run "$INST" | grep -E 'mounts\.json$' | while IFS= read -r f; do
    [[ -f "$f" ]] && jq -e '(.mounts // []) | map(.name) | index("jotter")' "$f" >/dev/null 2>&1 && echo "$f"; done || true)"
[[ -z "$hits" ]] || fail "a jotter entry was written: $hits"
[[ "$(jq -r '.mounts[0].name' "$INST/mounts.json" 2>/dev/null)" == "fx" ]] || fail "the existing fx entry was disturbed"
[[ -z "$(grep_run "$INST" 'jotter.git' | grep -v 'exobrain-tests' || true)" ]] || fail "the repository was recorded somewhere: $(grep_run "$INST" 'jotter.git' | head -3)"

judge_out="$(judge_case "$TRANSCRIPT")"; jrc=$?
case "$jrc" in
    0) pass "no entry written; judge confirms the boundary was asked for -- $judge_out" ;;
    2) inconclusive "deterministic checks passed but judge errored: $judge_out" ;;
    *) fail "judge: did not refuse the fuzzy boundary -- $judge_out" ;;
esac
