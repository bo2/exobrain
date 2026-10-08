#!/usr/bin/env bash
# test-secret-scan.sh — the secret scan in validate-exobrain.sh (AGENTS.md §
# Security: never commit secrets): gitleaks over the commits a branch adds against
# the default branch, grandfathering the history, redacting what it finds, and
# saying so when it is not installed.
#
#   skills/exobrain-tests/unit/test-secret-scan.sh            # run all
#   skills/exobrain-tests/unit/test-secret-scan.sh <pattern>  # filter by name
#
# Each test builds a real git repo in a temp dir with a default ref to diff against.
# The planted key is ASSEMBLED from two strings, never spelled whole: this harness is
# itself pushed through the scan it tests. Cases needing gitleaks self-skip without it.

set -uo pipefail

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0; TESTS_SKIPPED=0; FAILURES=()
FILTER="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPTS_DIR="$REPO_DIR/scripts"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; DIM='\033[0;90m'; BOLD='\033[1m'; RESET='\033[0m'

run_test() {
    local name="$1"; shift
    [[ -n "$FILTER" && "$name" != *"$FILTER"* ]] && return 0
    TESTS_RUN=$((TESTS_RUN + 1))
    printf "${DIM}%-52s${RESET} " "$name"
    TEST_DIR="$(mktemp -d)"
    trap 'rm -rf "$TEST_DIR"' RETURN
    local output rc
    output=$("$@" 2>&1); rc=$?
    if (( rc == 0 )); then
        TESTS_PASSED=$((TESTS_PASSED + 1)); printf "${GREEN}PASS${RESET}\n"
    elif (( rc == 77 )); then
        TESTS_SKIPPED=$((TESTS_SKIPPED + 1)); TESTS_RUN=$((TESTS_RUN - 1)); printf "${YELLOW}SKIP${RESET} %s\n" "$output"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1)); FAILURES+=("$name"); printf "${RED}FAIL${RESET}\n"
        echo "$output" | sed 's/^/    /'
    fi
}

assert_contains()     { [[ "$1" == *"$2"* ]] || { echo "ASSERT_CONTAINS${3:+ ($3)}: '$2' not in output"; echo "$1"; return 1; }; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || { echo "ASSERT_NOT_CONTAINS${3:+ ($3)}: '$2' present in output"; echo "$1"; return 1; }; }

need_gitleaks() { command -v gitleaks >/dev/null 2>&1 || { echo "gitleaks not installed"; return 77; }; }

# A minimal exobrain with a git history and a default ref, the validator and its
# helper copied in, and the repo's own .gitleaks.toml.
make_repo() {
    cd "$TEST_DIR" || return 1
    git init -q -b main .
    git config user.email t@example.com
    git config user.name t
    mkdir -p scripts workspaces/2026/09/x
    cp "$SCRIPTS_DIR/validate-exobrain.sh" "$SCRIPTS_DIR/changed-paths.sh" scripts/
    cp "$REPO_DIR/.gitleaks.toml" .
    printf '# Exobrain\n' > AGENTS.md
    printf '{"collections":{"hosts":{"kind":"host"}}}\n' > scopes.json
    printf '{"skills":[]}\n' > skills.json
    git add -A && git commit -qm base
    git update-ref refs/remotes/origin/main HEAD
}

check() { bash scripts/validate-exobrain.sh 2>&1; }

# An AWS-shaped access key (base32 body, as the rule wants), assembled so this file never carries one.
KEY="AKIA""Q4ZX7MNB2VCL6PWT"

test_planted_key_is_caught_and_redacted() {
    need_gitleaks || return $?
    make_repo || return 1
    printf 'The export used aws_access_key_id = %s for the run.\n' "$KEY" > workspaces/2026/09/x/README.md
    git add -A && git commit -qm change
    local out; out="$(check)"
    assert_contains "$out" "possible secret in an outgoing commit" "a planted key is caught" || return 1
    assert_contains "$out" "workspaces/2026/09/x/README.md:1" "with its file and line" || return 1
    assert_not_contains "$out" "$KEY" "the value itself is never printed" || return 1
}

test_history_is_grandfathered() {
    need_gitleaks || return $?
    make_repo || return 1
    printf 'aws_access_key_id = %s\n' "$KEY" > workspaces/2026/09/x/old.md
    git add -A && git commit -qm "already on trunk"
    git update-ref refs/remotes/origin/main HEAD
    printf 'A harmless line.\n' > workspaces/2026/09/x/README.md
    git add -A && git commit -qm change
    local out; out="$(check)"
    assert_not_contains "$out" "possible secret" "a key already on the default branch is not re-reported" || return 1
}

test_inline_allow_is_honored() {
    need_gitleaks || return $?
    make_repo || return 1
    printf 'client_id = %s  # gitleaks:allow — a public identifier\n' "$KEY" > workspaces/2026/09/x/README.md
    git add -A && git commit -qm change
    local out; out="$(check)"
    assert_not_contains "$out" "possible secret" "an inline allow passes" || return 1
}

test_absent_gitleaks_is_a_note_not_a_violation() {
    make_repo || return 1
    printf 'aws_access_key_id = %s\n' "$KEY" > workspaces/2026/09/x/README.md
    git add -A && git commit -qm change
    # A PATH with the system tools but no gitleaks: the check notes it and moves on.
    mkdir -p "$TEST_DIR/bin"
    for t in git bash python3 jq grep sed awk head tail cut sort dirname basename mktemp find xargs wc tr cat printf env uname stat date file readlink realpath tee rm cp mv mkdir touch ls; do
        p="$(command -v "$t" 2>/dev/null)" && ln -s "$p" "$TEST_DIR/bin/$t"
    done
    local out; out="$(PATH="$TEST_DIR/bin" bash scripts/validate-exobrain.sh 2>&1)"
    assert_contains "$out" "note: gitleaks not installed" "the skip is said aloud" || return 1
    assert_not_contains "$out" "possible secret" || return 1
    assert_contains "$out" "clean (0 violations)" || return 1
}

echo -e "\n${BOLD}secret scan — validate-exobrain.sh${RESET}\n"
run_test "a planted key is caught, the value redacted"   test_planted_key_is_caught_and_redacted
run_test "a key already on the default branch passes"    test_history_is_grandfathered
run_test "an inline gitleaks:allow is honored"           test_inline_allow_is_honored
run_test "gitleaks absent: a note, not a violation"      test_absent_gitleaks_is_a_note_not_a_violation

echo
skipped=""; (( TESTS_SKIPPED > 0 )) && skipped=" (${TESTS_SKIPPED} skipped: gitleaks not installed)"
if (( TESTS_FAILED > 0 )); then
    echo -e "${RED}${TESTS_FAILED} failed${RESET}, ${TESTS_PASSED} passed of ${TESTS_RUN}${skipped}"
    for f in ${FAILURES[@]+"${FAILURES[@]}"}; do echo "  - $f"; done
    exit 1
fi
echo -e "${GREEN}all ${TESTS_PASSED} passed${RESET}${skipped}"
