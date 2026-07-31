#!/usr/bin/env bash
# test-compat-ledger.sh — tests for the compatibility-shim ledger
# (knowledge/exobrain/compat.md): the marker↔row consistency checks in
# validate-exobrain.sh and the past-the-date advisory in exobrain-healthcheck.sh.
# Exercises the framework scripts in <repo>/scripts/ of whichever instance this
# suite is installed in.
#
#   skills/exobrain-tests/unit/test-compat-ledger.sh            # run all
#   skills/exobrain-tests/unit/test-compat-ledger.sh <pattern>  # filter by name
#
# Each test builds a fake exobrain in a temp dir — a ledger, a script carrying a
# marker — so nothing reads the real tree and the dates are fixed rather than
# relative to today.

set -uo pipefail

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0; FAILURES=()
FILTER="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"          # .../exobrain-tests/unit
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"        # repo root: unit→exobrain-tests→skills→root
SCRIPTS_DIR="$REPO_DIR/scripts"                       # framework scripts under test

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

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

PAST_DATE="2020-01-01"      # fixed dates: a run's verdict never depends on today
FUTURE_DATE="2999-12-31"

# setup_repo — fake exobrain carrying the real validator and healthcheck.
setup_repo() {
    local repo="$TEST_DIR/exobrain"
    mkdir -p "$repo/scripts" "$repo/knowledge/exobrain"
    cp "$SCRIPTS_DIR/validate-exobrain.sh" "$SCRIPTS_DIR/exobrain-healthcheck.sh" "$repo/scripts/"
    chmod +x "$repo/scripts/"*.sh
    printf '# Exobrain\n\nFake.\n' > "$repo/AGENTS.md"
    echo "$repo"
}

# write_ledger <repo> <row>... — a ledger with the convention text and the given rows.
write_ledger() {
    local repo="$1"; shift
    { printf '# Compatibility shims\n\n## Ledger\n\n'
      printf '| id | Heals | Files | Added | Remove after |\n|---|---|---|---|---|\n'
      printf '%s\n' "$@"
    } > "$repo/knowledge/exobrain/compat.md"
}

# write_shim <repo> <id> <date> — a script carrying one marker.
write_shim() {
    local repo="$1" id="$2" date="$3"
    { printf '#!/usr/bin/env bash\n'
      printf '# COMPAT %s (remove after %s) — heals the old thing.\n' "$id" "$date"
      printf 'true\n'
    } > "$repo/scripts/shim.sh"
}

validate()    { "$1/scripts/validate-exobrain.sh" 2>&1; }
healthcheck() { "$1/scripts/exobrain-healthcheck.sh" 2>&1; }

# ---------------------------------------------------------------------------
# validate-exobrain.sh — marker ↔ row consistency
# ---------------------------------------------------------------------------

test_matching_marker_and_row_pass() {
    local r; r="$(setup_repo)"
    write_shim "$r" 0001 "$FUTURE_DATE"
    write_ledger "$r" "| 0001 | Old thing. | \`scripts/shim.sh\` | 2026-01-01 | $FUTURE_DATE |"
    local o rc; o="$(validate "$r")" && rc=0 || rc=$?
    assert_eq 0 "$rc" "clean ledger validates" || { echo "$o"; return 1; }
}

test_marker_without_row_fails() {
    local r; r="$(setup_repo)"
    write_shim "$r" 0002 "$FUTURE_DATE"
    write_ledger "$r" "| 0001 | Old thing. | \`scripts/shim.sh\` | 2026-01-01 | $FUTURE_DATE |"
    local o rc; o="$(validate "$r")" && rc=0 || rc=$?
    assert_eq 1 "$rc" "unledgered marker fails" || return 1
    assert_contains "$o" "COMPAT 0002 marker with no row"
}

test_row_without_marker_fails() {
    local r; r="$(setup_repo)"
    printf '#!/usr/bin/env bash\ntrue\n' > "$r/scripts/shim.sh"
    write_ledger "$r" "| 0001 | Old thing. | \`scripts/shim.sh\` | 2026-01-01 | $FUTURE_DATE |"
    local o rc; o="$(validate "$r")" && rc=0 || rc=$?
    assert_eq 1 "$rc" "row over an unmarked file fails" || return 1
    assert_contains "$o" "carries no 'COMPAT 0001' marker"
}

test_missing_file_fails() {
    local r; r="$(setup_repo)"
    write_ledger "$r" "| 0001 | Old thing. | \`scripts/gone.sh\` | 2026-01-01 | $FUTURE_DATE |"
    local o rc; o="$(validate "$r")" && rc=0 || rc=$?
    assert_eq 1 "$rc" "row over a missing file fails" || return 1
    assert_contains "$o" "lists a file that doesn't exist"
}

test_date_drift_fails() {
    local r; r="$(setup_repo)"
    write_shim "$r" 0001 "2026-03-03"
    write_ledger "$r" "| 0001 | Old thing. | \`scripts/shim.sh\` | 2026-01-01 | $FUTURE_DATE |"
    local o rc; o="$(validate "$r")" && rc=0 || rc=$?
    assert_eq 1 "$rc" "marker/ledger date drift fails" || return 1
    assert_contains "$o" "disagrees with the ledger"
}

test_duplicate_id_fails() {
    local r; r="$(setup_repo)"
    write_shim "$r" 0001 "$FUTURE_DATE"
    write_ledger "$r" \
        "| 0001 | Old thing. | \`scripts/shim.sh\` | 2026-01-01 | $FUTURE_DATE |" \
        "| 0001 | Other thing. | \`scripts/shim.sh\` | 2026-01-02 | $FUTURE_DATE |"
    local o rc; o="$(validate "$r")" && rc=0 || rc=$?
    assert_eq 1 "$rc" "duplicate id fails" || return 1
    assert_contains "$o" "duplicate shim id 0001"
}

# A shim past its date is the healthcheck's business — the validator must not turn
# the calendar into a push blocker.
test_overdue_shim_does_not_fail_validation() {
    local r; r="$(setup_repo)"
    write_shim "$r" 0001 "$PAST_DATE"
    write_ledger "$r" "| 0001 | Old thing. | \`scripts/shim.sh\` | 2019-01-01 | $PAST_DATE |"
    local o rc; o="$(validate "$r")" && rc=0 || rc=$?
    assert_eq 0 "$rc" "an overdue shim still validates clean" || { echo "$o"; return 1; }
}

# A marker is a comment line; docs and tests quoting the string are prose, not code.
test_prose_mention_is_not_a_marker() {
    local r; r="$(setup_repo)"
    write_shim "$r" 0001 "$FUTURE_DATE"
    write_ledger "$r" "| 0001 | Old thing. | \`scripts/shim.sh\` | 2026-01-01 | $FUTURE_DATE |"
    printf '# Notes\n\nA card quoting `COMPAT 0042 (remove after 2020-01-01)` as an example.\n' > "$r/notes.md"
    local o rc; o="$(validate "$r")" && rc=0 || rc=$?
    assert_eq 0 "$rc" "a quoted marker in prose is not a shim" || { echo "$o"; return 1; }
}

test_no_ledger_skips() {
    local r; r="$(setup_repo)"
    rm -rf "$r/knowledge"
    local o rc; o="$(validate "$r")" && rc=0 || rc=$?
    assert_eq 0 "$rc" "an instance without the ledger degrades open" || { echo "$o"; return 1; }
}

# ---------------------------------------------------------------------------
# exobrain-healthcheck.sh — the past-the-date advisory
# ---------------------------------------------------------------------------

test_healthcheck_names_overdue_shim() {
    local r; r="$(setup_repo)"
    write_shim "$r" 0001 "$PAST_DATE"
    write_ledger "$r" "| 0001 | Codex skill links in the home dir. | \`scripts/shim.sh\` | 2019-01-01 | $PAST_DATE |"
    local o rc; o="$(healthcheck "$r")" && rc=0 || rc=$?
    assert_eq 0 "$rc" "healthcheck stays advisory (exit 0)" || return 1
    assert_contains "$o" "COMPAT 0001 (due $PAST_DATE)" || return 1
    assert_contains "$o" "Codex skill links in the home dir."
}

test_healthcheck_quiet_before_the_date() {
    local r; r="$(setup_repo)"
    write_shim "$r" 0001 "$FUTURE_DATE"
    write_ledger "$r" "| 0001 | Old thing. | \`scripts/shim.sh\` | 2026-01-01 | $FUTURE_DATE |"
    local o rc; o="$(healthcheck "$r")" && rc=0 || rc=$?
    assert_eq 0 "$rc" "healthcheck exits 0" || return 1
    assert_not_contains "$o" "COMPAT 0001"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

echo ""; echo "${BOLD}compat-ledger test suite${RESET}"; echo ""

run_test "matching marker and row validate clean"   test_matching_marker_and_row_pass
run_test "marker with no ledger row fails"          test_marker_without_row_fails
run_test "row over an unmarked file fails"          test_row_without_marker_fails
run_test "row naming a missing file fails"          test_missing_file_fails
run_test "marker/ledger date drift fails"           test_date_drift_fails
run_test "duplicate shim id fails"                  test_duplicate_id_fails
run_test "overdue shim never fails validation"      test_overdue_shim_does_not_fail_validation
run_test "quoted marker in prose is not a shim"     test_prose_mention_is_not_a_marker
run_test "no ledger degrades open"                  test_no_ledger_skips
run_test "healthcheck names an overdue shim"        test_healthcheck_names_overdue_shim
run_test "healthcheck quiet before the date"        test_healthcheck_quiet_before_the_date

echo ""; echo "─────────────────────────────────────────────"
if [[ $TESTS_FAILED -eq 0 ]]; then
    printf "${GREEN}${BOLD}All %d tests passed${RESET}\n" "$TESTS_RUN"
else
    printf "${RED}${BOLD}%d of %d tests failed${RESET}\n" "$TESTS_FAILED" "$TESTS_RUN"
    printf '  - %s\n' "${FAILURES[@]}"
fi
echo "─────────────────────────────────────────────"
exit "$TESTS_FAILED"
