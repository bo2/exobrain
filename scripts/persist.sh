#!/usr/bin/env bash
# persist.sh — land a completed logical change from a worktree onto the default
# branch: timeline rows → commit → validate → authoring review → push → PR →
# squash-merge → update the main checkout → remove the worktree and branch.
# The mechanical tail of the exobrain-persist skill, in one idempotent command.
#
#   scripts/persist.sh [-m <message>] [--timeline <summary>] [--title <PR title>]
#                      [--author <id>] [--machinery-verified] [--dry-run]
#   scripts/persist.sh --sweep [--dry-run]
#
# Run it from inside the worktree holding the change. Uncommitted work is
# committed with -m (required only when nothing is committed yet); a branch that
# already carries commits needs no message; the PR is titled after the branch's
# first commit unless --title says otherwise. Every step checks whether it has
# already happened, so re-running after an interruption — a killed process, a
# failed pull, a merged PR whose worktree was never removed — finishes the land
# instead of failing on it.
#
# A change touching shared machinery (root scripts/ and skills/, the registries,
# the global-scope specs) is gated: the script runs the deterministic unit suite
# itself, and lands only when --machinery-verified asserts the agent-judged half
# (the behavior suite, and exobrain-ab where the change alters behavior).
#
# --sweep runs against the repo this script lives in (any checkout of it) and
# lands every pending worktree: one a run of this script already claimed (its
# `persist-requested` marker survives a kill), or one that is clean, ahead of the
# default branch, and quiet for at least PERSIST_QUIET_MINUTES (default 60) — so
# a session still committing to its branch is left alone. Dirty worktrees are
# reported, never touched.
#
# Exit: 0 landed (or nothing to land) · 1 a step failed (the branch keeps whatever
# progress was made; re-run to resume) · 2 usage · 3 the machinery gate (the
# message says how to clear it).
#
# Lands serialize on a lock in the main checkout's .git, so two of them — a chat
# turn and the sweep, say — never race on the main checkout's pull or worktree
# table. Environment: EXOBRAIN_SKIP_AUTHORING_REVIEW=1 skips the review (its own
# opt-out); PERSIST_QUIET_MINUTES sets the sweep's quiet period; EXOBRAIN_AUTHOR
# names the timeline author (else .exobrain.json's person, else git user.name).

set -uo pipefail

# A scheduled run starts with a minimal PATH.
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MACHINERY_FLAG="--machinery-verified"
MACHINERY_VERIFIED="${MACHINERY_VERIFIED:-0}"
UNIT_SUITE="skills/exobrain-tests/unit/run.sh"
LOCK_STALE_MINUTES=30
LOCK_WAIT_SECONDS=600

log()  { echo "persist: $*"; }
warn() { echo "persist: $*" >&2; }
die()  { echo "persist: $*" >&2; exit "${2:-1}"; }

usage() { grep '^#' "$0" | sed -n '2,38p' | sed 's/^# \{0,1\}//'; }

# ---------------------------------------------------------------------------
# Repo geometry
# ---------------------------------------------------------------------------

# main_root <any path inside the repo> — the main checkout's working directory.
main_root() {
    local common
    common="$(git -C "$1" rev-parse --git-common-dir 2>/dev/null)" || return 1
    [[ "$common" = /* ]] || common="$(cd "$1" && cd "$common" && pwd)"
    (cd "$common/.." && pwd)
}

# default_branch <main root> — origin's default branch, else main/trunk/master.
default_branch() {
    local ref cand
    if ref="$(git -C "$1" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"; then
        echo "${ref#origin/}"; return 0
    fi
    for cand in main trunk master; do
        if git -C "$1" rev-parse --verify --quiet "refs/remotes/origin/$cand" >/dev/null \
           || git -C "$1" rev-parse --verify --quiet "refs/heads/$cand" >/dev/null; then
            echo "$cand"; return 0
        fi
    done
    return 1
}

has_remote() { git -C "$1" remote get-url origin >/dev/null 2>&1; }

# base_ref <main root> <default branch> — what the change is measured against:
# origin's default branch when there is a remote, the local one otherwise.
base_ref() {
    if has_remote "$1" && git -C "$1" rev-parse --verify --quiet "refs/remotes/origin/$2" >/dev/null; then
        echo "origin/$2"
    else
        echo "$2"
    fi
}

# ---------------------------------------------------------------------------
# Lock — one land at a time per repo
# ---------------------------------------------------------------------------

LOCK_DIR=""
take_lock() {
    local common waited=0
    common="$(git -C "$1" rev-parse --git-common-dir)"
    [[ "$common" = /* ]] || common="$1/$common"
    LOCK_DIR="$common/exobrain-persist.lock"
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        if [[ -n "$(find "$LOCK_DIR" -maxdepth 0 -mmin +$LOCK_STALE_MINUTES 2>/dev/null)" ]]; then
            warn "taking over a stale lock ($LOCK_DIR)"
            rm -rf "$LOCK_DIR"; continue
        fi
        (( waited >= LOCK_WAIT_SECONDS )) && die "another persist has held the lock for ${waited}s ($LOCK_DIR)"
        sleep 5; waited=$((waited + 5))
    done
    echo "$$ $(date +%s)" > "$LOCK_DIR/owner"
    trap 'release_lock' EXIT
}
release_lock() { [[ -n "$LOCK_DIR" ]] && rm -rf "$LOCK_DIR"; LOCK_DIR=""; }

# ---------------------------------------------------------------------------
# Land one worktree
# ---------------------------------------------------------------------------

DRY_RUN=0; PR_TITLE=""
run() { if (( DRY_RUN )); then log "would: $*"; else "$@"; fi; }

# author_id <main root> — who a timeline row is attributed to.
author_id() {
    if [[ -n "${EXOBRAIN_AUTHOR:-}" ]]; then echo "$EXOBRAIN_AUTHOR"; return; fi
    local from_cfg=""
    if [[ -f "$1/.exobrain.json" ]] && command -v jq >/dev/null 2>&1; then
        from_cfg="$(jq -r '.person // ""' "$1/.exobrain.json" 2>/dev/null)"
    fi
    [[ -n "$from_cfg" ]] && { echo "$from_cfg"; return; }
    git -C "$1" config user.name 2>/dev/null || echo "unknown"
}

# machinery_paths <worktree> <base> — changed paths (committed + working tree)
# that shape other agents' behavior: root scripts, root skills, the registries,
# and the global-scope specs. Person/host scopes are exempt.
machinery_paths() {
    {
        git -C "$1" diff --name-only "$2"...HEAD 2>/dev/null
        git -C "$1" status --porcelain --untracked-files=all | cut -c4- | sed 's/^.* -> //'
    } | sort -u | grep -E '^(scripts/|skills/|skills\.json$|scopes\.json$|skills\.schema\.json$|AGENTS\.md$|CLAUDE\.md$|CODEX\.md$|OPENCLAW\.md$)' || true
}

# timeline_rows <worktree> <base> <summary> <author> — append one row per
# timeline-tracked domain or workspace this change touches. Idempotent: a row
# with today's date and the same summary is not written twice.
timeline_rows() {
    local wt="$1" base="$2" summary="$3" author="$4" today readme dir tl row
    today="$(date +%F)"
    row="| $today | $author | $summary |"
    while IFS= read -r readme; do
        [[ -n "$readme" ]] || continue
        dir="$(dirname "$readme")"
        local changed
        changed="$({ git -C "$wt" diff --name-only "$base"...HEAD -- "$dir" 2>/dev/null
                     git -C "$wt" status --porcelain --untracked-files=all -- "$dir" | cut -c4-; } \
                   | grep -v "^$dir/TIMELINE.md$" | head -1)"
        [[ -n "$changed" ]] || continue
        tl="$wt/$dir/TIMELINE.md"
        if [[ -f "$tl" ]] && grep -qF -- "$row" "$tl"; then continue; fi
        log "timeline row → $dir/TIMELINE.md"
        (( DRY_RUN )) && continue
        if [[ ! -f "$tl" ]]; then
            printf '# Timeline\n\n| Date | Author | Summary |\n|------|--------|---------|\n' > "$tl"
        fi
        # Keep the table well-formed when the file's last line lacks a newline.
        [[ -z "$(tail -c1 "$tl")" ]] || echo >> "$tl"
        echo "$row" >> "$tl"
    done < <(cd "$wt" && grep -rl --include=README.md -E '^timeline:[[:space:]]*true' knowledge workspaces 2>/dev/null || true)
}

# pr_state <worktree> <branch> — "<number> <STATE>" for the branch's PR, or empty.
pr_state() {
    (cd "$1" && gh pr list --head "$2" --state all --json number,state --jq '.[0] | select(. != null) | "\(.number) \(.state)"' 2>/dev/null) || true
}

# land <worktree path> [message] [timeline summary] [author]
land() {
    local wt="$1" message="${2:-}" tl_summary="${3:-}" author="${4:-}"
    local main branch default base gitdir marker

    wt="$(cd "$wt" && git rev-parse --show-toplevel)" || die "not a git checkout: $1"
    main="$(main_root "$wt")" || die "cannot resolve the main checkout for $wt"
    branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
    default="$(default_branch "$main")" || die "cannot resolve the default branch"
    [[ "$branch" != "HEAD" ]] || die "$wt is on a detached HEAD"
    [[ "$branch" != "$default" ]] || die "$wt is on the default branch ($default) — persist runs from a worktree on its own branch (AGENTS.md § Git workflow)"
    [[ "$wt" != "$main" ]] || die "$wt is the main checkout — move the work to a worktree first (scripts/create-worktree.sh)"
    base="$(base_ref "$main" "$default")"
    [[ -n "$author" ]] || author="$(author_id "$main")"

    gitdir="$(git -C "$wt" rev-parse --git-dir)"; [[ "$gitdir" = /* ]] || gitdir="$wt/$gitdir"
    marker="$gitdir/persist-requested"

    log "landing $branch from $wt onto $default"
    take_lock "$main"
    # The claim carries the machinery assertion, so a run that dies after
    # asserting it is swept without the flag being repeated.
    if [[ -f "$marker" ]] && grep -qx 'machinery-verified' "$marker" 2>/dev/null; then MACHINERY_VERIFIED=1; fi
    if (( ! DRY_RUN )); then
        if [[ "$MACHINERY_VERIFIED" == "1" ]]; then echo machinery-verified > "$marker"; else touch "$marker"; fi
    fi

    # Refresh the base so "ahead of" and the machinery diff mean current trunk.
    if has_remote "$main"; then
        git -C "$main" fetch --quiet origin "$default" 2>/dev/null || warn "fetch failed; measuring against the last known $base"
    fi

    # ---- machinery gate --------------------------------------------------
    local machinery
    machinery="$(machinery_paths "$wt" "$base")"
    if [[ -n "$machinery" && "$MACHINERY_VERIFIED" != "1" ]]; then
        rm -f "$marker"
        {
            echo "persist: this change touches shared machinery, which must be behaviorally verified before it lands (exobrain-persist skill, step 3):"
            echo "$machinery" | sed 's/^/    /'
            echo "persist: this script runs the unit suite ($UNIT_SUITE) itself; run the behavior suite (and exobrain-ab where the change alters behavior), then re-run with $MACHINERY_FLAG to assert that it happened"
        } >&2
        exit 3
    fi
    if [[ -n "$machinery" && -x "$wt/$UNIT_SUITE" ]]; then
        log "machinery changed — running $UNIT_SUITE"
        (( DRY_RUN )) || (cd "$wt" && "$UNIT_SUITE") || die "unit suite failed — fix, amend, then re-run"
    fi

    # ---- commit ----------------------------------------------------------
    local dirty ahead
    dirty="$(git -C "$wt" status --porcelain --untracked-files=all)"
    ahead="$(git -C "$wt" rev-list --count "$base"..HEAD 2>/dev/null || echo 0)"
    if [[ -z "$dirty" && "$ahead" == "0" ]]; then
        rm -f "$marker"; log "nothing to land: $branch has no changes against $base"; return 0
    fi
    [[ -n "$message" || "$ahead" != "0" ]] || die "uncommitted changes and no commit yet — pass -m <message>" 2
    [[ -n "$tl_summary" ]] || tl_summary="${message:-$(git -C "$wt" log -1 --format=%s)}"

    timeline_rows "$wt" "$base" "$tl_summary" "$author"

    dirty="$(git -C "$wt" status --porcelain --untracked-files=all)"
    if [[ -n "$dirty" ]]; then
        log "committing:"; echo "$dirty" | sed 's/^/    /'
        if [[ "$ahead" != "0" && -z "$message" ]] && ! git -C "$wt" merge-base --is-ancestor HEAD "refs/remotes/origin/$branch" 2>/dev/null; then
            # Only timeline rows on top of an unpushed commit: fold them in.
            run git -C "$wt" add -A && run git -C "$wt" commit --quiet --amend --no-edit || die "commit failed"
        else
            [[ -n "$message" ]] || message="Persist $branch"
            run git -C "$wt" add -A && run git -C "$wt" commit --quiet -m "$message" || die "commit failed"
        fi
    fi

    # ---- gates -----------------------------------------------------------
    if [[ -x "$wt/scripts/validate-exobrain.sh" ]]; then
        log "validate-exobrain.sh"
        (( DRY_RUN )) || (cd "$wt" && scripts/validate-exobrain.sh) || die "validation failed — fix, then re-run"
    fi
    if [[ -x "$wt/scripts/authoring-review.sh" ]]; then
        log "authoring-review.sh"
        (( DRY_RUN )) || (cd "$wt" && scripts/authoring-review.sh) || die "authoring review flagged violations — fix, amend, then re-run"
    fi

    # ---- no remote: fast-forward the local default branch -----------------
    if ! has_remote "$main"; then
        log "no remote: fast-forwarding $default to $branch"
        run git -C "$main" merge --ff-only --quiet "$branch" || die "fast-forward of $default failed"
        cleanup_worktree "$main" "$wt" "$branch" 0
        rm -f "$marker"
        log "landed $branch onto $default (local)"
        return 0
    fi

    # ---- push · PR · merge ---------------------------------------------------
    local pr number state
    pr="$(pr_state "$wt" "$branch")"; number="${pr%% *}"; state="${pr#* }"
    if [[ "$state" != "MERGED" ]]; then
        log "pushing $branch"
        run git -C "$wt" push --quiet -u origin "$branch" || die "push failed"
        if [[ -z "$pr" ]]; then
            local title body
            # The branch's first commit names the change; later ones refine it.
            title="${PR_TITLE:-$(git -C "$wt" log --reverse --format=%s "$base"..HEAD | head -1)}"
            body="$(git -C "$wt" log --reverse --format='- %s%n%n%b' "$base"..HEAD | sed -e 's/[[:space:]]*$//' | cat -s)"
            log "opening PR: $title"
            if (( DRY_RUN )); then :; else
                (cd "$wt" && gh pr create --base "$default" --head "$branch" --title "$title" --body "$body") || die "gh pr create failed"
            fi
            pr="$(pr_state "$wt" "$branch")"; number="${pr%% *}"; state="${pr#* }"
        fi
        if (( ! DRY_RUN )); then
            [[ -n "$number" ]] || die "no PR found for $branch after creating one"
            log "squash-merging PR $number"
            if ! (cd "$wt" && gh pr merge "$number" --squash 2>&1 | sed 's/^/    /'; exit "${PIPESTATUS[0]}"); then
                # Usually a conflict with what landed on the default branch since
                # this branch forked: bring the branch up to date and try once more.
                log "merge refused; merging $base into $branch and retrying"
                git -C "$wt" fetch --quiet origin "$default" || true
                if ! git -C "$wt" merge --quiet --no-edit "$base"; then
                    git -C "$wt" merge --abort 2>/dev/null || true
                    die "conflict with $default — resolve it in $wt, then re-run"
                fi
                git -C "$wt" push --quiet origin "$branch" || die "push after merge failed"
                (cd "$wt" && gh pr merge "$number" --squash) || die "gh pr merge failed after retry"
            fi
            pr="$(pr_state "$wt" "$branch")"; state="${pr#* }"
            [[ "$state" == "MERGED" ]] || die "PR $number is $state after merging; check it on the forge"
        fi
    else
        log "PR $number already merged"
    fi

    # ---- update main · clean up --------------------------------------------
    log "updating the main checkout"
    run git -C "$main" pull --ff-only --quiet || die "the main checkout did not fast-forward ($main); fix it, then re-run to finish cleanup"
    cleanup_worktree "$main" "$wt" "$branch" 1
    rm -f "$marker" 2>/dev/null || true
    log "landed $branch as PR $number"
}

# cleanup_worktree <main> <worktree> <branch> <delete remote 0|1>
cleanup_worktree() {
    local main="$1" wt="$2" branch="$3" remote="$4"
    log "removing worktree $wt and branch $branch"
    (( DRY_RUN )) && return 0
    cd "$main" || die "cannot cd to $main"
    git -C "$main" worktree remove --force "$wt" || warn "worktree remove failed for $wt"
    git -C "$main" branch -D "$branch" >/dev/null 2>&1 || true
    if (( remote )); then
        git -C "$main" push --quiet origin --delete "$branch" 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------------
# Sweep — land every pending worktree
# ---------------------------------------------------------------------------

sweep() {
    local main default base quiet="${PERSIST_QUIET_MINUTES:-60}"
    main="$(main_root "$SCRIPT_DIR")" || die "$SCRIPT_DIR is not inside a git repo"
    default="$(default_branch "$main")" || die "cannot resolve the default branch"
    has_remote "$main" && git -C "$main" fetch --quiet origin "$default" 2>/dev/null
    base="$(base_ref "$main" "$default")"

    local failed=0 landed=0 skipped=0 path branch gitdir reason
    while IFS='|' read -r path branch; do
        [[ -n "$path" && "$path" != "$main" ]] || continue
        [[ -d "$path" ]] || { warn "worktree missing on disk: $path (git worktree prune)"; continue; }
        [[ -n "$branch" && "$branch" != "$default" ]] || continue
        gitdir="$(git -C "$path" rev-parse --git-dir)"; [[ "$gitdir" = /* ]] || gitdir="$path/$gitdir"
        reason=""
        if [[ -f "$gitdir/persist-requested" ]]; then
            reason="claimed by an earlier persist"
        elif [[ -n "$(git -C "$path" status --porcelain --untracked-files=all)" ]]; then
            log "skip $branch: uncommitted changes (someone may be working there)"; skipped=$((skipped + 1)); continue
        elif [[ "$(git -C "$path" rev-list --count "$base"..HEAD 2>/dev/null || echo 0)" == "0" ]]; then
            continue
        elif (( ( $(date +%s) - $(git -C "$path" log -1 --format=%ct) ) / 60 < quiet )); then
            log "skip $branch: committed less than ${quiet}m ago"; skipped=$((skipped + 1)); continue
        else
            reason="clean, ahead of $default, quiet for ${quiet}m"
        fi
        log "── $branch ($reason)"
        if (land "$path"); then landed=$((landed + 1)); else failed=$((failed + 1)); fi
    done < <(git -C "$main" worktree list --porcelain | awk '
        /^worktree /{p=substr($0,10)} /^branch /{b=substr($0,8); sub("refs/heads/","",b)} /^$/{if(p){print p"|"b}; p="";b=""}
        END{if(p)print p"|"b}')
    log "sweep: $landed landed, $skipped skipped, $failed failed"
    (( failed == 0 ))
}

# ---------------------------------------------------------------------------

main() {
    local mode=land message="" tl_summary="" author=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--message)   message="${2:-}"; shift 2 ;;
            --timeline)     tl_summary="${2:-}"; shift 2 ;;
            --author)       author="${2:-}"; shift 2 ;;
            --title)        PR_TITLE="${2:-}"; shift 2 ;;
            --sweep)        mode=sweep; shift ;;
            --dry-run)      DRY_RUN=1; shift ;;
            "$MACHINERY_FLAG") MACHINERY_VERIFIED=1; shift ;;
            -h|--help)      usage; exit 0 ;;
            *)              echo "persist: unknown argument: $1" >&2; usage >&2; exit 2 ;;
        esac
    done
    command -v git >/dev/null || die "git not found"
    case "$mode" in
        land)  land "$PWD" "$message" "$tl_summary" "$author" ;;
        sweep) sweep ;;
    esac
}

main "$@"
