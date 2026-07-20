#!/usr/bin/env bash
# test-authoring-review.sh — tests for authoring-review.sh, focused on the LLM
# engine call. Seed-local (lives under seed-tests); it exercises the framework
# script in <repo>/scripts/.
#
#   seed/skills/seed-tests/scripts/test-authoring-review.sh            # run all
#   seed/skills/seed-tests/scripts/test-authoring-review.sh <pattern>  # filter by name
#
# A fake engine on PATH records its own environment, so we can assert that an
# inherited SOCKS/HTTP proxy (some networks route git through one) is stripped
# before the model is invoked — without stripping it the engine can't reach its
# API and the review silently skips on every proxied push. Each test builds an
# isolated fake repo in a temp dir; nothing touches the real repo.

set -uo pipefail

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0; FAILURES=()
FILTER="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"          # .../seed-tests/scripts
REPO_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"     # <repo> — the seed
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

assert_eq()       { [[ "$1" == "$2" ]] || { echo "ASSERT_EQ${3:+ ($3)}: expected '$1', got '$2'"; return 1; }; }
assert_contains() { [[ "$1" == *"$2"* ]] || { echo "ASSERT_CONTAINS${3:+ ($3)}: '$2' not in output"; echo "$1"; return 1; }; }
assert_file()     { [[ -e "$1" ]] || { echo "ASSERT_FILE${2:+ ($2)}: $1 missing"; return 1; }; }

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

FAKE_BIN=""; FAKE_REC=""

# setup_repo — fake exobrain with the real authoring-review.sh, a `base` branch,
# and a changed in-scope domain file on HEAD. Prints the repo path.
setup_repo() {
    local repo="$TEST_DIR/exobrain"
    mkdir -p "$repo/scripts" "$repo/domains/sample"
    cp "$SCRIPTS_DIR/authoring-review.sh" "$repo/scripts/"
    chmod +x "$repo/scripts/authoring-review.sh"
    git -C "$repo" init -q
    git -C "$repo" config user.email t@t.test; git -C "$repo" config user.name tester
    printf '# Sample\n\nBaseline line.\n' > "$repo/domains/sample/profile.md"
    git -C "$repo" add -A; git -C "$repo" commit -q -m base --no-gpg-sign
    git -C "$repo" branch base
    printf '# Sample\n\nBaseline line.\nAn added line under review.\n' > "$repo/domains/sample/profile.md"
    git -C "$repo" add -A; git -C "$repo" commit -q -m change --no-gpg-sign
    echo "$repo"
}

# make_fake_engine — install a fake `claude` on PATH that records any proxy env
# it sees, drains the prompt, and prints $FAKE_OUT (the canned model verdict).
make_fake_engine() {
    FAKE_BIN="$TEST_DIR/bin"; FAKE_REC="$TEST_DIR/engine-env.txt"
    mkdir -p "$FAKE_BIN"
    cat > "$FAKE_BIN/claude" <<EOF
#!/usr/bin/env bash
env | grep -iE '^(all_proxy|https?_proxy)=' > "$FAKE_REC" 2>/dev/null || true
cat >/dev/null 2>&1 || true
printf '%s\n' "\${FAKE_OUT:-AUTHORING-OK}"
EOF
    chmod +x "$FAKE_BIN/claude"
}

# run_review <repo> <verdict> — run authoring-review against `base` with the fake
# engine on PATH and a proxy env set (as an inherited proxied push leaves it).
run_review() {
    local repo="$1" verdict="$2"
    ( cd "$repo" && PATH="$FAKE_BIN:$PATH" FAKE_OUT="$verdict" \
        ALL_PROXY=socks5h://127.0.0.1:8080 HTTPS_PROXY=socks5h://127.0.0.1:8080 \
        bash scripts/authoring-review.sh base )
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

# The core regression guard: the engine must run with the inherited proxy env
# stripped (else it can't reach its API and the review silently skips).
test_proxy_stripped_from_engine() {
    local r; r="$(setup_repo)"; make_fake_engine
    local rc; run_review "$r" "AUTHORING-OK" >/dev/null; rc=$?
    assert_eq 0 "$rc" "clean review exits 0" || return 1
    assert_file "$FAKE_REC" "engine was actually invoked" || return 1
    assert_eq "" "$(cat "$FAKE_REC")" "no proxy env reached the engine"
}

# The verdict path: a reported violation exits non-zero with the finding shown.
test_violation_exits_nonzero() {
    local r; r="$(setup_repo)"; make_fake_engine
    local o rc
    o="$(run_review "$r" "domains/sample/profile.md: no ephemeral numbers -- drop the count." 2>&1)" && rc=0 || rc=$?
    assert_eq 1 "$rc" "violation exits 1" || return 1
    assert_contains "$o" "domains/sample/profile.md" "the finding is surfaced"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

echo ""; echo "${BOLD}authoring-review.sh test suite${RESET}"; echo ""

run_test "proxy env stripped from engine call"  test_proxy_stripped_from_engine
run_test "reported violation exits non-zero"    test_violation_exits_nonzero

echo ""; echo "─────────────────────────────────────────────"
if [[ $TESTS_FAILED -eq 0 ]]; then
    printf "${GREEN}${BOLD}All %d tests passed${RESET}\n" "$TESTS_RUN"
else
    printf "${RED}${BOLD}%d of %d tests failed${RESET}\n" "$TESTS_FAILED" "$TESTS_RUN"
    printf '  - %s\n' "${FAILURES[@]}"
fi
echo "─────────────────────────────────────────────"
exit "$TESTS_FAILED"
