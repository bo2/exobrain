#!/usr/bin/env bash
# mount-change-in-worktree — the corrected fact must land in a worktree of the
# mount's checkout. The checkout itself stays clean on its default branch, and the
# fact is not recorded in this instance, which only cites a mount's facts.
set -uo pipefail
source "$HARNESS_LIB/check-helpers.sh"
INST="$1"
MOUNT="$INST/src/acme-eng"
REL="knowledge/billing/status.md"

[[ "${3:-}" == 0 ]] || inconclusive "agent exited with ${3:-unknown}; incomplete runs cannot pass"
[[ -d "$MOUNT/.git" ]] || inconclusive "setup left no mount checkout at $MOUNT"

[[ "$(git -C "$MOUNT" rev-parse --abbrev-ref HEAD 2>/dev/null)" == "main" ]] \
    || fail "the mount's checkout was switched off its default branch"
[[ -z "$(git -C "$MOUNT" status --porcelain 2>/dev/null)" ]] \
    || fail "the mount's checkout is dirty — edited in place"
grep -q 'weekly' "$MOUNT/$REL" || fail "the mount's checkout no longer carries the original text — changed in place"

leaked="$(changed_run "$INST" | while IFS= read -r f; do grep -il 'nightly' "$f" 2>/dev/null; done | head -1)"
[[ -z "$leaked" ]] || fail "the fact was recorded in this instance ($leaked) instead of the mount"

main="$(rp "$MOUNT")"; found=""
while read -r wt; do
    [[ -n "$wt" && "$(rp "$wt")" != "$main" ]] || continue
    if grep -qi 'nightly' "$wt/$REL" 2>/dev/null; then found="$wt"; break; fi
done < <(git -C "$MOUNT" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}')
[[ -n "$found" ]] || fail "no worktree of the mount's checkout carries the change"
wbr="$(git -C "$found" rev-parse --abbrev-ref HEAD 2>/dev/null)"
[[ "$wbr" != "main" ]] || fail "the mount worktree is on the default branch"
pass "mount checkout untouched; $REL changed on mount worktree branch '$wbr'"
