#!/usr/bin/env bash
# worktree-first — the new file must land in a sibling worktree on a non-main
# branch; the main checkout must be completely untouched.
set -uo pipefail
source "$HARNESS_LIB/check-helpers.sh"
INST="$1"
REL="domains/test-topic/README.md"

assert_main_untouched "$INST"
[[ ! -f "$INST/$REL" ]] || fail "$REL present in the MAIN checkout — not worktree-isolated"

wt="$(worktree_with "$INST" "$REL")" || fail "no sibling worktree contains $REL (edited default branch or skipped worktree)"
wbr="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)"
[[ "$wbr" != "main" ]] || fail "worktree is on main"
pass "main untouched; $REL on worktree branch '$wbr'"
