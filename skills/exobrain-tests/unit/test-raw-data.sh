#!/usr/bin/env bash
# test-raw-data.sh — the raw-format gate in validate-exobrain.sh (AGENTS.md §
# Synthesized knowledge, not raw data): a photo, PDF, export, or similar newly
# added under knowledge/ or workspaces/ is blocked; files already tracked, text and
# chart formats, and paths outside those trees pass.
#
#   skills/exobrain-tests/unit/test-raw-data.sh            # run all
#   skills/exobrain-tests/unit/test-raw-data.sh <pattern>  # filter by name
#
# The gate looks only at files ADDED against the default branch, so each test
# builds a real git repo with a base commit and a default-branch ref to diff against.

set -uo pipefail

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0; FAILURES=()
FILTER="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPTS_DIR="$REPO_DIR/scripts"

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

assert_contains()     { [[ "$1" == *"$2"* ]] || { echo "ASSERT_CONTAINS${3:+ ($3)}: '$2' not in output"; echo "$1"; return 1; }; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || { echo "ASSERT_NOT_CONTAINS${3:+ ($3)}: '$2' present in output"; echo "$1"; return 1; }; }

# make_repo — a minimal exobrain with one tracked photo on the base commit and
# origin/main pointing at it, so "added against the default branch" has a base.
make_repo() {
    cd "$TEST_DIR" || return 1
    git init -q -b main .
    git config user.email t@example.com
    git config user.name t
    git config commit.gpgsign false
    mkdir -p scripts knowledge/health/_raw workspaces/2026/09/x
    cp "$SCRIPTS_DIR/validate-exobrain.sh" scripts/
    printf '# Exobrain\n' > AGENTS.md
    printf '{"scopes":[]}\n' > scopes.json
    printf '{"skills":[]}\n' > skills.json
    printf 'old photo bytes\n' > knowledge/health/_raw/old.jpg
    git add -A && git commit -qm base
    git update-ref refs/remotes/origin/main HEAD
}

commit_all() { git add -A && git commit -qm change; }
check() { bash scripts/validate-exobrain.sh 2>&1; }

test_added_photo_in_raw_is_blocked() {
    make_repo || return 1
    printf 'x\n' > knowledge/health/_raw/lab-result.JPG
    commit_all
    local out; out="$(check)" && { echo "should fail: $out"; return 1; }
    assert_contains "$out" "raw-format file added" || return 1
    assert_contains "$out" "knowledge/health/_raw/lab-result.JPG" "uppercase extension caught"
}

test_added_pdf_in_workspace_is_blocked() {
    make_repo || return 1
    printf 'x\n' > workspaces/2026/09/x/statement.pdf
    printf 'x\n' > workspaces/2026/09/x/export.ofx
    commit_all
    local out; out="$(check)" && { echo "should fail: $out"; return 1; }
    assert_contains "$out" "workspaces/2026/09/x/statement.pdf" || return 1
    assert_contains "$out" "workspaces/2026/09/x/export.ofx"
}

test_tracked_file_is_left_alone() {
    make_repo || return 1
    printf 'edited\n' >> knowledge/health/_raw/old.jpg
    commit_all
    local out; out="$(check)" || { echo "$out"; return 1; }
    assert_not_contains "$out" "raw-format file added"
}

test_derived_and_text_formats_pass() {
    make_repo || return 1
    printf 'a,b\n' > workspaces/2026/09/x/results.csv
    printf 'select 1;\n' > workspaces/2026/09/x/query.sql
    printf 'png\n' > workspaces/2026/09/x/chart.png
    printf '{"q":"from:bank"}\n' > knowledge/health/_raw/search-2026-09-21.json
    commit_all
    local out; out="$(check)" || { echo "$out"; return 1; }
    assert_not_contains "$out" "raw-format file added"
}

test_outside_content_trees_passes() {
    make_repo || return 1
    mkdir -p skills/x/fixtures
    printf 'x\n' > skills/x/fixtures/sample.pdf
    commit_all
    local out; out="$(check)" || { echo "$out"; return 1; }
    assert_not_contains "$out" "raw-format file added"
}

run_test "added photo in _raw/ is blocked"         test_added_photo_in_raw_is_blocked
run_test "added PDF and bank export are blocked"   test_added_pdf_in_workspace_is_blocked
run_test "an already-tracked file is left alone"   test_tracked_file_is_left_alone
run_test "text, SQL, and chart formats pass"       test_derived_and_text_formats_pass
run_test "files outside content trees pass"        test_outside_content_trees_passes

echo ""
printf "Ran %d  ${GREEN}passed %d${RESET}  ${RED}failed %d${RESET}\n" "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
if [[ $TESTS_FAILED -gt 0 ]]; then printf 'Failures: %s\n' ${FAILURES[*]+"${FAILURES[*]}"}; exit 1; fi
exit 0
