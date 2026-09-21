#!/usr/bin/env bash
# test-persist.sh — tests for persist.sh: the one-command land from a worktree
# onto the default branch, and its --sweep over pending worktrees. Exercises the
# framework script in <repo>/scripts/ of whichever instance this suite is
# installed in.
#
#   skills/exobrain-tests/unit/test-persist.sh            # run all
#   skills/exobrain-tests/unit/test-persist.sh <pattern>  # filter by name
#
# Each test builds a bare "origin", a main checkout cloned from it, and worktrees
# off that, all in a temp dir; the gates (validate-exobrain.sh,
# authoring-review.sh, the unit suite) are stubs that record being called, and
# `gh` is a fake on PATH that keeps PR state in a file and squash-merges into the
# bare origin the way the forge would. No network, no credentials, nothing
# touches the real repo.

set -uo pipefail

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0; FAILURES=()
FILTER="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"          # .../exobrain-tests/unit
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"        # repo root: unit→exobrain-tests→skills→root
SCRIPTS_DIR="$REPO_DIR/scripts"                       # framework scripts under test

RED='\033[0;31m'; GREEN='\033[0;32m'; DIM='\033[0;90m'; RESET='\033[0m'

run_test() {
    local name="$1"; shift
    [[ -n "$FILTER" && "$name" != *"$FILTER"* ]] && return 0
    TESTS_RUN=$((TESTS_RUN + 1))
    printf "${DIM}%-52s${RESET} " "$name"
    TEST_DIR="$(mktemp -d)"
    trap 'rm -rf "$TEST_DIR"' RETURN
    local output
    if output=$("$@" 2>&1); then
        TESTS_PASSED=$((TESTS_PASSED + 1)); printf "${GREEN}PASS${RESET}\n"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1)); FAILURES+=("$name"); printf "${RED}FAIL${RESET}\n"
        echo "$output" | sed 's/^/    /'
    fi
}

assert_eq()           { [[ "$1" == "$2" ]] || { echo "ASSERT_EQ${3:+ ($3)}: expected '$1', got '$2'"; return 1; }; }
assert_contains()     { [[ "$1" == *"$2"* ]] || { echo "ASSERT_CONTAINS${3:+ ($3)}: '$2' not in:"; echo "$1"; return 1; }; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || { echo "ASSERT_NOT_CONTAINS${3:+ ($3)}: '$2' unexpectedly present"; return 1; }; }
assert_file()         { [[ -e "$1" ]] || { echo "ASSERT_FILE${2:+ ($2)}: $1 missing"; return 1; }; }
assert_no_file()      { [[ ! -e "$1" ]] || { echo "ASSERT_NO_FILE${2:+ ($2)}: $1 unexpectedly exists"; return 1; }; }

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

ORIGIN=""; MAIN=""; FAKE_BIN=""; REC=""

git_id() { git -C "$1" config user.email t@t.test; git -C "$1" config user.name tester; }

# setup_repo [--no-remote] — bare origin + main checkout on `main`, carrying the
# real persist.sh, stub gates (validator, authoring review, unit suite), a
# timeline-tracked domain and a plain one. Sets ORIGIN/MAIN.
setup_repo() {
    local no_remote=0; [[ "${1:-}" == "--no-remote" ]] && no_remote=1
    local seed="$TEST_DIR/seed"
    mkdir -p "$seed/scripts" "$seed/skills/exobrain-tests/unit" "$seed/knowledge/tracked" "$seed/knowledge/plain" "$seed/people/p"
    cp "$SCRIPTS_DIR/persist.sh" "$seed/scripts/"
    REC="$TEST_DIR/calls"; : > "$REC"
    cat > "$seed/scripts/validate-exobrain.sh" <<EOF
#!/usr/bin/env bash
echo validate >> "$REC"; exit "\${FAKE_VALIDATE_EXIT:-0}"
EOF
    cat > "$seed/scripts/authoring-review.sh" <<EOF
#!/usr/bin/env bash
[[ "\${EXOBRAIN_SKIP_AUTHORING_REVIEW:-}" == "1" ]] && exit 0
echo review >> "$REC"
if [[ "\${FAKE_REVIEW_EXIT:-0}" == "1" ]]; then
    echo "Authoring review flagged possible issues in the changed files:" >&2
    echo "  knowledge/plain/x.md — a session echo" >&2
    echo "For a deeper reader-lens pass, run the audit skill." >&2
fi
exit "\${FAKE_REVIEW_EXIT:-0}"
EOF
    cat > "$seed/skills/exobrain-tests/unit/run.sh" <<EOF
#!/usr/bin/env bash
echo unit >> "$REC"; exit "\${FAKE_UNIT_EXIT:-0}"
EOF
    chmod +x "$seed/scripts/"*.sh "$seed/skills/exobrain-tests/unit/run.sh"
    printf '# Exobrain\n' > "$seed/AGENTS.md"
    printf -- '---\nname: tracked\ntimeline: true\n---\n# Tracked\n' > "$seed/knowledge/tracked/README.md"
    printf -- '---\nname: plain\n---\n# Plain\n' > "$seed/knowledge/plain/README.md"
    printf '# p\n' > "$seed/people/p/AGENTS.md"
    printf '.exobrain.json\n' > "$seed/.gitignore"
    git -C "$seed" init -q -b main; git_id "$seed"
    git -C "$seed" add -A; git -C "$seed" commit -q -m "Seed"

    if (( no_remote )); then
        MAIN="$seed"; ORIGIN=""
    else
        ORIGIN="$TEST_DIR/origin.git"
        git clone -q --bare "$seed" "$ORIGIN"
        git -C "$ORIGIN" symbolic-ref HEAD refs/heads/main
        MAIN="$TEST_DIR/main"
        git clone -q "$ORIGIN" "$MAIN"; git_id "$MAIN"
    fi
    printf '{"person":"tester-person"}\n' > "$MAIN/.exobrain.json"
    setup_fake_gh
}

# setup_fake_gh — a `gh` on PATH: `pr list --head <b>` reports the PR from a state
# file, `pr create` records one, `pr merge --squash` squash-merges the branch into
# the bare origin's main (refusing on conflict, as the forge would).
setup_fake_gh() {
    FAKE_BIN="$TEST_DIR/bin"; mkdir -p "$FAKE_BIN"
    local state="$TEST_DIR/prs"; : > "$state"
    cat > "$FAKE_BIN/gh" <<EOF
#!/usr/bin/env bash
set -uo pipefail
STATE="$state"; ORIGIN="$ORIGIN"; SCRATCH="$TEST_DIR/gh-scratch"
echo "gh \$*" >> "$REC"
sub="\${1:-} \${2:-}"; shift 2 || true
case "\$sub" in
  "pr list")
    head=""; while [[ \$# -gt 0 ]]; do case "\$1" in --head) head="\$2"; shift 2;; *) shift;; esac; done
    awk -v b="\$head" '\$2==b {print \$1" "\$3}' "\$STATE" | tail -1 ;;
  "pr create")
    head=""; title=""; body=""
    while [[ \$# -gt 0 ]]; do case "\$1" in --head) head="\$2"; shift 2;; --title) title="\$2"; shift 2;; --body) body="\$2"; shift 2;; --base) shift 2;; *) shift;; esac; done
    git -C "\$ORIGIN" rev-parse --verify --quiet "refs/heads/\$head" >/dev/null || { echo "gh: branch \$head not on origin" >&2; exit 1; }
    n=\$(( \$(wc -l < "\$STATE") + 1 ))
    printf '%s %s OPEN %s\n' "\$n" "\$head" "\$title" >> "\$STATE"
    printf '%s\n' "\$body" > "$TEST_DIR/pr-body-\$n"
    echo "https://forge.test/pr/\$n" ;;
  "pr merge")
    n="\$1"; line="\$(awk -v n="\$n" '\$1==n' "\$STATE")"
    [[ -n "\$line" ]] || { echo "gh: no PR \$n" >&2; exit 1; }
    head="\$(echo "\$line" | awk '{print \$2}')"; title="\$(echo "\$line" | cut -d' ' -f4-)"
    rm -rf "\$SCRATCH"; git clone -q "\$ORIGIN" "\$SCRATCH"
    git -C "\$SCRATCH" config user.email gh@t.test; git -C "\$SCRATCH" config user.name gh
    git -C "\$SCRATCH" checkout -q main
    if ! git -C "\$SCRATCH" merge --squash "origin/\$head" >/dev/null 2>&1; then
        echo "X Pull request #\$n is not mergeable: the merge commit cannot be cleanly created." >&2; exit 1
    fi
    git -C "\$SCRATCH" commit -q -m "\$title (#\$n)" && git -C "\$SCRATCH" push -q origin main
    sed -i.bak "s/^\$n \$head OPEN/\$n \$head MERGED/" "\$STATE" ;;
  *) echo "fake gh: unsupported: \$sub \$*" >&2; exit 1 ;;
esac
EOF
    chmod +x "$FAKE_BIN/gh"
}

# add_worktree <branch> — a worktree off main, path printed.
add_worktree() {
    local path="$TEST_DIR/wt-$1"
    git -C "$MAIN" worktree add -q -b "$1" "$path" main
    git_id "$path"
    echo "$path"
}

# commit_in <worktree> <file> <content> <message>
commit_in() {
    mkdir -p "$(dirname "$1/$2")"; printf '%s\n' "$3" > "$1/$2"
    git -C "$1" add -A; git -C "$1" commit -q -m "$4"
}

# persist <worktree> [args…] — run persist.sh from inside the worktree with the fake gh.
persist() {
    local wt="$1"; shift
    (cd "$wt" && PATH="$FAKE_BIN:$PATH" scripts/persist.sh "$@")
}

# sweep [env…] — run --sweep from the main checkout with the fake gh.
sweep() { (cd "$MAIN" && PATH="$FAKE_BIN:$PATH" env "$@" scripts/persist.sh --sweep); }

# age_files <days> <path…> — backdate mtimes.
age_files() {
    local d="$1"; shift
    touch -t "$(date -v-"${d}"d +%Y%m%d%H%M 2>/dev/null || date -d "$d days ago" +%Y%m%d%H%M)" "$@"
}

# wait_for_log <file> <text> — a detached land finishes on its own time.
wait_for_log() {
    local i
    for i in $(seq 1 100); do
        grep -q "$2" "$1" 2>/dev/null && return 0
        python3 -c 'import time; time.sleep(0.1)'
    done
    echo "timed out waiting for '$2' in $1:"; cat "$1" 2>/dev/null; return 1
}

origin_log()  { git -C "$ORIGIN" log --format=%s main; }
main_log()    { git -C "$MAIN" log --format=%s main; }
origin_has_branch() { git -C "$ORIGIN" rev-parse --verify --quiet "refs/heads/$1" >/dev/null; }
claim_of() { echo "$MAIN/.git/worktrees/wt-$1/persist-requested"; }

# ---------------------------------------------------------------------------
# Tests — landing one worktree
# ---------------------------------------------------------------------------

test_lands_committed_branch() {
    setup_repo
    local wt; wt="$(add_worktree feat-a)"
    commit_in "$wt" knowledge/plain/note.md "a fact" "Record a plain fact"
    local out; out="$(persist "$wt")" || { echo "$out"; return 1; }
    assert_contains "$out" "landed feat-a as PR 1" || return 1
    assert_eq "Record a plain fact (#1)" "$(origin_log | head -1)" "origin main" || return 1
    assert_eq "$(origin_log | head -1)" "$(main_log | head -1)" "main pulled" || return 1
    assert_no_file "$wt" "worktree removed" || return 1
    git -C "$MAIN" rev-parse --verify --quiet refs/heads/feat-a >/dev/null && { echo "local branch survived"; return 1; }
    origin_has_branch feat-a && { echo "remote branch survived"; return 1; }
    assert_contains "$(cat "$REC")" "validate" "validator ran" || return 1
    assert_contains "$(cat "$REC")" "review" "authoring review ran" || return 1
    assert_not_contains "$(cat "$REC")" "unit" "no machinery, no unit suite" || return 1
    assert_no_file "$MAIN/.git/exobrain-persist.lock" "lock released"
}

test_commits_dirty_work_with_message() {
    setup_repo
    local wt; wt="$(add_worktree feat-b)"
    printf 'x\n' > "$wt/knowledge/plain/x.md"
    persist "$wt" -m "Add x to plain" >/dev/null || return 1
    assert_eq "Add x to plain (#1)" "$(origin_log | head -1)"
}

test_dirty_work_without_message_is_usage_error() {
    setup_repo
    local wt; wt="$(add_worktree feat-c)"
    printf 'x\n' > "$wt/knowledge/plain/x.md"
    local out; out="$(persist "$wt" 2>&1)"; local rc=$?
    assert_eq 2 "$rc" "exit code" || return 1
    assert_contains "$out" "pass -m" || return 1
    origin_has_branch feat-c && { echo "pushed despite usage error"; return 1; }
    assert_file "$wt" "worktree kept"
}

test_refuses_default_branch_and_main_checkout() {
    setup_repo
    printf 'x\n' > "$MAIN/knowledge/plain/x.md"
    local out; out="$(cd "$MAIN" && PATH="$FAKE_BIN:$PATH" scripts/persist.sh -m "Oops" 2>&1)"; local rc=$?
    assert_eq 1 "$rc" "exit code" || return 1
    assert_contains "$out" "default branch" || return 1
    assert_eq "Seed" "$(origin_log | head -1)" "origin untouched"
}

test_nothing_to_land_is_a_noop() {
    setup_repo
    local wt; wt="$(add_worktree feat-d)"
    local out; out="$(persist "$wt")" || return 1
    assert_contains "$out" "nothing to land" || return 1
    assert_file "$wt" "worktree kept" || return 1
    assert_not_contains "$(cat "$REC")" "gh" "no forge calls"
}

test_machinery_gate_blocks_until_verified() {
    setup_repo
    local wt; wt="$(add_worktree feat-e)"
    commit_in "$wt" scripts/new-tool.sh "#!/bin/sh" "Add a tool"
    local out; out="$(persist "$wt" 2>&1)"; local rc=$?
    assert_eq 3 "$rc" "exit code" || return 1
    assert_contains "$out" "scripts/new-tool.sh" || return 1
    assert_contains "$out" "--machinery-verified" "failure message names the flag" || return 1
    assert_contains "$out" "step 3" "points at the skill step" || return 1
    assert_contains "$out" "runs the unit suite" "says the script runs the unit suite itself" || return 1
    assert_not_contains "$(cat "$REC")" "unit" "refusal is cheap: no unit suite before the flag" || return 1
    origin_has_branch feat-e && { echo "pushed despite gate"; return 1; }
    assert_no_file "$(claim_of feat-e)" "not claimed for the sweep" || return 1
    persist "$wt" --machinery-verified >/dev/null || return 1
    assert_eq 1 "$(grep -c '^unit$' "$REC")" "unit suite ran once with the flag" || return 1
    assert_eq "Add a tool (#1)" "$(origin_log | head -1)"
}

test_machinery_unit_suite_failure_stops_before_push() {
    setup_repo
    local wt; wt="$(add_worktree feat-e2)"
    commit_in "$wt" skills/s/SKILL.md "# s" "Add a shared skill"
    local out; out="$(FAKE_UNIT_EXIT=1 persist "$wt" --machinery-verified 2>&1)"; local rc=$?
    assert_eq 1 "$rc" "exit code" || return 1
    assert_contains "$out" "unit suite failed" || return 1
    origin_has_branch feat-e2 && { echo "pushed despite unit failure"; return 1; }
    assert_not_contains "$(cat "$REC")" "validate" "validator not reached" || return 1
    assert_file "$wt" "worktree kept"
}

test_person_scope_is_not_machinery() {
    setup_repo
    local wt; wt="$(add_worktree feat-f)"
    commit_in "$wt" people/p/skills/s/SKILL.md "# s" "Add a person skill"
    persist "$wt" >/dev/null || return 1
    assert_not_contains "$(cat "$REC")" "unit" "no unit suite for a person-scope change" || return 1
    assert_eq "Add a person skill (#1)" "$(origin_log | head -1)"
}

test_timeline_row_for_tracked_domain_only() {
    setup_repo
    local wt; wt="$(add_worktree feat-g)"
    commit_in "$wt" knowledge/tracked/fact.md "f" "Record a tracked fact"
    commit_in "$wt" knowledge/plain/fact.md "f" "Record a plain fact"
    persist "$wt" --timeline "Two facts recorded" >/dev/null || return 1
    git -C "$MAIN" pull -q --ff-only
    local tl="$MAIN/knowledge/tracked/TIMELINE.md"
    assert_file "$tl" || return 1
    assert_contains "$(cat "$tl")" "| Date | Author | Summary |" "header" || return 1
    assert_contains "$(cat "$tl")" "| $(date +%F) | tester-person | Two facts recorded |" "row" || return 1
    assert_eq 1 "$(grep -c "Two facts recorded" "$tl")" "one row" || return 1
    assert_no_file "$MAIN/knowledge/plain/TIMELINE.md" "plain domain has no timeline"
}

test_timeline_summary_defaults_to_commit_subject() {
    setup_repo
    local wt; wt="$(add_worktree feat-h)"
    printf 'f\n' > "$wt/knowledge/tracked/fact.md"
    EXOBRAIN_AUTHOR=alex persist "$wt" -m "Record via message" >/dev/null || return 1
    git -C "$MAIN" pull -q --ff-only
    assert_contains "$(cat "$MAIN/knowledge/tracked/TIMELINE.md")" "| alex | Record via message |"
}

test_review_failure_stops_before_push() {
    setup_repo
    local wt; wt="$(add_worktree feat-i)"
    commit_in "$wt" knowledge/plain/x.md "x" "Change x"
    local out; out="$(FAKE_REVIEW_EXIT=1 persist "$wt" 2>&1)"; local rc=$?
    assert_eq 1 "$rc" "exit code" || return 1
    assert_contains "$out" "authoring review" || return 1
    origin_has_branch feat-i && { echo "pushed despite review failure"; return 1; }
    assert_eq "Change x" "$(git -C "$wt" log -1 --format=%s)" "commit kept locally"
}

test_validation_failure_stops_before_push() {
    setup_repo
    local wt; wt="$(add_worktree feat-j)"
    commit_in "$wt" knowledge/plain/x.md "x" "Change x"
    FAKE_VALIDATE_EXIT=1 persist "$wt" >/dev/null 2>&1 && { echo "expected failure"; return 1; }
    origin_has_branch feat-j && { echo "pushed despite validation failure"; return 1; }
    assert_not_contains "$(cat "$REC")" "review" "review not reached"
}

test_resumes_after_pr_merged_but_main_not_updated() {
    setup_repo
    local wt; wt="$(add_worktree feat-k)"
    commit_in "$wt" knowledge/plain/x.md "x" "Change x"
    # Simulate a run killed after the merge: branch pushed, PR merged on the forge.
    git -C "$wt" push -q -u origin feat-k
    (cd "$wt" && PATH="$FAKE_BIN:$PATH" gh pr create --base main --head feat-k --title "Change x" --body "" >/dev/null)
    (cd "$wt" && PATH="$FAKE_BIN:$PATH" gh pr merge 1 --squash)
    assert_eq "Seed" "$(main_log | head -1)" "main behind" || return 1
    local out; out="$(persist "$wt")" || { echo "$out"; return 1; }
    assert_contains "$out" "already merged" || return 1
    assert_eq "Change x (#1)" "$(main_log | head -1)" "main updated" || return 1
    assert_no_file "$wt" "worktree removed" || return 1
    origin_has_branch feat-k && { echo "remote branch survived"; return 1; }
    return 0
}

test_pr_title_is_the_first_commit_unless_given() {
    setup_repo
    local wt; wt="$(add_worktree feat-t)"
    commit_in "$wt" knowledge/plain/x.md "x" "Add the feature"
    commit_in "$wt" knowledge/plain/y.md "y" "Fix a typo in it"
    persist "$wt" >/dev/null || return 1
    assert_eq "Add the feature (#1)" "$(origin_log | head -1)" "first subject titles the PR" || return 1
    wt="$(add_worktree feat-u)"
    commit_in "$wt" knowledge/plain/z.md "z" "Draft"
    persist "$wt" --title "The real title" >/dev/null || return 1
    assert_eq "The real title (#2)" "$(origin_log | head -1)" "--title wins"
}

test_resumes_after_push_without_pr() {
    setup_repo
    local wt; wt="$(add_worktree feat-l)"
    commit_in "$wt" knowledge/plain/x.md "x" "Change x"
    git -C "$wt" push -q -u origin feat-l
    persist "$wt" >/dev/null || return 1
    assert_eq "Change x (#1)" "$(origin_log | head -1)" || return 1
    assert_eq 1 "$(grep -c "gh pr create" "$REC")" "one PR created"
}

test_non_conflicting_divergence_lands() {
    setup_repo
    local wt; wt="$(add_worktree feat-m)"
    commit_in "$wt" knowledge/plain/x.md "x" "Change x"
    # The default branch moves on elsewhere while the branch waits.
    commit_in "$MAIN" knowledge/plain/y.md "y" "Change y"; git -C "$MAIN" push -q origin main
    persist "$wt" >/dev/null || return 1
    assert_eq "Change x (#1)" "$(origin_log | head -1)" || return 1
    assert_file "$MAIN/knowledge/plain/x.md" || return 1
    assert_file "$MAIN/knowledge/plain/y.md"
}

test_conflict_fails_cleanly_and_keeps_the_branch() {
    setup_repo
    local wt; wt="$(add_worktree feat-n)"
    commit_in "$wt" knowledge/plain/same.md "branch version" "Change same"
    commit_in "$MAIN" knowledge/plain/same.md "main version" "Change same on main"; git -C "$MAIN" push -q origin main
    local out; out="$(persist "$wt" 2>&1)"; local rc=$?
    assert_eq 1 "$rc" "exit code" || return 1
    assert_contains "$out" "conflict with" || return 1
    assert_file "$wt" "worktree kept" || return 1
    assert_eq "" "$(git -C "$wt" status --porcelain)" "no merge left in progress" || return 1
    assert_eq "Change same on main" "$(origin_log | head -1)" "default branch untouched" || return 1
    assert_file "$(claim_of feat-n)" "still claimed for the sweep"
}

test_no_remote_fast_forwards_locally() {
    setup_repo --no-remote
    local wt; wt="$(add_worktree feat-o)"
    commit_in "$wt" knowledge/plain/x.md "x" "Change x"
    local out; out="$(persist "$wt")" || { echo "$out"; return 1; }
    assert_contains "$out" "(local)" || return 1
    assert_eq "Change x" "$(main_log | head -1)" || return 1
    assert_no_file "$wt" "worktree removed" || return 1
    assert_not_contains "$(cat "$REC")" "gh" "no forge calls"
}

test_dry_run_changes_nothing() {
    setup_repo
    local wt; wt="$(add_worktree feat-p)"
    commit_in "$wt" knowledge/tracked/x.md "x" "Change x"
    local out; out="$(persist "$wt" --dry-run)" || { echo "$out"; return 1; }
    assert_contains "$out" "would: git" || return 1
    assert_no_file "$wt/knowledge/tracked/TIMELINE.md" || return 1
    assert_file "$wt" "worktree kept" || return 1
    assert_no_file "$(claim_of feat-p)" "no claim in a dry run" || return 1
    origin_has_branch feat-p && { echo "pushed in dry run"; return 1; }
    assert_not_contains "$(cat "$REC")" "gh pr create" "no PR opened" || return 1
    assert_not_contains "$(cat "$REC")" "gh pr merge" "no merge"
}

test_option_without_its_value_is_a_usage_error() {
    setup_repo
    local wt; wt="$(add_worktree feat-v)"
    local out; out="$(persist "$wt" -m 2>&1)"; local rc=$?
    assert_eq 2 "$rc" "exit code" || return 1
    assert_contains "$out" "-m needs a value"
}

test_context_file_lands_in_the_pr_body() {
    setup_repo
    local wt; wt="$(add_worktree feat-w)"
    commit_in "$wt" knowledge/plain/x.md "x" "Change x"
    mkdir -p "$wt/tmp"; printf 'Asked for x; unsure about y.\n' > "$wt/tmp/handover.md"
    printf 'tmp/\n' >> "$wt/.git/info/exclude" 2>/dev/null || printf 'tmp/\n' >> "$MAIN/.git/info/exclude"
    persist "$wt" --context tmp/handover.md >/dev/null || return 1
    assert_contains "$(cat "$TEST_DIR/pr-body-1")" "## Source context" || return 1
    assert_contains "$(cat "$TEST_DIR/pr-body-1")" "unsure about y"
}

# ---------------------------------------------------------------------------
# Tests — detached lands
# ---------------------------------------------------------------------------

test_detach_commits_returns_and_lands_in_the_background() {
    setup_repo
    local wt; wt="$(add_worktree dt-a)"
    printf 'f\n' > "$wt/knowledge/tracked/fact.md"
    local out; out="$(persist "$wt" --detach -m "Record a fact")" || { echo "$out"; return 1; }
    assert_contains "$out" "committed on dt-a" || return 1
    assert_contains "$out" "started in the background" || return 1
    local logf="$MAIN/.git/persist-logs/dt-a.log"
    wait_for_log "$logf" "landed dt-a as PR 1" || return 1
    assert_eq "Record a fact (#1)" "$(origin_log | head -1)" || return 1
    # The timeline row folds into the commit --detach made, not a second one.
    assert_eq 1 "$(grep -c '^- ' "$TEST_DIR/pr-body-1")" "one commit on the branch"
}

test_detach_refuses_unverified_machinery_in_the_foreground() {
    setup_repo
    local wt; wt="$(add_worktree dt-b)"
    commit_in "$wt" scripts/tool.sh "#!/bin/sh" "Add a tool"
    local out; out="$(persist "$wt" --detach 2>&1)"; local rc=$?
    assert_eq 3 "$rc" "exit code" || return 1
    assert_contains "$out" "--machinery-verified" || return 1
    assert_no_file "$MAIN/.git/persist-logs/dt-b.log" "nothing was started"
}

test_detached_land_records_findings_in_the_pr_body() {
    setup_repo
    local wt; wt="$(add_worktree dt-c)"
    commit_in "$wt" knowledge/plain/x.md "x" "Change x"
    FAKE_REVIEW_EXIT=1 persist "$wt" --detach >/dev/null || return 1
    wait_for_log "$MAIN/.git/persist-logs/dt-c.log" "landed dt-c as PR 1" || return 1
    local body; body="$(cat "$TEST_DIR/pr-body-1")"
    assert_contains "$body" "## Authoring review (unattended land, not blocking)" || return 1
    assert_contains "$body" "a session echo" || return 1
    assert_not_contains "$body" "For a deeper" "the trailer is trimmed"
}

test_detached_land_still_blocks_on_the_proof_gate() {
    setup_repo
    local wt; wt="$(add_worktree dt-d)"
    commit_in "$wt" knowledge/plain/x.md "x" "Change x"
    FAKE_REVIEW_EXIT=2 persist "$wt" --detach >/dev/null || return 1
    wait_for_log "$MAIN/.git/persist-logs/dt-d.log" "authoring review flagged" || return 1
    origin_has_branch dt-d && { echo "pushed despite the proof gate"; return 1; }
    assert_file "$(claim_of dt-d)" "still claimed for the sweep"
}

# ---------------------------------------------------------------------------
# Tests — sweep
# ---------------------------------------------------------------------------

test_sweep_lands_claimed_and_quiet_skips_fresh_and_dirty() {
    setup_repo
    local claimed fresh dirty
    claimed="$(add_worktree sw-claimed)"; commit_in "$claimed" knowledge/plain/a.md a "Change a"
    touch "$(claim_of sw-claimed)"
    fresh="$(add_worktree sw-fresh)";     commit_in "$fresh" knowledge/plain/b.md b "Change b"
    dirty="$(add_worktree sw-dirty)";     commit_in "$dirty" knowledge/plain/c.md c "Change c"; printf 'wip\n' > "$dirty/knowledge/plain/wip.md"
    local out; out="$(sweep PERSIST_QUIET_MINUTES=60)" || { echo "$out"; return 1; }
    assert_contains "$out" "sweep: 1 landed, 2 skipped, 0 awaiting verification, 0 stale, 0 failed" || return 1
    assert_no_file "$claimed" "claimed worktree landed" || return 1
    assert_file "$fresh" "fresh worktree left alone" || return 1
    assert_file "$dirty" "dirty worktree left alone" || return 1
    assert_eq "Change a (#1)" "$(origin_log | head -1)" || return 1
    # With no quiet period the fresh one lands too; the dirty one never does.
    out="$(sweep PERSIST_QUIET_MINUTES=0)" || { echo "$out"; return 1; }
    assert_contains "$out" "sweep: 1 landed, 1 skipped, 0 awaiting verification, 0 stale, 0 failed" || return 1
    assert_no_file "$fresh" || return 1
    assert_file "$dirty"
}

test_sweep_honors_a_claim_that_asserted_machinery() {
    setup_repo
    local asserted bare
    asserted="$(add_worktree sw-asserted)"; commit_in "$asserted" scripts/tool.sh "#!/bin/sh" "Add a tool"
    echo machinery-verified > "$(claim_of sw-asserted)"
    bare="$(add_worktree sw-bare)";         commit_in "$bare" scripts/other.sh "#!/bin/sh" "Add another"
    local out; out="$(sweep PERSIST_QUIET_MINUTES=0 2>&1)" || { echo "$out"; return 1; }
    assert_contains "$out" "sweep: 1 landed, 0 skipped, 1 awaiting verification, 0 stale, 0 failed" || return 1
    assert_contains "$out" "skip sw-bare: touches shared machinery" || return 1
    assert_no_file "$asserted" "asserted claim landed" || return 1
    assert_eq 1 "$(grep -c '^unit$' "$REC")" "unit suite ran for the asserted land" || return 1
    assert_file "$bare" "unverified machinery left for an agent" || return 1
    assert_eq "Add a tool (#1)" "$(origin_log | head -1)"
}

test_sweep_fails_on_machinery_that_waited_too_long() {
    setup_repo
    local wt; wt="$(add_worktree sw-old)"
    mkdir -p "$wt/scripts"; printf '#!/bin/sh\n' > "$wt/scripts/old.sh"; git -C "$wt" add -A
    GIT_COMMITTER_DATE="2020-01-01T00:00:00" git -C "$wt" commit -q -m "Add an old tool"
    local out; out="$(sweep PERSIST_QUIET_MINUTES=0 2>&1)"; local rc=$?
    assert_eq 1 "$rc" "a stale worktree fails the sweep" || return 1
    assert_contains "$out" "stale: sw-old has waited" || return 1
    assert_contains "$out" "1 stale, 0 failed" || return 1
    assert_file "$wt" "worktree kept"
}

test_sweep_fails_on_a_stale_dirty_worktree() {
    setup_repo
    local wt; wt="$(add_worktree sw-rot)"
    printf 'wip\n' > "$wt/knowledge/plain/wip.md"; age_files 3 "$wt/knowledge/plain/wip.md"
    local out; out="$(sweep 2>&1)"; local rc=$?
    assert_eq 1 "$rc" "exit code" || return 1
    assert_contains "$out" "stale: sw-rot has uncommitted changes untouched for 3d" || return 1
    assert_contains "$out" "0 skipped, 0 awaiting verification, 1 stale, 0 failed" || return 1
    assert_file "$wt/knowledge/plain/wip.md" "never touched" || return 1
    # The threshold is configurable.
    out="$(sweep PERSIST_STALE_DAYS=7 2>&1)" || { echo "$out"; return 1; }
    assert_contains "$out" "1 skipped, 0 awaiting verification, 0 stale"
}

test_swept_land_records_findings_in_the_pr_body() {
    setup_repo
    local wt; wt="$(add_worktree sw-find)"; commit_in "$wt" knowledge/plain/x.md x "Change x"
    local out; out="$(sweep PERSIST_QUIET_MINUTES=0 FAKE_REVIEW_EXIT=1 2>&1)" || { echo "$out"; return 1; }
    assert_contains "$out" "findings go into the PR body" || return 1
    assert_contains "$(cat "$TEST_DIR/pr-body-1")" "a session echo"
}

test_sweep_reports_a_failed_land_and_continues() {
    setup_repo
    local bad good
    bad="$(add_worktree sw-bad)";   commit_in "$bad" knowledge/plain/same.md "branch" "Change same"
    good="$(add_worktree sw-good)"; commit_in "$good" knowledge/plain/ok.md ok "Change ok"
    commit_in "$MAIN" knowledge/plain/same.md "main" "Main same"; git -C "$MAIN" push -q origin main
    local out; out="$(sweep PERSIST_QUIET_MINUTES=0 2>&1)"; local rc=$?
    assert_eq 1 "$rc" "exit code" || return 1
    assert_contains "$out" "sweep: 1 landed, 0 skipped, 0 awaiting verification, 0 stale, 1 failed" || return 1
    assert_file "$bad" || return 1
    assert_no_file "$good"
}

test_stale_lock_is_taken_over() {
    setup_repo
    local wt; wt="$(add_worktree feat-q)"
    commit_in "$wt" knowledge/plain/x.md "x" "Change x"
    mkdir -p "$MAIN/.git/exobrain-persist.lock"
    touch -t "$(date -v-2H +%Y%m%d%H%M 2>/dev/null || date -d '2 hours ago' +%Y%m%d%H%M)" "$MAIN/.git/exobrain-persist.lock"
    local out; out="$(persist "$wt" 2>&1)" || { echo "$out"; return 1; }
    assert_contains "$out" "stale lock" || return 1
    assert_eq "Change x (#1)" "$(origin_log | head -1)"
}

# ---------------------------------------------------------------------------

run_test lands_committed_branch                      test_lands_committed_branch
run_test commits_dirty_work_with_message             test_commits_dirty_work_with_message
run_test dirty_work_without_message_is_usage_error   test_dirty_work_without_message_is_usage_error
run_test refuses_default_branch_and_main_checkout    test_refuses_default_branch_and_main_checkout
run_test nothing_to_land_is_a_noop                   test_nothing_to_land_is_a_noop
run_test machinery_gate_blocks_until_verified        test_machinery_gate_blocks_until_verified
run_test machinery_unit_suite_failure_stops_before_push test_machinery_unit_suite_failure_stops_before_push
run_test person_scope_is_not_machinery               test_person_scope_is_not_machinery
run_test timeline_row_for_tracked_domain_only        test_timeline_row_for_tracked_domain_only
run_test timeline_summary_defaults_to_commit_subject test_timeline_summary_defaults_to_commit_subject
run_test review_failure_stops_before_push            test_review_failure_stops_before_push
run_test validation_failure_stops_before_push        test_validation_failure_stops_before_push
run_test resumes_after_pr_merged_but_main_not_updated test_resumes_after_pr_merged_but_main_not_updated
run_test pr_title_is_the_first_commit_unless_given  test_pr_title_is_the_first_commit_unless_given
run_test resumes_after_push_without_pr               test_resumes_after_push_without_pr
run_test non_conflicting_divergence_lands            test_non_conflicting_divergence_lands
run_test conflict_fails_cleanly_and_keeps_the_branch test_conflict_fails_cleanly_and_keeps_the_branch
run_test no_remote_fast_forwards_locally             test_no_remote_fast_forwards_locally
run_test dry_run_changes_nothing                     test_dry_run_changes_nothing
run_test option_without_its_value_is_a_usage_error   test_option_without_its_value_is_a_usage_error
run_test context_file_lands_in_the_pr_body           test_context_file_lands_in_the_pr_body
run_test detach_commits_returns_and_lands_in_the_background test_detach_commits_returns_and_lands_in_the_background
run_test detach_refuses_unverified_machinery_in_the_foreground test_detach_refuses_unverified_machinery_in_the_foreground
run_test detached_land_records_findings_in_the_pr_body test_detached_land_records_findings_in_the_pr_body
run_test detached_land_still_blocks_on_the_proof_gate test_detached_land_still_blocks_on_the_proof_gate
run_test sweep_lands_claimed_and_quiet_skips_fresh_and_dirty test_sweep_lands_claimed_and_quiet_skips_fresh_and_dirty
run_test sweep_honors_a_claim_that_asserted_machinery test_sweep_honors_a_claim_that_asserted_machinery
run_test sweep_fails_on_machinery_that_waited_too_long test_sweep_fails_on_machinery_that_waited_too_long
run_test sweep_fails_on_a_stale_dirty_worktree       test_sweep_fails_on_a_stale_dirty_worktree
run_test swept_land_records_findings_in_the_pr_body  test_swept_land_records_findings_in_the_pr_body
run_test sweep_reports_a_failed_land_and_continues   test_sweep_reports_a_failed_land_and_continues
run_test stale_lock_is_taken_over                    test_stale_lock_is_taken_over

echo ""
if [[ $TESTS_FAILED -gt 0 ]]; then
    printf "${RED}%d/%d failed${RESET}: %s\n" "$TESTS_FAILED" "$TESTS_RUN" ${FAILURES[*]+"${FAILURES[*]}"}
    exit 1
fi
printf "${GREEN}%d/%d passed${RESET}\n" "$TESTS_PASSED" "$TESTS_RUN"
