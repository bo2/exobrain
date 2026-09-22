#!/usr/bin/env bash
# persist.sh — land a completed logical change from a worktree onto the default
# branch: timeline rows → commit → validate → authoring review → push → PR →
# squash-merge → update the main checkout → remove the worktree and branch.
# The mechanical tail of the exobrain-persist skill, in one idempotent command.
#
#   scripts/persist.sh [-m <message>] [--timeline <summary>] [--title <PR title>]
#                      [--author <id>] [--context <file>] [--machinery-verified]
#                      [--dry-run]
#   scripts/persist.sh --detach [same options]
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
# Two kinds of change are verified before they land (exobrain-persist skill, step 3).
# An agent spec at any scope — AGENTS.md, a CLAUDE.md or CODEX.md sidecar, a SKILL.md —
# lands only when a passing behavioral run recorded under the worktree's tmp/test-runs
# covers it: the run tested this change's specs as they are now, wired the spec's scope,
# and for a sidecar ran that sidecar's agent. The PR body lists the runs. The rest of
# the shared machinery — root scripts, root skills' code, the registries, OpenClaw
# sidecars — is gated on the author's word: the script runs the deterministic unit
# suite itself, and lands only when --machinery-verified asserts the agent-judged half
# (the behavior suite, and exobrain-ab where the change alters behavior).
#
# --detach commits in the foreground, then hands the rest of the land to a
# process in its own session and returns at once, printing where that process
# logs (<main checkout>/.git/persist-logs/<branch>.log). A chat turn uses it so
# the person's reply never waits on the forge; a land that fails is retried by
# --sweep.
#
# A detached or swept land is unattended: nobody is there to act on an authoring
# finding, so the review's findings are posted as a comment review on the PR for
# the curator instead of blocking. The review's deterministic proof gate (exit 2) blocks either way,
# and so does the validator. A foreground land blocks on every finding.
#
# --context <file> copies that file into the PR body as the session's handover to
# whoever later acts on those findings: what the person asked for, what the
# session decided, what it was unsure about. Write it under the worktree's
# gitignored tmp/ — the worktree is removed as the land finishes, and the PR is
# what survives.
#
# --sweep runs against the repo this script lives in (any checkout of it) and
# lands every pending worktree: one a run of this script already claimed (its
# `persist-requested` marker survives a kill), or one that is clean, ahead of the
# default branch, and quiet for at least PERSIST_QUIET_MINUTES (default 60) — so
# a session still committing to its branch is left alone. A dirty worktree is
# never touched, and neither is one the verification gate would refuse (a spec no
# passing run covers, or a machinery diff whose claim carries no
# --machinery-verified): both wait for a person or an agent, so neither fails the
# sweep. One that has waited PERSIST_STALE_DAYS (default 2) is reported
# as stale and does fail it, so a scheduled sweep's alert names it — finish and
# land it, or remove it.
#
# Exit: 0 landed (or nothing to land) · 1 a step failed or the sweep found a stale
# worktree (the branch keeps whatever progress was made; re-run to resume) ·
# 2 usage · 3 the verification gate (the message says how to clear it).
#
# Lands serialize on a lock in the main checkout's .git, so two of them — a chat
# turn and the sweep, say — never race on the main checkout's pull or worktree
# table. Environment: EXOBRAIN_SKIP_AUTHORING_REVIEW=1 skips the review (its own
# opt-out); PERSIST_QUIET_MINUTES sets the sweep's quiet period and
# PERSIST_STALE_DAYS its stale threshold; EXOBRAIN_AUTHOR names the timeline
# author (else .exobrain.json's person, else git user.name).

set -uo pipefail

# A scheduled run starts with a minimal PATH.
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MACHINERY_FLAG="--machinery-verified"
MACHINERY_VERIFIED="${MACHINERY_VERIFIED:-0}"
UNIT_SUITE="skills/exobrain-tests/unit/run.sh"
# CONTEXT_HEADING opens the --context section of the PR body; FINDINGS_HEADING opens
# the review an unattended land posts, which is how findings-pending.sh finds it.
CONTEXT_HEADING="## Source context (from the session that made this change)"
FINDINGS_HEADING="## Authoring review (unattended land, not blocking)"
LOCK_STALE_MINUTES=30
LOCK_WAIT_SECONDS=600

log()  { echo "persist: $*"; }
warn() { echo "persist: $*" >&2; }
die()  { echo "persist: $1" >&2; exit "${2:-1}"; }

usage() { grep '^#' "$0" | sed -n '2,63p' | sed 's/^# \{0,1\}//'; }

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

DRY_RUN=0; PR_TITLE=""; UNATTENDED=0; REVIEW_NOTE=""; CONTEXT_FILE=""; CONTEXT_NOTE=""; VERIFY_NOTE=""
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

# ---------------------------------------------------------------------------
# Verification gate
# ---------------------------------------------------------------------------

# Agent specs at any scope, verified by a behavioral run: every AGENTS.md, Claude or
# Codex sidecar, and SKILL.md.
SPEC_RE='(^|/)((AGENTS|CLAUDE|CODEX)(\.[^/]*)?|SKILL)\.md$'
# The rest of the machinery that shapes agents, verified on the author's word: root
# scripts, root skills' code, the registries, and OpenClaw sidecars at any scope (no
# behavioral harness runs OpenClaw).
MACHINERY_RE='^(scripts/|skills/|skills\.json$|scopes\.json$|skills\.schema\.json$)|(^|/)OPENCLAW(\.[^/]*)?\.md$'

# changed_paths <worktree> <base> — paths changed on the branch, committed or not.
changed_paths() {
    {
        git -C "$1" diff --name-only "$2"...HEAD 2>/dev/null
        git -C "$1" status --porcelain --untracked-files=all | cut -c4- | sed 's/^.* -> //'
    } | sort -u
}

spec_paths()      { changed_paths "$1" "$2" | grep -E "$SPEC_RE" || true; }
machinery_paths() { changed_paths "$1" "$2" | grep -E "$MACHINERY_RE" | grep -vE "$SPEC_RE" || true; }

# worktree_tree <worktree> — the tree the worktree's current state commits as,
# uncommitted changes included, built in a copy of its index so the real staging
# area is never touched.
worktree_tree() {
    local idx src tree rc
    idx="$(mktemp)"
    src="$(git -C "$1" rev-parse --git-path index)"; [[ "$src" = /* ]] || src="$1/$src"
    cp "$src" "$idx" 2>/dev/null || rm -f "$idx"
    tree="$(GIT_INDEX_FILE="$idx" git -C "$1" add -A 2>/dev/null && GIT_INDEX_FILE="$idx" git -C "$1" write-tree 2>/dev/null)"
    rc=$?
    rm -f "$idx"
    (( rc == 0 )) && [[ -n "$tree" ]] && echo "$tree"
}

# qualifying_runs <worktree> <tree> — the behavioral runs under the worktree's
# tmp/test-runs that verify <tree>'s specs, one "<run dir>|<agents>|<scopes>" line each
# (comma-separated lists). A run qualifies when every case it ran met its threshold with
# no harness error, at least one passing case drove an agent and is not the smoke check,
# and no spec differs between the tree it tested and <tree>.
qualifying_runs() {
    local wt="$1" tree="$2" s tested diff
    command -v jq >/dev/null || return 0
    for s in "$wt"/tmp/test-runs/*/summary.json; do
        [[ -f "$s" ]] || continue
        tested="$(jq -r 'select(.all_met == true and .harness_error == false
                    and any(.cases[]; .verdict == "PASS" and .profile != "static" and (.name | endswith("/smoke") | not)))
                  | .tree // empty' "$s" 2>/dev/null)"
        [[ -n "$tested" ]] || continue
        diff="$(git -C "$wt" diff --name-only "$tested" "$tree" 2>/dev/null)" || continue
        grep -qE "$SPEC_RE" <<< "$diff" && continue
        printf '%s|%s|%s\n' "$(dirname "$s")" "$(jq -r '.agents | join(",")' "$s")" "$(jq -r '.scopes | join(",")' "$s")"
    done
}

# spec_scope <spec> — the scope a spec loads from: a SKILL.md's is the directory
# holding its skills/, any other spec's is its own directory; "" is the global scope.
spec_scope() {
    case "$1" in
        */skills/*/SKILL.md) echo "${1%%/skills/*}" ;;
        skills/*/SKILL.md)   echo "" ;;
        */*)                 echo "${1%/*}" ;;
        *)                   echo "" ;;
    esac
}

# spec_agent <spec> — the one agent that loads a sidecar; empty for a spec every agent loads.
spec_agent() {
    case "${1##*/}" in
        CLAUDE.md|CLAUDE.*.md) echo claude ;;
        CODEX.md|CODEX.*.md)   echo codex ;;
    esac
}

# spec_gaps <worktree> <base> — the changed specs no qualifying run covers, one per
# line with what a covering run needs. A run covers a spec when it wired the spec's
# scope (every run loads the global scope) and, for a sidecar, ran the sidecar's agent.
spec_gaps() {
    local wt="$1" base="$2" specs tree runs="" p scope need covered dir agents scopes leaf
    specs="$(spec_paths "$wt" "$base")"
    [[ -n "$specs" ]] || return 0
    tree="$(worktree_tree "$wt")"
    [[ -n "$tree" ]] && runs="$(qualifying_runs "$wt" "$tree")"
    while IFS= read -r p; do
        [[ -n "$p" ]] || continue
        scope="$(spec_scope "$p")"; need="$(spec_agent "$p")"; covered=0
        while IFS='|' read -r dir agents scopes; do
            [[ -n "$dir" ]] || continue
            [[ -z "$need" || ",$agents," == *",$need,"* ]] || continue
            if [[ -z "$scope" ]]; then covered=1; break; fi
            for leaf in ${scopes//,/ }; do
                if [[ "$leaf" == "$scope" || "$leaf" == "$scope/"* ]]; then covered=1; break 2; fi
            done
        done <<< "$runs"
        (( covered )) || echo "$p — needs a passing run since its last edit${need:+ with $need}${scope:+, wired to $scope}"
    done <<< "$specs"
}

# verification_note <worktree> <tree> — the qualifying runs, one line each, for the PR body.
verification_note() {
    local dir
    while IFS='|' read -r dir _ _; do
        [[ -n "$dir" ]] || continue
        jq -r --arg run "${dir##*/}" '"- run \($run) (\(.agents | join(", "))\(if (.scopes | length) > 0 then "; scopes: " + (.scopes | join(", ")) else "" end)): " + ([.cases[] | "\(.name) \(.passes)/\(.total)"] | join(", "))' "$dir/summary.json"
    done < <(qualifying_runs "$1" "$2")
}

# gate_refusal <worktree> <base> — why the gate refuses this change, empty when it
# doesn't. Specs need covering runs; other machinery needs the author's flag
# (MACHINERY_VERIFIED).
gate_refusal() {
    local wt="$1" base="$2" gaps machinery=""
    gaps="$(spec_gaps "$wt" "$base")"
    [[ "${MACHINERY_VERIFIED:-0}" == "1" ]] || machinery="$(machinery_paths "$wt" "$base")"
    if [[ -n "$gaps" ]]; then
        echo "persist: this change edits agent specs, which land only with a passing behavioral run that covers them (exobrain-persist skill, step 3):"
        echo "$gaps" | sed 's/^/    /'
        echo "persist: from this worktree run skills/exobrain-tests/behavior/run.sh --working-tree --cases <the cases this change could move> [--scope <scope>], then re-run persist. A run counts once every case it ran met its threshold, one of them agent-driven and not the smoke check."
    fi
    if [[ -n "$machinery" ]]; then
        echo "persist: this change touches shared machinery, which must be verified before it lands (exobrain-persist skill, step 3):"
        echo "$machinery" | sed 's/^/    /'
        echo "persist: this script runs the unit suite ($UNIT_SUITE) itself; run the behavior suite (and exobrain-ab where the change alters behavior), then re-run with $MACHINERY_FLAG to assert that it happened"
    fi
}

# refuse_at_gate <worktree> <base> — exit 3 with the gate's refusal when it has one.
refuse_at_gate() {
    local refusal; refusal="$(gate_refusal "$1" "$2")"
    [[ -z "$refusal" ]] || { echo "$refusal" >&2; exit 3; }
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

# post_findings_review <worktree> <number> — post REVIEW_NOTE's findings as a
# comment review on PR <number>, unless an earlier run of this land already did.
post_findings_review() {
    local posted findings
    posted="$(cd "$1" && gh pr view "$2" --json reviews --jq '.reviews[].body' 2>/dev/null)" || posted=""
    [[ "$posted" == *"$FINDINGS_HEADING"* ]] && return 0
    findings="$(sed -n '/flagged/,/^For a deeper/p' <<< "$REVIEW_NOTE" | sed -e '1d' -e '$d' | cat -s)"
    log "posting the authoring findings as a review on PR $2"
    (cd "$1" && gh pr review "$2" --comment --body "$FINDINGS_HEADING"$'\n\n'"$findings") \
        || die "posting the authoring review on PR $2 failed"
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

    if [[ -n "$CONTEXT_FILE" ]]; then
        local cpath="$CONTEXT_FILE"; [[ "$cpath" = /* ]] || cpath="$wt/$cpath"
        if [[ -s "$cpath" ]]; then CONTEXT_NOTE="$(cat "$cpath")"
        else warn "context file is empty or missing: $cpath"; fi
    fi

    log "landing $branch from $wt onto $default"
    take_lock "$main"
    # The claim carries the machinery assertion, so a run that dies after
    # asserting it is swept without the flag being repeated.
    if [[ -f "$marker" ]] && grep -qx 'machinery-verified' "$marker" 2>/dev/null; then MACHINERY_VERIFIED=1; fi
    if (( ! DRY_RUN )); then
        if [[ "$MACHINERY_VERIFIED" == "1" ]]; then echo machinery-verified > "$marker"; else touch "$marker"; fi
    fi

    # Refresh the base so "ahead of" and the gate's diff mean current trunk.
    if has_remote "$main"; then
        git -C "$main" fetch --quiet origin "$default" 2>/dev/null || warn "fetch failed; measuring against the last known $base"
    fi

    # ---- verification gate -------------------------------------------------
    local refusal machinery
    refusal="$(gate_refusal "$wt" "$base")"
    if [[ -n "$refusal" ]]; then
        rm -f "$marker"
        echo "$refusal" >&2
        exit 3
    fi
    [[ -z "$(spec_paths "$wt" "$base")" ]] || VERIFY_NOTE="$(verification_note "$wt" "$(worktree_tree "$wt")")"
    machinery="$(machinery_paths "$wt" "$base")"
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
        if [[ "$ahead" != "0" ]] && [[ -z "$message" || "$message" == "$(git -C "$wt" log -1 --format=%s)" ]] && ! git -C "$wt" merge-base --is-ancestor HEAD "refs/remotes/origin/$branch" 2>/dev/null; then
            # Only timeline rows on top of an unpushed commit (one --detach just
            # made with this message, say): fold them in.
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
    if [[ -x "$wt/scripts/authoring-review.sh" ]] && (( ! DRY_RUN )); then
        log "authoring-review.sh"
        local review_out review_rc=0
        review_out="$(cd "$wt" && scripts/authoring-review.sh 2>&1)" || review_rc=$?
        [[ -z "$review_out" ]] || echo "$review_out"
        if (( review_rc != 0 )); then
            if (( review_rc == 1 && UNATTENDED )); then
                log "unattended land: the findings go into a review on the PR instead of blocking"
                REVIEW_NOTE="$review_out"
            else
                die "authoring review flagged violations — fix, amend, then re-run"
            fi
        fi
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
            if [[ -n "$VERIFY_NOTE" ]]; then
                body="$body"$'\n\n'"## Behavioral verification"$'\n\n'"$VERIFY_NOTE"
            fi
            if [[ -n "$CONTEXT_NOTE" ]]; then
                body="$body"$'\n\n'"$CONTEXT_HEADING"$'\n\n'"$CONTEXT_NOTE"
            fi
            log "opening PR: $title"
            if (( DRY_RUN )); then :; else
                (cd "$wt" && gh pr create --base "$default" --head "$branch" --title "$title" --body "$body") || die "gh pr create failed"
            fi
            pr="$(pr_state "$wt" "$branch")"; number="${pr%% *}"; state="${pr#* }"
        fi
        if (( ! DRY_RUN )); then
            [[ -n "$number" ]] || die "no PR found for $branch after creating one"
            [[ -z "$REVIEW_NOTE" ]] || post_findings_review "$wt" "$number"
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

# commit_age_days <worktree> — days since the branch's last commit.
commit_age_days() {
    local t; t="$(git -C "$1" log -1 --format=%ct 2>/dev/null || echo 0)"
    (( t > 0 )) || { echo 0; return; }
    echo $(( ( $(date +%s) - t ) / 86400 ))
}

# dirty_age_days <worktree> — days since the newest uncommitted file changed.
dirty_age_days() {
    local wt="$1" f newest=0 m
    while IFS= read -r f; do
        [[ -n "$f" && -e "$wt/$f" ]] || continue
        m="$(stat -f %m "$wt/$f" 2>/dev/null || stat -c %Y "$wt/$f" 2>/dev/null || echo 0)"
        (( m > newest )) && newest=$m
    done < <(git -C "$wt" status --porcelain --untracked-files=all | cut -c4- | sed 's/^.* -> //')
    (( newest > 0 )) || { echo 0; return; }
    echo $(( ( $(date +%s) - newest ) / 86400 ))
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
    local main default base quiet="${PERSIST_QUIET_MINUTES:-60}" stale_days="${PERSIST_STALE_DAYS:-2}"
    main="$(main_root "$SCRIPT_DIR")" || die "$SCRIPT_DIR is not inside a git repo"
    default="$(default_branch "$main")" || die "cannot resolve the default branch"
    has_remote "$main" && git -C "$main" fetch --quiet origin "$default" 2>/dev/null
    base="$(base_ref "$main" "$default")"
    # Vouching for machinery is an author's act, never the sweep's: only a claim
    # that carried the flag counts (see land).
    MACHINERY_VERIFIED=0

    local failed=0 landed=0 skipped=0 stale=0 waiting=0 path branch gitdir reason age claimed
    while IFS='|' read -r path branch; do
        [[ -n "$path" && "$path" != "$main" ]] || continue
        [[ -d "$path" ]] || { warn "worktree missing on disk: $path (git worktree prune)"; continue; }
        [[ -n "$branch" && "$branch" != "$default" ]] || continue
        gitdir="$(git -C "$path" rev-parse --git-dir)"; [[ "$gitdir" = /* ]] || gitdir="$path/$gitdir"
        reason=""
        if [[ -f "$gitdir/persist-requested" ]]; then
            reason="claimed by an earlier persist"
        elif [[ -n "$(git -C "$path" status --porcelain --untracked-files=all)" ]]; then
            age="$(dirty_age_days "$path")"
            if (( age >= stale_days )); then
                warn "stale: $branch has uncommitted changes untouched for ${age}d ($path) — commit and land them, or remove the worktree"
                stale=$((stale + 1))
            else
                log "skip $branch: uncommitted changes (someone may be working there)"; skipped=$((skipped + 1))
            fi
            continue
        elif [[ "$(git -C "$path" rev-list --count "$base"..HEAD 2>/dev/null || echo 0)" == "0" ]]; then
            continue
        elif (( ( $(date +%s) - $(git -C "$path" log -1 --format=%ct) ) / 60 < quiet )); then
            log "skip $branch: committed less than ${quiet}m ago"; skipped=$((skipped + 1)); continue
        else
            reason="clean, ahead of $default, quiet for ${quiet}m"
        fi
        # A diff the verification gate refuses needs verification the sweep can't
        # do (see the gate in land); a claim that carried the flag vouches for
        # machinery. Without that the worktree waits — not a sweep failure until it
        # has waited long enough to be rotting.
        claimed=0; grep -qx 'machinery-verified' "$gitdir/persist-requested" 2>/dev/null && claimed=1
        if [[ -n "$(MACHINERY_VERIFIED=$claimed gate_refusal "$path" "$base")" ]]; then
            age="$(commit_age_days "$path")"
            if (( age >= stale_days )); then
                warn "stale: $branch has waited ${age}d for the behavioral verification its diff needs ($path) — verify and land it, or remove the worktree"
                stale=$((stale + 1))
            else
                log "skip $branch: touches shared machinery or agent specs — needs an agent's behavioral verification"
                waiting=$((waiting + 1))
            fi
            continue
        fi
        log "── $branch ($reason)"
        if (land "$path"); then landed=$((landed + 1)); else failed=$((failed + 1)); fi
    done < <(git -C "$main" worktree list --porcelain | awk '
        /^worktree /{p=substr($0,10)} /^branch /{b=substr($0,8); sub("refs/heads/","",b)} /^$/{if(p){print p"|"b}; p="";b=""}
        END{if(p)print p"|"b}')
    log "sweep: $landed landed, $skipped skipped, $waiting awaiting verification, $stale stale, $failed failed"
    (( failed == 0 && stale == 0 ))
}

# ---------------------------------------------------------------------------

# detach <worktree> <log> <args…> — re-run this script in a new session with stdio
# on the log, so the exec that started it can return and its caller end.
detach() {
    local wt="$1" logf="$2"; shift 2
    mkdir -p "$(dirname "$logf")"
    python3 - "$wt" "$logf" "$SCRIPT_DIR/persist.sh" "$@" <<'PYEOF'
import os, subprocess, sys
wt, logf, script, *args = sys.argv[1:]
with open(logf, "ab") as log:
    subprocess.Popen([script, *args], cwd=wt, stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                     start_new_session=True, env={**os.environ, "PERSIST_DETACHED": "1"})
PYEOF
}

main() {
    local mode=land message="" tl_summary="" author="" do_detach=0 a
    # Everything but --detach is handed on to the detached run verbatim.
    local -a passthrough=()
    for a in "$@"; do
        if [[ "$a" == --detach ]]; then do_detach=1; else passthrough+=("$a"); fi
    done
    set -- ${passthrough[@]+"${passthrough[@]}"}
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--message|--timeline|--author|--title|--context)
                [[ $# -ge 2 ]] || die "$1 needs a value" 2 ;;
        esac
        case "$1" in
            -m|--message)   message="$2"; shift 2 ;;
            --timeline)     tl_summary="$2"; shift 2 ;;
            --author)       author="$2"; shift 2 ;;
            --title)        PR_TITLE="$2"; shift 2 ;;
            --context)      CONTEXT_FILE="$2"; shift 2 ;;
            --sweep)        mode=sweep; shift ;;
            --dry-run)      DRY_RUN=1; shift ;;
            "$MACHINERY_FLAG") MACHINERY_VERIFIED=1; shift ;;
            -h|--help)      usage; exit 0 ;;
            *)              echo "persist: unknown argument: $1" >&2; usage >&2; exit 2 ;;
        esac
    done
    command -v git >/dev/null || die "git not found"
    [[ "${PERSIST_DETACHED:-}" == "1" || "$mode" == sweep ]] && UNATTENDED=1
    if (( do_detach )) && [[ "$mode" == land && "${PERSIST_DETACHED:-}" != "1" ]] && (( ! DRY_RUN )); then
        local wt main branch default logf
        command -v python3 >/dev/null || die "--detach needs python3"
        wt="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not a git checkout"
        main="$(main_root "$wt")" || die "cannot resolve the main checkout"
        branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
        default="$(default_branch "$main")" || die "cannot resolve the default branch"
        [[ "$branch" != "$default" && "$wt" != "$main" ]] || die "$wt is on the default branch or is the main checkout — persist runs from a worktree on its own branch"
        # Commit here so the caller can confirm the change is durable before returning.
        if [[ -n "$(git -C "$wt" status --porcelain --untracked-files=all)" ]]; then
            [[ -n "$message" ]] || die "uncommitted changes and no commit yet — pass -m <message>" 2
            git -C "$wt" add -A && git -C "$wt" commit --quiet -m "$message" || die "commit failed"
            log "committed on $branch"
        fi
        # Refuse at the gate here, where the caller still sees it.
        refuse_at_gate "$wt" "$(base_ref "$main" "$default")"
        logf="$main/.git/persist-logs/$branch.log"
        detach "$wt" "$logf" ${passthrough[@]+"${passthrough[@]}"}
        log "land of $branch started in the background (log: $logf); a failure is retried by the sweep"
        exit 0
    fi
    case "$mode" in
        land)  land "$PWD" "$message" "$tl_summary" "$author" ;;
        sweep) sweep ;;
    esac
}

main "$@"
