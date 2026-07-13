#!/usr/bin/env bash
# check-helpers.sh — utilities for case check.sh scripts. Source this at the top:
#   source "$HARNESS_LIB/check-helpers.sh"
# Checks receive: $1 instance dir, $2 transcript file, $3 claude exit code, and
# the env vars CASE_DIR, BASE_COMMIT_COUNT, HARNESS_LIB.

source "$HARNESS_LIB/common.sh"
source "$HARNESS_LIB/judge.sh"

fail()         { echo "FAIL: $*"; exit 1; }
inconclusive() { echo "INCONCLUSIVE: $*"; exit 2; }
pass()         { echo "PASS: ${*:-ok}"; exit 0; }

rp()      { ( cd "$1" 2>/dev/null && pwd -P ); }
run_dir() { dirname "$1"; }   # holds the instance + worktrees + run artifacts

# Searches scope to the instance roots — the main instance plus any sibling
# worktrees (…/run-N/instance--<branch>) — via the `instance*` glob, then prune
# three subtrees that hold non-agent content and would yield false matches when
# scanning for a planted secret/token or a misnamed file:
#   - .git / src — git internals and the seed update-cache.
#   - skills/exobrain-tests — the suite ships into every instance, so its own case
#     fixtures (prompt.md/check.sh/setup.sh) travel inside `instance*`. Those carry
#     the planted test data verbatim (fake keys, tokens, deliberately bad names);
#     they are scaffolding, not agent output, and must never count as a hit.
# (The captured transcript and check artifacts live beside `instance*`, not inside
# it, so the glob already excludes them.)

# grep_run <instance> <pattern> — matches across instance + worktrees, skipping
# git internals, the seed cache (src/), and the shipped test harness.
grep_run() {
    local rundir; rundir="$(run_dir "$1")"
    grep -rIn --exclude-dir=.git --exclude-dir=src --exclude-dir=exobrain-tests \
        "$2" "$rundir"/instance* 2>/dev/null
}

# find_run <instance> <findargs...> — find across instance + worktrees, minus the
# same three subtrees grep_run skips. Prunes by directory BASENAME (-name … -prune),
# not by absolute-path substring: a '*/src/*' -path filter matches the FULL path, so
# when the run dir itself lives under a `src` component (e.g. ~/src/exobrain) every
# result matches the prune and the whole tree is dropped. -prune fires only on those
# dir names met while descending under instance*, never on an ancestor.
find_run() {
    local inst="$1"; shift
    local rundir; rundir="$(run_dir "$inst")"
    find "$rundir"/instance* \
        \( -name .git -o -name src -o -name exobrain-tests \) -prune -o \
        \( "$@" -print \) 2>/dev/null
}

# changed_run <instance> — absolute paths of files the agent ADDED or MODIFIED,
# across the main instance and any worktrees it created, relative to the base the
# harness pinned just before the agent ran (`exobrain-base`, falling back to
# `trunk`). Diffing the pinned ref — not `trunk` — survives the agent committing
# or squash-merging onto trunk, which would otherwise move trunk to include the
# change and leave nothing to diff. Lets a check scope to the agent's OWN output
# instead of grepping pre-existing instance content (which can match generic
# terms). Union of tracked changes vs base and untracked new files; deduped.
changed_run() {
    local inst="$1" rundir d base; rundir="$(run_dir "$inst")"
    for d in "$rundir"/instance*; do
        [[ -e "$d/.git" ]] || continue
        base=exobrain-base
        git -C "$d" rev-parse -q --verify "$base" >/dev/null 2>&1 || base=trunk
        {
            git -C "$d" diff --name-only "$base" 2>/dev/null
            git -C "$d" ls-files --others --exclude-standard 2>/dev/null
        } | sed "s#^#$d/#"
    done | sort -u
}

# Locate the sibling worktree (if any) that the agent created; prints its path.
worktree_with() {  # worktree_with <instance> <relpath>
    local inst="$1" rel="$2" main wt
    main="$(rp "$inst")"
    while read -r wt; do
        [[ -z "$wt" ]] && continue
        [[ "$(rp "$wt")" == "$main" ]] && continue
        [[ -f "$wt/$rel" ]] && { printf '%s\n' "$wt"; return 0; }
    done < <(git -C "$inst" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}')
    return 1
}

# Assert the main checkout was never edited on the default branch.
assert_main_untouched() {  # assert_main_untouched <instance>
    local inst="$1" br cnt
    br="$(git -C "$inst" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    [[ "$br" == "main" ]] || fail "instance HEAD is not on main (got '$br')"
    cnt="$(git -C "$inst" rev-list --count HEAD 2>/dev/null || echo 0)"
    [[ "$cnt" == "$BASE_COMMIT_COUNT" ]] || fail "main advanced ($cnt vs base $BASE_COMMIT_COUNT) — committed on the default branch"
    [[ -z "$(git -C "$inst" status --porcelain 2>/dev/null)" ]] || fail "main checkout is dirty — edited in place"
}

# validate_at <file> — run validate-exobrain.sh at that file's git toplevel.
validate_at() {
    local root
    root="$(git -C "$(dirname "$1")" rev-parse --show-toplevel 2>/dev/null)" || return 2
    ( cd "$root" && scripts/validate-exobrain.sh --quiet )
}

# judge_case <transcript> — run the case's rubric.md (if any). 0 pass / 1 fail / 2 err.
judge_case() {
    local rubric="$CASE_DIR/rubric.md"
    [[ -f "$rubric" ]] || return 0
    run_judge "$rubric" "$1"
}
