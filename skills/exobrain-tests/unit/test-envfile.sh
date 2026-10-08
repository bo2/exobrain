#!/usr/bin/env bash
# test-envfile.sh — scripts/envfile.py, the one reader/writer of .env the credential
# scripts share: a save replaces the file atomically (a failure leaves the old file
# whole and no temporary behind), under a lock (concurrent savers lose nothing),
# keeps the other lines and the mode, follows a symlinked .env to the real file —
# and no script under scripts/ writes .env on its own any more.
#
#   skills/exobrain-tests/unit/test-envfile.sh            # run all
#   skills/exobrain-tests/unit/test-envfile.sh <pattern>  # filter by name
#
# Every test works on a fixture file in a temp dir; the real .env is never touched.

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

assert_eq()       { [[ "$1" == "$2" ]] || { echo "ASSERT_EQ${3:+ ($3)}: expected '$1', got '$2'"; return 1; }; }
assert_contains() { [[ "$1" == *"$2"* ]] || { echo "ASSERT_CONTAINS${3:+ ($3)}: '$2' not in output"; echo "$1"; return 1; }; }

# py <code> — run Python with scripts/ importable and $ENVF the fixture path.
py() { ENVF="$TEST_DIR/.env" PYTHONPATH="$SCRIPTS_DIR" python3 -c "$1"; }

seed() { printf '# comment\nA=1\nB=two words\n\nC=3\n' > "$TEST_DIR/.env"; chmod 600 "$TEST_DIR/.env"; }

test_load_and_save_keep_the_rest() {
    seed
    py 'import os, envfile
env = envfile.load(os.environ["ENVF"]); assert env == {"A": "1", "B": "two words", "C": "3"}, env
envfile.save("B", "changed", os.environ["ENVF"])
envfile.save("D", "new", os.environ["ENVF"])' || return 1
    assert_eq $'# comment\nA=1\nB=changed\n\nC=3\nD=new' "$(cat "$TEST_DIR/.env")" "replaced in place, appended at the end, comments and blanks kept" || return 1
    assert_eq "600" "$(stat -f %Lp "$TEST_DIR/.env" 2>/dev/null || stat -c %a "$TEST_DIR/.env")" "mode kept" || return 1
    [[ -z "$(ls -A "$TEST_DIR" | grep -v '^\.env$' | grep -v '^\.env\.lock$')" ]] || { echo "temporary left behind: $(ls -A "$TEST_DIR")"; return 1; }
}

test_missing_file_is_created_private() {
    py 'import os, envfile
assert envfile.load(os.environ["ENVF"]) == {}
envfile.save("T", "v", os.environ["ENVF"])' || return 1
    assert_eq "T=v" "$(cat "$TEST_DIR/.env")" || return 1
    assert_eq "600" "$(stat -f %Lp "$TEST_DIR/.env" 2>/dev/null || stat -c %a "$TEST_DIR/.env")" "a new file is private" || return 1
}

test_failed_replace_leaves_the_old_file_whole() {
    seed
    py 'import os, envfile
real = os.replace
def boom(a, b): raise OSError("disk full")
os.replace = boom
try:
    envfile.save("B", "changed", os.environ["ENVF"])
except OSError as e:
    assert "disk full" in str(e)
else:
    raise SystemExit("save should have raised")' || return 1
    assert_eq $'# comment\nA=1\nB=two words\n\nC=3' "$(cat "$TEST_DIR/.env")" "the old file is untouched" || return 1
    [[ -z "$(ls -A "$TEST_DIR" | grep -v '^\.env$' | grep -v '^\.env\.lock$')" ]] || { echo "temporary left behind: $(ls -A "$TEST_DIR")"; return 1; }
}

test_concurrent_savers_lose_nothing() {
    seed
    local i pids=()
    for i in $(seq 1 12); do
        py "import os, envfile
envfile.save('K$i', 'v$i', os.environ['ENVF'])" & pids+=($!)
    done
    for i in ${pids[@]+"${pids[@]}"}; do wait "$i" || return 1; done
    local out; out="$(cat "$TEST_DIR/.env")"
    for i in $(seq 1 12); do assert_contains "$out" "K$i=v$i" "saver $i's line survived" || return 1; done
    assert_contains "$out" "B=two words" "the seed survived" || return 1
}

test_symlinked_env_updates_the_target() {
    seed
    mkdir -p "$TEST_DIR/wt"
    ln -s "$TEST_DIR/.env" "$TEST_DIR/wt/.env"
    ENVF="$TEST_DIR/wt/.env" PYTHONPATH="$SCRIPTS_DIR" python3 -c 'import os, envfile; envfile.save("A", "9", os.environ["ENVF"])' || return 1
    [[ -L "$TEST_DIR/wt/.env" ]] || { echo "the symlink was replaced by a file"; return 1; }
    assert_contains "$(cat "$TEST_DIR/.env")" "A=9" "the real file holds the change" || return 1
    [[ ! -e "$TEST_DIR/wt/.env.lock" ]] || { echo "the lock went beside the link, not the file"; return 1; }
}

# Every Python script under scripts/ that writes .env goes through the module.
test_no_script_writes_env_on_its_own() {
    local hits
    hits="$(grep -ln 'open(ENV, "w")\|open(ENV,"w")\|def save_env' "$SCRIPTS_DIR"/*.py 2>/dev/null | grep -v '/envfile.py$' || true)"
    [[ -z "$hits" ]] || { echo "scripts still writing .env themselves:"; echo "$hits"; return 1; }
}

echo -e "\n${BOLD}envfile — scripts/envfile.py${RESET}\n"
run_test "load, then save: replaced, appended, rest kept, mode kept" test_load_and_save_keep_the_rest
run_test "a missing file is created private"                          test_missing_file_is_created_private
run_test "a failed replace leaves the old file whole"                 test_failed_replace_leaves_the_old_file_whole
run_test "concurrent savers lose nothing"                             test_concurrent_savers_lose_nothing
run_test "a symlinked .env updates the real file"                     test_symlinked_env_updates_the_target
run_test "no script writes .env on its own"                           test_no_script_writes_env_on_its_own

echo
if (( TESTS_FAILED > 0 )); then
    echo -e "${RED}${TESTS_FAILED} failed${RESET}, ${TESTS_PASSED} passed of ${TESTS_RUN}"
    for f in ${FAILURES[@]+"${FAILURES[@]}"}; do echo "  - $f"; done
    exit 1
fi
echo -e "${GREEN}all ${TESTS_PASSED} passed${RESET}"
