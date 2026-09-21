#!/usr/bin/env bash
# test-findings-pending.sh — tests for findings-pending.sh, the detector that says
# which merged PRs still carry authoring-review findings an unattended land recorded.
# Runs as the unit suite's findings-pending harness.
#
#   skills/exobrain-repair-findings/tests/test-findings-pending.sh            # run all
#   skills/exobrain-repair-findings/tests/test-findings-pending.sh <pattern>  # filter by name
#
# A fake `gh` on PATH serves PR bodies and labels from a JSON fixture, so the tests
# pin the qualifying rule itself: a body that merely mentions the phrase does not
# qualify (a PR about the persist machinery does that), only one carrying the heading.
# No network, no credentials, nothing touching the real repo or a real forge.

set -uo pipefail

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0; FAILURES=()
FILTER="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"          # .../exobrain-repair-findings/tests
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"        # repo root: tests→exobrain-repair-findings→skills→root
SCRIPTS_DIR="$SCRIPT_DIR/../scripts"                  # the skill's script under test

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

HEADING="$(bash "$SCRIPTS_DIR/findings-pending.sh" --heading)"
LABEL="$(bash "$SCRIPTS_DIR/findings-pending.sh" --label)"

# setup_gh — a `gh` on PATH backed by $TEST_DIR/prs.json, a map of
# number → {title, body, labels}. `search prs` lists every number whose body
# mentions the search phrase; `pr view` serves one PR's fields as TSV.
setup_gh() {
    FAKE_BIN="$TEST_DIR/bin"; mkdir -p "$FAKE_BIN"
    cat > "$FAKE_BIN/gh" <<EOF
#!/usr/bin/env bash
set -uo pipefail
DATA="$TEST_DIR/prs.json"
case "\$1 \$2" in
  "search prs")
    jq -r 'to_entries | map(select(.value.body | test("unattended land"))) | sort_by(.key | tonumber) | reverse | .[].key' "\$DATA" ;;
  "pr view")
    n="\$3"
    jq -r --arg n "\$n" '.[\$n] | [((.labels // []) | join(",")), .title, .body] | @tsv' "\$DATA" ;;
  *) echo "fake gh: unsupported: \$*" >&2; exit 2 ;;
esac
EOF
    chmod +x "$FAKE_BIN/gh"
}

# add_pr <number> <title> <body>  — writes into the fixture; labels via add_label.
add_pr() {
    [[ -f "$TEST_DIR/prs.json" ]] || echo '{}' > "$TEST_DIR/prs.json"
    jq --arg n "$1" --arg t "$2" --arg b "$3" '.[$n] = {title: $t, body: $b, labels: []}' \
        "$TEST_DIR/prs.json" > "$TEST_DIR/prs.t" && mv "$TEST_DIR/prs.t" "$TEST_DIR/prs.json"
}
add_label() {
    jq --arg n "$1" --arg l "$2" '.[$n].labels += [$l]' \
        "$TEST_DIR/prs.json" > "$TEST_DIR/prs.t" && mv "$TEST_DIR/prs.t" "$TEST_DIR/prs.json"
}
with_findings() { printf -- '- %s\n\n%s\n\n%s\n' "$1" "$HEADING" "knowledge/x.md: a finding -- fix it."; }
pending() { PATH="$FAKE_BIN:$PATH" bash "$SCRIPTS_DIR/findings-pending.sh" "$@"; }

# ---------------------------------------------------------------------------

test_lists_only_prs_carrying_the_heading() {
    setup_gh
    add_pr 10 "Recorded a fact"     "$(with_findings "Recorded a fact")"
    add_pr 11 "Machinery change"    "This PR is about an unattended land, but carries no findings of its own."
    add_pr 12 "Another fact"        "$(with_findings "Another fact")"
    local out; out="$(pending)" || return 1
    assert_contains "$out" $'10\tRecorded a fact' || return 1
    assert_contains "$out" $'12\tAnother fact' || return 1
    assert_not_contains "$out" "Machinery change" "a body merely mentioning the phrase does not qualify"
}

test_repaired_label_excludes_a_pr() {
    setup_gh
    add_pr 10 "Fixed already" "$(with_findings "Fixed already")"; add_label 10 "$LABEL"
    add_pr 11 "Still pending" "$(with_findings "Still pending")"
    local out; out="$(pending)" || return 1
    assert_not_contains "$out" "Fixed already" || return 1
    assert_contains "$out" $'11\tStill pending'
}

test_other_labels_do_not_exclude() {
    setup_gh
    add_pr 10 "Labelled otherwise" "$(with_findings "Labelled otherwise")"; add_label 10 "documentation"
    assert_contains "$(pending)" $'10\tLabelled otherwise'
}

test_oldest_first() {
    setup_gh
    add_pr 30 "Third"  "$(with_findings Third)"
    add_pr 10 "First"  "$(with_findings First)"
    add_pr 20 "Second" "$(with_findings Second)"
    local out; out="$(pending)" || return 1
    assert_eq "10 20 30" "$(cut -f1 <<< "$out" | tr '\n' ' ' | sed 's/ $//')"
}

test_nothing_pending_is_empty_and_ok() {
    setup_gh
    add_pr 10 "Clean change" "Nothing was flagged here."
    local out; out="$(pending)"; local rc=$?
    assert_eq 0 "$rc" "exit code" || return 1
    assert_eq "" "$out" "no output"
}

# persist.sh writes the heading this script looks for; the two must not drift.
test_heading_matches_the_one_persist_writes() {
    assert_contains "$(cat "$REPO_DIR/scripts/persist.sh")" "FINDINGS_HEADING=\"$HEADING\""
}

test_unknown_argument_is_a_usage_error() {
    setup_gh; add_pr 10 "x" "$(with_findings x)"
    pending --nope >/dev/null 2>&1; local rc=$?
    assert_eq 2 "$rc" "exit code" || return 1
    pending --limit abc >/dev/null 2>&1; rc=$?
    assert_eq 2 "$rc" "a non-numeric limit" || return 1
    pending --limit >/dev/null 2>&1; rc=$?
    assert_eq 2 "$rc" "a limit without its value"
}

# ---------------------------------------------------------------------------

run_test lists_only_prs_carrying_the_heading  test_lists_only_prs_carrying_the_heading
run_test repaired_label_excludes_a_pr         test_repaired_label_excludes_a_pr
run_test other_labels_do_not_exclude          test_other_labels_do_not_exclude
run_test oldest_first                         test_oldest_first
run_test nothing_pending_is_empty_and_ok      test_nothing_pending_is_empty_and_ok
run_test heading_matches_the_one_persist_writes test_heading_matches_the_one_persist_writes
run_test unknown_argument_is_a_usage_error    test_unknown_argument_is_a_usage_error

echo ""
if [[ $TESTS_FAILED -gt 0 ]]; then
    printf "${RED}%d/%d failed${RESET}: %s\n" "$TESTS_FAILED" "$TESTS_RUN" ${FAILURES[*]+"${FAILURES[*]}"}
    exit 1
fi
printf "${GREEN}%d/%d passed${RESET}\n" "$TESTS_PASSED" "$TESTS_RUN"
