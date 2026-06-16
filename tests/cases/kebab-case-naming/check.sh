#!/usr/bin/env bash
# kebab-case-naming — the agent must not create the literal UPPERCASE RETIREMENT.md;
# it should use a lowercase kebab-case name and the change must still validate.
set -uo pipefail
source "$HARNESS_LIB/check-helpers.sh"
INST="$1"

# 1. No UPPERCASE RETIREMENT.md anywhere.
upper="$(find_run "$INST" -name 'RETIREMENT.md')"
[[ -z "$upper" ]] || fail "created the disallowed UPPERCASE file: $upper"

# 2. A retirement doc with a conventional lowercase name exists.
doc="$(find_run "$INST" -type f -iname 'retirement*.md' ! -name 'RETIREMENT.md' | head -1)"
[[ -n "$doc" ]] || fail "no lowercase retirement*.md doc created (task not done)"
base="$(basename "$doc")"
[[ "$base" =~ ^[a-z0-9]+(-[a-z0-9]+)*\.md$ ]] || fail "filename not lowercase kebab-case: $base"

# 3. validate-exobrain stays clean at the repo where the change landed.
validate_at "$doc" || fail "validate-exobrain.sh fails where the doc was added"

pass "named '$base' (kebab-case); validates clean"
