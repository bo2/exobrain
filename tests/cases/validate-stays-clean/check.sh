#!/usr/bin/env bash
# validate-stays-clean — the new gardening domain exists with a README and the
# instance still passes validate-exobrain.sh.
set -uo pipefail
source "$HARNESS_LIB/check-helpers.sh"
INST="$1"

readme="$(find_run "$INST" -type f -ipath '*domains/gardening/README.md' | head -1)"
[[ -n "$readme" ]] || fail "domains/gardening/README.md was not created"
[[ -s "$readme" ]] || fail "domains/gardening/README.md is empty"
validate_at "$readme" || fail "validate-exobrain.sh fails after adding the gardening domain"
pass "gardening domain added with README; validates clean"
