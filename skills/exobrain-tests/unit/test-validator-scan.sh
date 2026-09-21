#!/usr/bin/env bash
# test-validator-scan.sh — find_repo's pruning in validate-exobrain.sh: bulk
# directories .gitignore excludes are never walked. Every whole-tree check calls
# find_repo, so one unpruned cache multiplies across all of them; a checkout whose
# workspaces held 18k cached files took the validator — and every pre-push —
# from seconds to over a minute and a half.
#
#   skills/exobrain-tests/unit/test-validator-scan.sh            # run all
#   skills/exobrain-tests/unit/test-validator-scan.sh <pattern>  # filter by name
#
# The probe is the bash-4 portability check, a whole-tree find_repo scan: a
# construct it flags anywhere it looks. Each "pruned" test has a sibling proving
# the same file IS flagged outside the pruned directory, so a silently disabled
# check cannot pass them.

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

make_repo() {
    cd "$TEST_DIR" || return 1
    git init -q -b main .
    git config user.email t@example.com
    git config user.name t
    mkdir -p scripts
    cp "$SCRIPTS_DIR/validate-exobrain.sh" scripts/
    printf '# Exobrain\n' > AGENTS.md
    printf '{"collections":{"hosts":{"kind":"host"}}}\n' > scopes.json
    printf '{"skills":[]}\n' > skills.json
    git add -A && git commit -qm base
    git update-ref refs/remotes/origin/main HEAD
}

check() { bash scripts/validate-exobrain.sh 2>&1; }

# A script the bash-4 check flags. Assembled rather than spelled out: a harness
# that spelled the construct would be flagged by the gate it is testing.
D=declare
bash4_script() {
    mkdir -p "$(dirname "$1")"
    printf '#!/usr/bin/env bash\n%s -A seen\n' "$D" > "$1"
}

# ---------------------------------------------------------------------------

test_flagged_outside_a_pruned_dir() {
    make_repo || return 1
    bash4_script workspaces/2026/09/x/tool.sh
    assert_contains "$(check)" "bash 4 construct in workspaces/2026/09/x/tool.sh" \
        "the probe must fire, or every pruned test below passes vacuously" || return 1
}

test_workspace_cache_is_pruned() {
    make_repo || return 1
    bash4_script workspaces/2026/09/x/_cache/export/tool.sh
    assert_not_contains "$(check)" "_cache" || return 1
}

test_cache_pruned_at_any_depth() {
    make_repo || return 1
    bash4_script knowledge/music/_cache/tool.sh
    bash4_script _cache/tool.sh
    assert_not_contains "$(check)" "_cache" || return 1
}

test_node_modules_and_pycache_are_pruned() {
    make_repo || return 1
    bash4_script workspaces/2026/09/x/node_modules/pkg/tool.sh
    bash4_script scripts/__pycache__/tool.sh
    local out; out="$(check)"
    assert_not_contains "$out" "node_modules" || return 1
    assert_not_contains "$out" "__pycache__" || return 1
}

# A directory merely named like a cache, one level off, is still scanned.
test_similar_names_are_still_scanned() {
    make_repo || return 1
    bash4_script workspaces/2026/09/x/cache/tool.sh
    bash4_script workspaces/2026/09/x/my_cache/tool.sh
    local out; out="$(check)"
    assert_contains "$out" "x/cache/tool.sh" || return 1
    assert_contains "$out" "x/my_cache/tool.sh" || return 1
}

# ---------------------------------------------------------------------------

echo
printf "${BOLD}validator scan — find_repo pruning${RESET}\n"
run_test "probe fires outside a pruned dir"             test_flagged_outside_a_pruned_dir
run_test "workspace _cache is pruned"                   test_workspace_cache_is_pruned
run_test "_cache pruned at any depth"                   test_cache_pruned_at_any_depth
run_test "node_modules and __pycache__ pruned"          test_node_modules_and_pycache_are_pruned
run_test "similar names are still scanned"              test_similar_names_are_still_scanned

echo
if [[ $TESTS_FAILED -eq 0 ]]; then
    printf "${GREEN}${BOLD}%d/%d passed${RESET}\n" "$TESTS_PASSED" "$TESTS_RUN"
    exit 0
fi
printf "${RED}${BOLD}%d/%d failed${RESET}:\n" "$TESTS_FAILED" "$TESTS_RUN"
for f in ${FAILURES[@]+"${FAILURES[@]}"}; do printf "  ${RED}- %s${RESET}\n" "$f"; done
exit 1
