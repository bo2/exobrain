#!/usr/bin/env bash
# test-script-syntax.sh — the script-syntax checks in validate-exobrain.sh: a
# changed shell script that does not parse under `bash -n`, or Python that does
# not compile, blocks the push. Scripts are recognised by shebang as well as
# extension, and a file in another shell's syntax is left alone.
#
#   skills/exobrain-tests/unit/test-script-syntax.sh            # run all
#   skills/exobrain-tests/unit/test-script-syntax.sh <pattern>  # filter by name
#
# The check is scoped to files CHANGED against the default branch, so each test
# builds a real git repo with a commit to diff against. The tests that expect a
# violation are what prove the check runs at all: without the default ref it is
# skipped, and every "left alone" test would pass vacuously.

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

# make_repo — a minimal exobrain with a default ref to diff against.
make_repo() {
    cd "$TEST_DIR" || return 1
    git init -q -b main .
    git config user.email t@example.com
    git config user.name t
    mkdir -p scripts stubs
    cp "$SCRIPTS_DIR/validate-exobrain.sh" scripts/
    printf '# Exobrain\n' > AGENTS.md
    printf '{"collections":{"hosts":{"kind":"host"}}}\n' > scopes.json
    printf '{"skills":[]}\n' > skills.json
    git add -A && git commit -qm base
    git update-ref refs/remotes/origin/main HEAD
}

commit() { git add -A && git commit -qm change; }
check()  { bash scripts/validate-exobrain.sh 2>&1; }

# The bug that motivated the check: an apostrophe inside a single-quoted string
# closes it early, and the rest of the line stops parsing.
write_broken() {
    printf '#!/usr/bin/env bash\nLIST='"'"'a|b|the brief'"'"'s backlog (x)'"'"'\necho "$LIST"\n' > "$1"
}

# ---------------------------------------------------------------------------

test_unparseable_script_is_caught() {
    make_repo || return 1
    write_broken scripts/run.sh; commit
    local out; out="$(check)"
    assert_contains "$out" "shell syntax error in scripts/run.sh:2" "names the file and line" || return 1
    assert_contains "$out" "syntax error near unexpected token" || return 1
}

test_extensionless_stub_is_caught() {
    make_repo || return 1
    write_broken stubs/curl; chmod +x stubs/curl; commit
    assert_contains "$(check)" "shell syntax error in stubs/curl" "a bash shebang makes it a script" || return 1
}

# A sourced library often carries no shebang; its .sh is what marks it shell.
test_sh_without_shebang_is_caught() {
    make_repo || return 1
    printf 'helper() {\n    echo "unterminated\n}\n' > scripts/lib.sh; commit
    assert_contains "$(check)" "shell syntax error in scripts/lib.sh" || return 1
}

test_valid_script_passes() {
    make_repo || return 1
    printf '#!/usr/bin/env bash\nset -euo pipefail\necho "fine"\n' > scripts/ok.sh; commit
    assert_not_contains "$(check)" "shell syntax error" || return 1
}

# zsh's short for-loop is valid zsh and a syntax error to bash; judging it by
# bash would be a false alarm.
test_other_shell_is_left_alone() {
    make_repo || return 1
    printf '#!/bin/zsh\nfor f (a b c) print $f\n' > scripts/zsh-tool.sh; commit
    assert_not_contains "$(check)" "shell syntax error" || return 1
}

test_non_shell_file_is_ignored() {
    make_repo || return 1
    printf '#!/usr/bin/env python3\nif True: print("(unbalanced\n' > stubs/tool
    printf 'Notes: if [ then fi ( unbalanced\n' > notes; commit
    assert_not_contains "$(check)" "shell syntax error" || return 1
}

# Diff-scoped like the path check: a script is judged when it changes, so one
# broken before the default branch was cut is not re-reported on every push.
test_unchanged_script_is_not_rechecked() {
    make_repo || return 1
    write_broken scripts/old.sh
    git add -A && git commit -qm "broken before the default ref" && git update-ref refs/remotes/origin/main HEAD
    printf 'unrelated\n' > notes; commit
    assert_not_contains "$(check)" "shell syntax error" || return 1
}

test_violation_fails_the_validator() {
    make_repo || return 1
    write_broken scripts/run.sh; commit
    bash scripts/validate-exobrain.sh >/dev/null 2>&1 && { echo "validator exited 0 on a broken script"; return 1; }
    return 0
}

# --- Python ---------------------------------------------------------------------

test_unparseable_python_is_caught() {
    make_repo || return 1
    printf 'import sys\n\ndef main(:\n    return 0\n' > scripts/tool.py; commit
    local out; out="$(check)"
    assert_contains "$out" "python syntax error in scripts/tool.py:3" "names the file and line" || return 1
}

# compile() rejects what a parse alone accepts; a `return` at module level parses
# but can never run.
test_python_compile_time_error_is_caught() {
    make_repo || return 1
    printf 'x = 1\nreturn x\n' > scripts/mod.py; commit
    assert_contains "$(check)" "python syntax error in scripts/mod.py:2" || return 1
}

test_python_shebang_without_extension_is_caught() {
    make_repo || return 1
    printf '#!/usr/bin/env python3\nprint("unclosed\n' > stubs/pytool; chmod +x stubs/pytool; commit
    assert_contains "$(check)" "python syntax error in stubs/pytool" || return 1
}

test_valid_python_passes() {
    make_repo || return 1
    printf 'def main():\n    return 0\n\nif __name__ == "__main__":\n    main()\n' > scripts/ok.py; commit
    assert_not_contains "$(check)" "python syntax error" || return 1
}

# The check must leave nothing behind in the tree it inspects.
test_python_check_writes_no_bytecode() {
    make_repo || return 1
    printf 'def main():\n    return 0\n' > scripts/ok.py; commit
    check >/dev/null
    [[ -z "$(find . -name '__pycache__' -o -name '*.pyc' | grep -v '^./.git/')" ]] \
        || { echo "bytecode written into the checkout"; return 1; }
}

test_unchanged_python_is_not_rechecked() {
    make_repo || return 1
    printf 'def main(:\n' > scripts/old.py
    git add -A && git commit -qm "broken before the default ref" && git update-ref refs/remotes/origin/main HEAD
    printf 'unrelated\n' > notes; commit
    assert_not_contains "$(check)" "python syntax error" || return 1
}

test_python_violation_fails_the_validator() {
    make_repo || return 1
    printf 'def main(:\n' > scripts/tool.py; commit
    bash scripts/validate-exobrain.sh >/dev/null 2>&1 && { echo "validator exited 0 on broken Python"; return 1; }
    return 0
}

# ---------------------------------------------------------------------------

echo
printf "${BOLD}script syntax — validate-exobrain.sh${RESET}\n"
run_test "unparseable script is caught"                 test_unparseable_script_is_caught
run_test "extensionless stub is caught"                 test_extensionless_stub_is_caught
run_test ".sh without a shebang is caught"              test_sh_without_shebang_is_caught
run_test "valid script passes"                          test_valid_script_passes
run_test "another shell is left alone"                  test_other_shell_is_left_alone
run_test "non-shell file is ignored"                    test_non_shell_file_is_ignored
run_test "unchanged script is not rechecked"            test_unchanged_script_is_not_rechecked
run_test "a violation fails the validator"              test_violation_fails_the_validator
run_test "python: unparseable file is caught"          test_unparseable_python_is_caught
run_test "python: compile-time error is caught"        test_python_compile_time_error_is_caught
run_test "python: shebang without .py is caught"       test_python_shebang_without_extension_is_caught
run_test "python: valid file passes"                   test_valid_python_passes
run_test "python: no bytecode written"                 test_python_check_writes_no_bytecode
run_test "python: unchanged file not rechecked"        test_unchanged_python_is_not_rechecked
run_test "python: a violation fails the validator"     test_python_violation_fails_the_validator

echo
if [[ $TESTS_FAILED -eq 0 ]]; then
    printf "${GREEN}${BOLD}%d/%d passed${RESET}\n" "$TESTS_PASSED" "$TESTS_RUN"
    exit 0
fi
printf "${RED}${BOLD}%d/%d failed${RESET}:\n" "$TESTS_FAILED" "$TESTS_RUN"
for f in ${FAILURES[@]+"${FAILURES[@]}"}; do printf "  ${RED}- %s${RESET}\n" "$f"; done
exit 1
