#!/usr/bin/env bash
# test-scratch-retention.sh — the scratch report in exobrain-healthcheck.sh: a tmp/
# entry or a _cache/ directory with no file touched in the window is named with its
# age and size, one touched inside the window is not, the listing is capped, the
# window is EXOBRAIN_SCRATCH_DAYS, and the check stays advisory (exit 0).
#
#   skills/exobrain-tests/unit/test-scratch-retention.sh            # run all
#   skills/exobrain-tests/unit/test-scratch-retention.sh <pattern>  # filter by name
#
# Each test builds a fake exobrain in a system temp dir (outside any git repository,
# so the healthcheck's MAIN resolves to the fixture) and sets file times with touch.

set -uo pipefail

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0; FAILURES=()
FILTER="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPTS_DIR="$REPO_DIR/scripts"

RED='\033[0;31m'; GREEN='\033[0;32m'; DIM='\033[0;90m'; BOLD='\033[1m'; RESET='\033[0m'

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
assert_contains()     { [[ "$1" == *"$2"* ]] || { echo "ASSERT_CONTAINS${3:+ ($3)}: '$2' not in output"; echo "$1"; return 1; }; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || { echo "ASSERT_NOT_CONTAINS${3:+ ($3)}: '$2' present in output"; echo "$1"; return 1; }; }

setup_repo() {
    local repo="$TEST_DIR/exobrain"
    mkdir -p "$repo/scripts" "$repo/tmp" "$repo/workspaces/2026/01/01-w/_cache" "$repo/knowledge/x"
    cp "$SCRIPTS_DIR/exobrain-healthcheck.sh" "$repo/scripts/"
    chmod +x "$repo/scripts/exobrain-healthcheck.sh"
    printf '# Exobrain\n' > "$repo/AGENTS.md"
    echo "$repo"
}

# old <file> [days] — create <file> last touched <days> (default 60) ago.
old() { mkdir -p "$(dirname "$1")"; printf 'x\n' > "$1"; touch -t "$(date -v-"${2:-60}"d +%Y%m%d%H%M 2>/dev/null || date -d "-${2:-60} days" +%Y%m%d%H%M)" "$1"; }

healthcheck() { (cd "$1" && bash scripts/exobrain-healthcheck.sh 2>&1); }

test_stale_entries_named_with_age_and_size() {
    local r o rc; r="$(setup_repo)"
    old "$r/tmp/dump/db.sql" 60
    old "$r/workspaces/2026/01/01-w/_cache/export.csv" 45
    printf 'fresh\n' > "$r/tmp/today.txt"
    o="$(healthcheck "$r")" && rc=0 || rc=$?
    assert_eq 0 "$rc" "advisory: exit 0" || return 1
    assert_contains "$o" "2 scratch entries untouched for 30+ days" || return 1
    assert_contains "$o" "tmp/dump — 60d untouched," "the stale tmp entry, with its age" || return 1
    assert_contains "$o" "workspaces/2026/01/01-w/_cache — 45d untouched," "the stale cache" || return 1
    assert_not_contains "$o" "today.txt" "a fresh entry is not named" || return 1
    assert_contains "$o" "Delete what its work no longer needs" || return 1
}

test_one_fresh_file_clears_a_directory() {
    local r o; r="$(setup_repo)"
    old "$r/tmp/mixed/old.bin" 90
    printf 'new\n' > "$r/tmp/mixed/new.bin"
    o="$(healthcheck "$r")"
    assert_not_contains "$o" "scratch" "a directory with one file inside the window is in use" || return 1
}

test_window_is_configurable_and_listing_capped() {
    local r o i; r="$(setup_repo)"
    for i in $(seq 1 12); do old "$r/tmp/e$i/f" 20; done
    o="$(healthcheck "$r")"
    assert_not_contains "$o" "scratch" "20 days is inside the default window" || return 1
    o="$(cd "$r" && EXOBRAIN_SCRATCH_DAYS=10 bash scripts/exobrain-healthcheck.sh 2>&1)"
    assert_contains "$o" "12 scratch entries untouched for 10+ days" || return 1
    assert_contains "$o" "… and 2 more" "the listing shows ten" || return 1
}

test_quiet_when_nothing_is_stale() {
    local r o; r="$(setup_repo)"
    printf 'new\n' > "$r/tmp/now.txt"
    o="$(healthcheck "$r")"
    assert_not_contains "$o" "scratch" || return 1
}

echo -e "\n${BOLD}scratch retention — exobrain-healthcheck.sh${RESET}\n"
run_test "stale entries named with age and size"         test_stale_entries_named_with_age_and_size
run_test "one fresh file clears a directory"             test_one_fresh_file_clears_a_directory
run_test "window configurable; listing capped at ten"    test_window_is_configurable_and_listing_capped
run_test "quiet when nothing is stale"                   test_quiet_when_nothing_is_stale

echo
if (( TESTS_FAILED > 0 )); then
    echo -e "${RED}${TESTS_FAILED} failed${RESET}, ${TESTS_PASSED} passed of ${TESTS_RUN}"
    for f in ${FAILURES[@]+"${FAILURES[@]}"}; do echo "  - $f"; done
    exit 1
fi
echo -e "${GREEN}all ${TESTS_PASSED} passed${RESET}"
