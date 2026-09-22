#!/usr/bin/env bash
# test-agent-attribution.sh — agent-neutral commit history (CLAUDE.md § Git history
# hygiene): scripts/strip-agent-attribution.sh, which the commit-msg hook runs on
# every commit, and the validator check that catches a commit that bypassed it.
#
#   skills/exobrain-tests/unit/test-agent-attribution.sh            # run all
#   skills/exobrain-tests/unit/test-agent-attribution.sh <pattern>  # filter by name
#
# The strip tests run the script on message files. The validator tests build a real
# git repo with a default-branch ref, since the check reads the outgoing commits.

set -uo pipefail

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0; FAILURES=()
FILTER="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPTS_DIR="$REPO_DIR/scripts"
STRIP="$SCRIPTS_DIR/strip-agent-attribution.sh"

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

assert_eq()           { [[ "$1" == "$2" ]] || { echo "ASSERT_EQ${3:+ ($3)}: expected:"; echo "$1"; echo "got:"; echo "$2"; return 1; }; }
assert_contains()     { [[ "$1" == *"$2"* ]] || { echo "ASSERT_CONTAINS${3:+ ($3)}: '$2' not in:"; echo "$1"; return 1; }; }

# strip <message> — run the script on a file holding <message>; print the result.
strip() {
    printf '%s\n' "$1" > "$TEST_DIR/msg"
    bash "$STRIP" "$TEST_DIR/msg" 2>/dev/null || return 1
    cat "$TEST_DIR/msg"
}

# ---------------------------------------------------------------------------
# Tests — strip-agent-attribution.sh
# ---------------------------------------------------------------------------

test_strips_claude_trailer_and_footer() {
    local out; out="$(strip $'Add a thing\n\nBody line.\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\n\nCo-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>')" || return 1
    assert_eq $'Add a thing\n\nBody line.' "$out"
}

test_matching_is_case_insensitive() {
    local out; out="$(strip $'Add a thing\n\nco-authored-by: claude <noreply@anthropic.com>\nGENERATED WITH Codex')" || return 1
    assert_eq "Add a thing" "$out"
}

# A human co-author, prose about the rule, and a "generated with" that names no
# agent are all the message's own.
test_keeps_what_is_not_agent_attribution() {
    local msg=$'Explain the hygiene rule\n\nDo not add a Co-Authored-By: Claude trailer.\nGenerated with the new export script.\n\nCo-Authored-By: Alex <alex@example.com>'
    local out; out="$(strip "$msg")" || return 1
    assert_eq "$msg" "$out"
}

test_clean_message_is_left_byte_identical() {
    printf 'Subject\n\nBody\n\n' > "$TEST_DIR/msg"; cp "$TEST_DIR/msg" "$TEST_DIR/before"
    local err; err="$(bash "$STRIP" "$TEST_DIR/msg" 2>&1)" || return 1
    cmp -s "$TEST_DIR/before" "$TEST_DIR/msg" || { echo "clean message rewritten"; return 1; }
    assert_eq "" "$err" "nothing reported"
}

test_reports_a_removal() {
    printf 'Subject\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n' > "$TEST_DIR/msg"
    assert_contains "$(bash "$STRIP" "$TEST_DIR/msg" 2>&1)" "removed agent attribution"
}

test_usage_error_without_a_file() {
    bash "$STRIP" >/dev/null 2>&1; local rc=$?
    assert_eq 2 "$rc" "no argument" || return 1
    bash "$STRIP" "$TEST_DIR/missing" >/dev/null 2>&1; rc=$?
    assert_eq 2 "$rc" "missing file"
}

# The hook strips and the validator rejects by the same rule; the two copies must not drift.
test_pattern_matches_the_validators() {
    local a b
    a="$(grep '^AGENT_ATTRIBUTION_RE=' "$STRIP")"
    b="$(grep '^AGENT_ATTRIBUTION_RE=' "$SCRIPTS_DIR/validate-exobrain.sh")"
    [[ -n "$a" ]] || { echo "no pattern in the strip script"; return 1; }
    assert_eq "$a" "$b"
}

# ---------------------------------------------------------------------------
# Tests — validator
# ---------------------------------------------------------------------------

# make_repo — a minimal exobrain with a base commit and origin/main pointing at it.
make_repo() {
    cd "$TEST_DIR" || return 1
    git init -q -b main .
    git config user.email t@example.com; git config user.name t; git config commit.gpgsign false
    mkdir -p scripts knowledge/plain
    cp "$SCRIPTS_DIR/validate-exobrain.sh" scripts/
    printf '# Exobrain\n' > AGENTS.md
    printf '{"scopes":[]}\n' > scopes.json
    printf '{"skills":[]}\n' > skills.json
    git add -A && git commit -qm base
    git update-ref refs/remotes/origin/main HEAD
}
commit_with() { printf '%s\n' "$RANDOM" >> knowledge/plain/x.md; git add -A && git commit -q --no-verify -m "$1"; }
check() { bash scripts/validate-exobrain.sh 2>&1; }

test_validator_rejects_a_commit_that_bypassed_the_hook() {
    make_repo || return 1
    commit_with $'Change x\n\nCo-Authored-By: Claude Opus 5 <noreply@anthropic.com>'
    local out; out="$(check)" && { echo "should fail: $out"; return 1; }
    assert_contains "$out" "agent attribution in outgoing commit message"
}

test_validator_passes_a_neutral_commit() {
    make_repo || return 1
    commit_with $'Change x\n\nDo not add a Co-Authored-By: Claude trailer.\n\nCo-Authored-By: Alex <alex@example.com>'
    local out; out="$(check)" || { echo "should pass: $out"; return 1; }
}

# ---------------------------------------------------------------------------

run_test strips_claude_trailer_and_footer        test_strips_claude_trailer_and_footer
run_test matching_is_case_insensitive            test_matching_is_case_insensitive
run_test keeps_what_is_not_agent_attribution     test_keeps_what_is_not_agent_attribution
run_test clean_message_is_left_byte_identical    test_clean_message_is_left_byte_identical
run_test reports_a_removal                       test_reports_a_removal
run_test usage_error_without_a_file              test_usage_error_without_a_file
run_test pattern_matches_the_validators          test_pattern_matches_the_validators
run_test validator_rejects_a_commit_that_bypassed_the_hook test_validator_rejects_a_commit_that_bypassed_the_hook
run_test validator_passes_a_neutral_commit       test_validator_passes_a_neutral_commit

echo ""
if [[ $TESTS_FAILED -gt 0 ]]; then
    printf "${RED}%d/%d failed${RESET}: %s\n" "$TESTS_FAILED" "$TESTS_RUN" ${FAILURES[*]+"${FAILURES[*]}"}
    exit 1
fi
printf "${GREEN}%d/%d passed${RESET}\n" "$TESTS_PASSED" "$TESTS_RUN"
