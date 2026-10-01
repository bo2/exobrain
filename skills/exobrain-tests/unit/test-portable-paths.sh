#!/usr/bin/env bash
# test-portable-paths.sh — the machine-specific-path check in
# validate-exobrain.sh (AGENTS.md § Conventions: no absolute /Users/<someone>/ or
# /home/<someone>/ paths outside host scope, because global and person scopes are
# shared across machines).
#
#   skills/exobrain-tests/unit/test-portable-paths.sh            # run all
#   skills/exobrain-tests/unit/test-portable-paths.sh <pattern>  # filter by name
#
# The rule is scoped to files CHANGED against the default branch, so each test
# builds a real git repo in a temp dir with a commit to diff against, rather than
# reading the live tree.

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

assert_contains()     { [[ "$1" == *"$2"* ]] || { echo "ASSERT_CONTAINS${3:+ ($3)}: '$2' not in output"; echo "$1"; return 1; }; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || { echo "ASSERT_NOT_CONTAINS${3:+ ($3)}: '$2' present in output"; echo "$1"; return 1; }; }

# ---------------------------------------------------------------------------
# A minimal exobrain with a git history, so the "changed against the default
# branch" scoping has something to diff. The validator needs the registries it
# reads to exist; everything else is the file under test.
# ---------------------------------------------------------------------------

make_repo() {
    cd "$TEST_DIR" || return 1
    git init -q -b main .
    git config user.email t@example.com
    git config user.name t
    mkdir -p scripts workspaces/2026/09/x
    cp "$SCRIPTS_DIR/validate-exobrain.sh" scripts/
    printf '# Exobrain\n' > AGENTS.md
    printf '{"collections":{"hosts":{"kind":"host"}}}\n' > scopes.json
    printf '{"skills":[]}\n' > skills.json
    git add -A && git commit -qm base
    # The check is scoped to files changed against the default branch, which the
    # validator resolves from origin. Without this ref the whole block is skipped
    # and every negative assertion below is vacuous; the two positive tests guard
    # against that.
    git update-ref refs/remotes/origin/main HEAD
}

# `record` prints one line per violation; the check names the file and line.
check() { bash scripts/validate-exobrain.sh 2>&1; }

# The fixtures are assembled rather than spelled out: a file that spells a
# machine-specific path is one, and this harness would fail the gate it tests.
U=Users
H=home

test_absolute_path_is_caught() {
    make_repo || return 1
    printf 'The dump lives at /%s/someone/dev/dumps/x.sql on that box.\n' "$U" \
        > workspaces/2026/09/x/README.md
    git add -A && git commit -qm change
    local out; out="$(check)"
    assert_contains "$out" "machine-specific path" "an absolute /Users path must be caught" || return 1
}

test_home_absolute_path_is_caught() {
    make_repo || return 1
    printf 'Deployed from /%s/someone/stack on the prod host.\n' "$H" \
        > workspaces/2026/09/x/README.md
    git add -A && git commit -qm change
    local out; out="$(check)"
    assert_contains "$out" "machine-specific path" "an absolute /home path must be caught" || return 1
}

test_relative_path_through_a_home_directory_is_not_caught() {
    # Without a leading boundary the pattern matches the tail of any relative
    # path whose second-to-last segment is named "home" or "Users" — ordinary
    # directory names.
    make_repo || return 1
    cat > workspaces/2026/09/x/README.md <<'EOF'
The sweep is in `apps/web/src/components/home/Sidebar.tsx:120`, and the queue's
copy in `src/components/home/queue/QueuePanel.tsx:102`. See also
`src/components/Users/Profile.tsx` for the same shape with the other segment.
EOF
    git add -A && git commit -qm change
    local out; out="$(check)"
    assert_not_contains "$out" "machine-specific path" "a relative path through home/ is portable" || return 1
}

test_placeholder_form_is_not_caught() {
    # Documented exemption: "<" is not a path character, so a placeholder is not
    # a machine-specific path.
    make_repo || return 1
    printf 'Put it under /Users/<name>/dev/ on your own machine.\n' \
        > workspaces/2026/09/x/README.md
    git add -A && git commit -qm change
    local out; out="$(check)"
    assert_not_contains "$out" "machine-specific path" "a placeholder is not a real path" || return 1
}

test_host_scope_is_exempt() {
    # Host scope is exactly where such a path belongs.
    make_repo || return 1
    mkdir -p people/x/hosts/mac
    printf 'The checkout is at /%s/someone/dev/app.\n' "$U" > people/x/hosts/mac/AGENTS.md
    git add -A && git commit -qm change
    local out; out="$(check)"
    assert_not_contains "$out" "machine-specific path" "host scope may carry absolute paths" || return 1
}

echo -e "\n${BOLD}portable paths — validate-exobrain.sh${RESET}\n"
run_test "an absolute /Users path is caught"            test_absolute_path_is_caught
run_test "an absolute /home path is caught"             test_home_absolute_path_is_caught
run_test "a relative path through home/ is not"         test_relative_path_through_a_home_directory_is_not_caught
run_test "a /Users/<name>/ placeholder is not"          test_placeholder_form_is_not_caught
run_test "host scope is exempt"                         test_host_scope_is_exempt

echo
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}${TESTS_FAILED} failed${RESET}, ${TESTS_PASSED} passed of ${TESTS_RUN}"
    for f in ${FAILURES[@]+"${FAILURES[@]}"}; do echo "  - $f"; done
    exit 1
fi
echo -e "${GREEN}all ${TESTS_PASSED} passed${RESET}"
