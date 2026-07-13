#!/usr/bin/env bash
# update-routes-to-pull — "update exobrain" must resolve to a local checkout
# update (git pull --ff-only), not the exobrain-evolve seed-adoption flow (nor a
# connect-agent relink). Plan-mode case: no filesystem change to assert, so the
# routing decision is read from the transcript by the rubric judge.
set -uo pipefail
source "$HARNESS_LIB/check-helpers.sh"
TRANSCRIPT="$2"

judge_out="$(judge_case "$TRANSCRIPT")"; jrc=$?
case "$jrc" in
    0) pass "treated 'update exobrain' as a checkout update -- $judge_out" ;;
    2) inconclusive "judge errored: $judge_out" ;;
    *) fail "mis-routed (evolve/relink instead of git pull) -- $judge_out" ;;
esac
