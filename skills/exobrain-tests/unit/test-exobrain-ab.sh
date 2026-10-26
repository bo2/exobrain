#!/usr/bin/env bash
# test-exobrain-ab.sh — the exobrain-ab harness's own machinery: run_one.sh's grading
# and run.sh's task-row check. A grader that is miswritten must fail the run, never
# read as a null result (both arms 0/N, "the change moved nothing").
#
#   skills/exobrain-tests/unit/test-exobrain-ab.sh            # run all
#   skills/exobrain-tests/unit/test-exobrain-ab.sh <pattern>  # filter by name
#
# `claude` is a fake on PATH that prints a canned answer and may run one command, so
# the stub log and the agent's stdout are both exercised without a model. The run.sh
# cases copy the harness scripts into a throwaway git repo. No agent, no network, no
# usage, nothing touches the real repo.

set -uo pipefail

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0; FAILURES=()
FILTER="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"            # .../exobrain-tests/unit
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AB_DIR="$REPO_DIR/skills/exobrain-ab/scripts"           # the harness under test

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
assert_contains()     { [[ "$1" == *"$2"* ]] || { echo "ASSERT_CONTAINS${3:+ ($3)}: '$2' not in:"; echo "$1"; return 1; }; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || { echo "ASSERT_NOT_CONTAINS${3:+ ($3)}: '$2' present in:"; echo "$1"; return 1; }; }

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

# fake_claude <stdout> [command...] — a `claude` on PATH that ignores its flags, runs
# the optional command (so a PATH stub can log it), and prints <stdout>. run_one.sh
# retries a run whose stdout is empty, so the fake always says something.
fake_claude() {
    local out="$1"; shift
    mkdir -p "$TEST_DIR/bin"
    {
        printf '#!/usr/bin/env bash\n'
        [[ $# -gt 0 ]] && printf '%q ' "$@" && printf '>/dev/null 2>&1\n'
        printf 'printf %%s\\\\n %q\n' "$out"
    } > "$TEST_DIR/bin/claude"
    chmod +x "$TEST_DIR/bin/claude"
}

# grade <GRADE> <correct_re> <wrong_re> — one run_one.sh run against the fake agent;
# prints the CSV row it appended ("<i>,<verdict>,<evidence>").
grade() {
    mkdir -p "$TEST_DIR/template" "$TEST_DIR/sb"; : > "$TEST_DIR/template/README.md"
    local out="$TEST_DIR/out.csv"; : > "$out"
    ( PATH="$TEST_DIR/bin:$PATH" AGENT=claude ARM=control TEMPLATE="$TEST_DIR/template" \
      STUBS="$AB_DIR/stubs" MODEL=m TASK_PROMPT=p GRADE="$1" CORRECT_RE="$2" WRONG_RE="$3" \
      OUT="$out" SANDBOX_ROOT="$TEST_DIR/sb" TIMEOUT=30 \
      bash "$AB_DIR/run_one.sh" 1 ) >/dev/null 2>&1
    cat "$out"
}

# make_repo — a git repo carrying a copy of the harness scripts, so run.sh resolves
# its repo and trunk there and never under the real checkout.
make_repo() {
    local r="$TEST_DIR/repo"
    mkdir -p "$r/skills/exobrain-ab"
    cp -R "$AB_DIR" "$r/skills/exobrain-ab/scripts"
    git -C "$r" init -q -b main
    git -C "$r" -c user.email=t@t.test -c user.name=t add -A
    git -C "$r" -c user.email=t@t.test -c user.name=t commit -qm init
    fake_claude ok
    echo "$r"
}

# run_matrix <repo> <tasks file> — run.sh up to its first failure; prints the combined
# output and returns its exit code.
run_matrix() {
    ( cd "$1" && PATH="$TEST_DIR/bin:$PATH" bash skills/exobrain-ab/scripts/run.sh /dev/null "$2" 1 1 m all 2>&1 )
}

# ---------------------------------------------------------------------------
# run_one.sh — a pattern beginning with '-' is a pattern, not a grep option
# ---------------------------------------------------------------------------

test_output_dash_pattern_grades_correct() {
    fake_claude 'run it with --parent set'
    local row; row="$(grade output '--parent' '')"
    assert_contains "$row" "1,correct," "a dash-leading correct_re matches stdout" || return 1
    assert_contains "$row" "--parent" "the evidence column carries the match" || return 1
}

test_output_dash_wrong_pattern_grades_wrong() {
    fake_claude 'use -w here'
    local row; row="$(grade output '-z' '-w')"
    assert_contains "$row" "1,wrong," "a dash-leading wrong_re matches stdout" || return 1
}

test_output_absent_dash_pattern_both_ways() {
    fake_claude 'fine'
    assert_contains "$(grade output_absent '' '-x')" "1,correct," "banned pattern absent" || return 1
    fake_claude 'ran with -x'
    assert_contains "$(grade output_absent '' '-x')" "1,wrong," "banned pattern present" || return 1
}

test_match_dash_pattern_grades_stublog() {
    # The fake agent reaches for the stub, which logs its invocation.
    fake_claude done example-tool --parent list
    local row; row="$(grade match '^example-tool --parent' '')"
    assert_contains "$row" "1,correct," "a dash-leading correct_re matches the stub log" || return 1
    assert_contains "$row" "example-tool --parent list" "the stub log is the evidence" || return 1
}

# ---------------------------------------------------------------------------
# run.sh — a malformed task row is refused before any sandbox is built
# ---------------------------------------------------------------------------

test_row_with_extra_field_is_refused() {
    local r; r="$(make_repo)"
    cat > "$TEST_DIR/tasks.sh" <<'EOF'
TASKS=(
"T_ok|dev|match|^example-tool .*list|^example-tool +[^l]|List the widgets."
"T_alt|dev|match|^example-tool .*(create|delete)|^x|Make a widget."
)
EOF
    local out rc; out="$(run_matrix "$r" "$TEST_DIR/tasks.sh")"; rc=$?
    assert_eq 1 "$rc" "run.sh exits 1" || return 1
    assert_contains "$out" "T_alt" "the refusal names the row" || return 1
    assert_contains "$out" "7 fields" "and its field count" || return 1
    assert_not_contains "$out" "Building templates" "nothing was built" || return 1
}

test_row_with_missing_field_is_refused() {
    local r; r="$(make_repo)"
    printf 'TASKS=(\n"T_short|dev|no_tool||Count the files."\n)\n' > "$TEST_DIR/tasks.sh"
    local out rc; out="$(run_matrix "$r" "$TEST_DIR/tasks.sh")"; rc=$?
    assert_eq 1 "$rc" "run.sh exits 1" || return 1
    assert_contains "$out" "T_short" "the refusal names the row" || return 1
    assert_contains "$out" "5 fields" "and its field count" || return 1
}

test_well_formed_rows_reach_the_build() {
    # The throwaway repo carries no connector, so the build fails after the check:
    # what matters is that the check let the file through.
    local r; r="$(make_repo)"
    printf 'TASKS=(\n"T_ok|dev|match|^example-tool .*list|^example-tool +[^l]|List the widgets."\n)\n' > "$TEST_DIR/tasks.sh"
    local out; out="$(run_matrix "$r" "$TEST_DIR/tasks.sh")"
    assert_not_contains "$out" "fields, not 6" "no row refused" || return 1
    assert_contains "$out" "Building templates" "the run went on to build" || return 1
}

test_shipped_template_passes_its_own_rule() {
    # shellcheck disable=SC1090
    TASKS=(); source "$AB_DIR/tasks.example.sh"
    [[ ${#TASKS[@]} -gt 0 ]] || { echo "tasks.example.sh defined no TASKS"; return 1; }
    local entry n
    for entry in ${TASKS[@]+"${TASKS[@]}"}; do
        n="$(printf '%s\n' "$entry" | awk -F'|' '{print NF}')"
        assert_eq 6 "$n" "row '${entry%%|*}' has six fields" || return 1
    done
}

# ---------------------------------------------------------------------------

echo -e "\n${BOLD}exobrain-ab — run_one.sh grading, run.sh task rows${RESET}\n"
run_test "output: dash-leading correct_re grades"        test_output_dash_pattern_grades_correct
run_test "output: dash-leading wrong_re grades"          test_output_dash_wrong_pattern_grades_wrong
run_test "output_absent: dash-leading pattern both ways" test_output_absent_dash_pattern_both_ways
run_test "match: dash-leading pattern reads the stublog" test_match_dash_pattern_grades_stublog
run_test "a row with an extra field is refused"          test_row_with_extra_field_is_refused
run_test "a row with a missing field is refused"         test_row_with_missing_field_is_refused
run_test "well-formed rows reach the build"              test_well_formed_rows_reach_the_build
run_test "the shipped template passes its own rule"      test_shipped_template_passes_its_own_rule

echo
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}${TESTS_FAILED} failed${RESET}, ${TESTS_PASSED} passed of ${TESTS_RUN}"
    for f in ${FAILURES[@]+"${FAILURES[@]}"}; do echo "  - $f"; done
    exit 1
fi
echo -e "${GREEN}all ${TESTS_PASSED} passed${RESET}"
