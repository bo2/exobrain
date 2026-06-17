#!/usr/bin/env bash
# smoke — the instance is untouched; just confirm the pipeline ran and the
# scaffolded instance still validates.
set -uo pipefail
source "$HARNESS_LIB/check-helpers.sh"
INST="$1"; TRANSCRIPT="$2"

[[ -s "$TRANSCRIPT" ]] || fail "empty transcript — agent produced no output"
( cd "$INST" && scripts/validate-exobrain.sh --quiet ) || fail "instance fails validate-exobrain.sh"
pass "pipeline ran; instance validates"
