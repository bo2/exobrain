#!/usr/bin/env bash
# test-behavior-runner.sh — tests for the behavior suite's runner
# (skills/exobrain-tests/behavior/run.sh): the record of what a run tested, which
# persist.sh reads to decide whether a spec change is verified, and --scope wiring.
#
#   skills/exobrain-tests/unit/test-behavior-runner.sh            # run all
#   skills/exobrain-tests/unit/test-behavior-runner.sh <pattern>  # filter by name
#
# Each test builds a fake instance in a temp dir carrying a copy of the runner, a
# stub validator, a stub connector that records how it was called, and cases whose
# checks always pass; `claude` is a fake on PATH that answers without a model. No
# agent, no network, no usage, nothing touches the real repo.

set -uo pipefail

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0; FAILURES=()
FILTER="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"          # .../exobrain-tests/unit
SUITE_DIR="$(cd "$SCRIPT_DIR/../behavior" && pwd)"    # the runner under test

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

assert_eq()       { [[ "$1" == "$2" ]] || { echo "ASSERT_EQ${3:+ ($3)}: expected '$1', got '$2'"; return 1; }; }
assert_contains() { [[ "$1" == *"$2"* ]] || { echo "ASSERT_CONTAINS${3:+ ($3)}: '$2' not in:"; echo "$1"; return 1; }; }

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

INST=""; FAKE_BIN=""; WIRED=""

# add_case <cases dir> <name> — a case whose check passes and notes which copy of the
# case ran, and whether the instance it checked was wired.
add_case() {
    local d="$1/$2"; mkdir -p "$d"
    printf '{"name":"%s","description":"%s at %s","runs":1,"permission_profile":"action","pass_threshold":"all","timeout_seconds":30}\n' \
        "$2" "$2" "$1" > "$d/meta.json"
    printf 'Say ok.\n' > "$d/prompt.md"
    cat > "$d/check.sh" <<EOF
#!/usr/bin/env bash
echo "$d wired=\$([[ -f "\$1/.claude/connected-scopes.md" ]] && echo yes || echo no)" >> "$TEST_DIR/checks"
exit 0
EOF
}

# setup_instance — a git repo with the runner, stub validator and connector, a
# person scope with a host below it, one global case and two scope cases (one of
# them shadowing the global case's name).
setup_instance() {
    INST="$TEST_DIR/inst"; WIRED="$TEST_DIR/wired"; : > "$WIRED"; : > "$TEST_DIR/checks"
    mkdir -p "$INST/skills/exobrain-tests/behavior/cases" "$INST/scripts" "$INST/people/p/hosts/h"
    cp -R "$SUITE_DIR/run.sh" "$SUITE_DIR/lib" "$SUITE_DIR/settings" "$INST/skills/exobrain-tests/behavior/"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$INST/scripts/validate-exobrain.sh"
    cat > "$INST/scripts/connect-agent.sh" <<EOF
#!/usr/bin/env bash
REPO="\$(cd "\$(dirname "\$0")/.." && pwd)"
echo "\$* | CODEX_HOME=\${CODEX_HOME:-} | \$(jq -c . "\$REPO/.exobrain.json")" >> "$WIRED"
mkdir -p "\$REPO/.claude"; echo wired > "\$REPO/.claude/connected-scopes.md"
EOF
    chmod +x "$INST/scripts/"*.sh
    printf '# Exobrain\n' > "$INST/AGENTS.md"
    printf '# p\n' > "$INST/people/p/AGENTS.md"
    printf '# h\n' > "$INST/people/p/hosts/h/AGENTS.md"
    add_case "$INST/skills/exobrain-tests/behavior/cases" global-case
    add_case "$INST/skills/exobrain-tests/behavior/cases" shadowed
    add_case "$INST/people/p/tests/behavior" person-case
    add_case "$INST/people/p/hosts/h/tests/behavior" shadowed
    chmod +x "$INST"/skills/exobrain-tests/behavior/cases/*/check.sh "$INST"/people/p/tests/behavior/*/check.sh \
             "$INST"/people/p/hosts/h/tests/behavior/*/check.sh
    printf 'tmp/\n.exobrain.json\n.claude/*\n.codex\n' > "$INST/.gitignore"
    printf '{"person":"pp","connected_scopes":["people/p/hosts/h"],"tools":{"x":1}}\n' > "$INST/.exobrain.json"
    git -C "$INST" init -q -b trunk
    git -C "$INST" -c user.email=t@t.test -c user.name=t add -A
    git -C "$INST" -c user.email=t@t.test -c user.name=t commit -q -m "Seed"

    FAKE_BIN="$TEST_DIR/bin"; mkdir -p "$FAKE_BIN"
    printf '#!/usr/bin/env bash\n[[ "${1:-}" == --version ]] && { echo fake; exit 0; }\ncat >/dev/null; echo ok\n' > "$FAKE_BIN/claude"
    chmod +x "$FAKE_BIN/claude"
}

# runner [args…] — the runner inside the fake instance, with the fake claude.
runner() { PATH="$FAKE_BIN:$PATH" "$INST/skills/exobrain-tests/behavior/run.sh" --agents claude "$@"; }

# summary — the newest run's summary.json.
summary() { cat "$(ls -d "$INST"/tmp/test-runs/*/ | sort | tail -1)summary.json"; }

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_run_records_what_it_tested() {
    setup_instance
    local out; out="$(runner --cases global-case 2>&1)" || { echo "$out"; return 1; }
    local s; s="$(summary)"
    assert_eq "$(git -C "$INST" rev-parse 'HEAD^{tree}')" "$(jq -r .tree <<< "$s")" "tree is HEAD's" || return 1
    assert_eq head "$(jq -r .source <<< "$s")" || return 1
    assert_eq '["claude"]' "$(jq -c .agents <<< "$s")" || return 1
    assert_eq '[]' "$(jq -c .scopes <<< "$s")" || return 1
    assert_eq false "$(jq -r .harness_error <<< "$s")" || return 1
    assert_eq true "$(jq -r .all_met <<< "$s")" || return 1
    assert_eq 'claude/global-case PASS action' "$(jq -r '.cases[0] | "\(.name) \(.verdict) \(.profile)"' <<< "$s")" || return 1
    assert_eq "" "$(cat "$WIRED")" "an unscoped run wires nothing"
}

test_working_tree_run_records_the_working_tree() {
    setup_instance
    printf '# Exobrain, uncommitted\n' > "$INST/AGENTS.md"
    runner --working-tree --cases global-case >/dev/null 2>&1 || return 1
    local tree idx; idx="$(mktemp)"; rm -f "$idx"
    tree="$(GIT_INDEX_FILE="$idx" git -C "$INST" add -A && GIT_INDEX_FILE="$idx" git -C "$INST" write-tree)"; rm -f "$idx"
    assert_eq "$tree" "$(summary | jq -r .tree)" "tree is the working tree's" || return 1
    assert_eq working-tree "$(summary | jq -r .source)" || return 1
    [[ "$tree" != "$(git -C "$INST" rev-parse 'HEAD^{tree}')" ]] || { echo "the edit did not change the tree"; return 1; }
    assert_eq " M AGENTS.md" "$(git -C "$INST" status --porcelain)" "the staging area was never touched"
}

test_scope_wires_every_copy_and_records_the_leaf() {
    setup_instance
    local out; out="$(runner --scope ./people/p/hosts/h/ --cases global-case,person-case 2>&1)" || { echo "$out"; return 1; }
    assert_eq '["people/p/hosts/h"]' "$(summary | jq -c .scopes)" "the leaf, normalized" || return 1
    assert_eq 2 "$(wc -l < "$WIRED" | tr -d ' ')" "one wiring per run copy" || return 1
    assert_contains "$(head -1 "$WIRED")" "claude --wire-sandbox | CODEX_HOME=" || return 1
    assert_contains "$(head -1 "$WIRED")" '"connected_scopes":["people/p/hosts/h"],"person":"pp"}' \
        "the leaf and this checkout's person, nothing else from its config" || return 1
    assert_contains "$(cat "$TEST_DIR/checks")" "person-case wired=yes" || return 1
    assert_contains "$(cat "$TEST_DIR/checks")" "global-case wired=yes"
}

test_scope_adds_its_chain_cases_innermost_wins() {
    setup_instance
    local out; out="$(runner --list 2>&1)"
    [[ "$out" != *person-case* ]] || { echo "an unwired listing shows scope cases"; return 1; }
    out="$(runner --scope people/p/hosts/h --list 2>&1)"
    assert_contains "$out" "[people/p/tests/behavior/person-case]" || return 1
    assert_contains "$out" "[people/p/hosts/h/tests/behavior/shadowed]" "the host's case shadows the global one" || return 1
    runner --scope people/p/hosts/h --cases shadowed >/dev/null 2>&1 || return 1
    assert_contains "$(cat "$TEST_DIR/checks")" "people/p/hosts/h/tests/behavior/shadowed wired=yes"
}

test_unknown_scope_is_a_harness_error() {
    setup_instance
    local out; out="$(runner --scope people/nope --cases global-case 2>&1)"; local rc=$?
    assert_eq 2 "$rc" "exit code" || return 1
    assert_contains "$out" "not a scope in this checkout"
}

test_missing_case_is_recorded_as_a_harness_error() {
    setup_instance
    runner --cases global-case,no-such-case >/dev/null 2>&1; local rc=$?
    assert_eq 2 "$rc" "exit code" || return 1
    assert_eq true "$(summary | jq -r .harness_error)"
}

# ---------------------------------------------------------------------------

command -v jq >/dev/null || { echo "jq not on PATH" >&2; exit 2; }

run_test run_records_what_it_tested                 test_run_records_what_it_tested
run_test working_tree_run_records_the_working_tree  test_working_tree_run_records_the_working_tree
run_test scope_wires_every_copy_and_records_the_leaf test_scope_wires_every_copy_and_records_the_leaf
run_test scope_adds_its_chain_cases_innermost_wins  test_scope_adds_its_chain_cases_innermost_wins
run_test unknown_scope_is_a_harness_error           test_unknown_scope_is_a_harness_error
run_test missing_case_is_recorded_as_a_harness_error test_missing_case_is_recorded_as_a_harness_error

echo ""
if [[ $TESTS_FAILED -gt 0 ]]; then
    printf "${RED}%d/%d failed${RESET}: %s\n" "$TESTS_FAILED" "$TESTS_RUN" ${FAILURES[*]+"${FAILURES[*]}"}
    exit 1
fi
printf "${GREEN}%d/%d passed${RESET}\n" "$TESTS_PASSED" "$TESTS_RUN"
