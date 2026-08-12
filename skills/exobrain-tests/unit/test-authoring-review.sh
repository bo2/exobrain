#!/usr/bin/env bash
# test-authoring-review.sh — tests for authoring-review.sh, focused on the LLM
# engine call. Exercises the framework script in <repo>/scripts/ of whichever
# instance this suite is installed in.
#
#   skills/exobrain-tests/unit/test-authoring-review.sh            # run all
#   skills/exobrain-tests/unit/test-authoring-review.sh <pattern>  # filter by name
#
# A fake engine on PATH records its own environment, so we can assert that an
# inherited SOCKS/HTTP proxy (some networks route git through one) is stripped
# before the model is invoked — without stripping it the engine can't reach its
# API and the review silently skips on every proxied push. Each test builds an
# isolated fake repo in a temp dir; nothing touches the real repo.

set -uo pipefail

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0; FAILURES=()
FILTER="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"          # .../exobrain-tests/unit
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"        # repo root: unit→exobrain-tests→skills→root
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
    mkdir -p "$repo/scripts" "$repo/knowledge/sample"
    cp "$SCRIPTS_DIR/authoring-review.sh" "$repo/scripts/"
    chmod +x "$repo/scripts/authoring-review.sh"
    git -C "$repo" init -q
    git -C "$repo" config user.email t@t.test; git -C "$repo" config user.name tester
    printf '# Sample\n\nBaseline line.\n' > "$repo/knowledge/sample/profile.md"
    git -C "$repo" add -A; git -C "$repo" commit -q -m base --no-gpg-sign
    git -C "$repo" branch base
    printf '# Sample\n\nBaseline line.\nAn added line under review.\n' > "$repo/knowledge/sample/profile.md"
    git -C "$repo" add -A; git -C "$repo" commit -q -m change --no-gpg-sign
    echo "$repo"
}

# declare_skills <repo> <name>... — write the global registry declaring each skill
# at a shared scope (global), force-shared so it reaches everyone in the chain.
declare_skills() {
    local repo="$1"; shift
    local nm rows=""
    for nm in "$@"; do
        [[ -n "$rows" ]] && rows="$rows,"
        rows="$rows { \"name\": \"$nm\", \"owner\": \"maintainer\", \"tier\": \"optional\", \"force\": true }"
    done
    printf '{ "skills": [%s ] }\n' "$rows" > "$repo/skills.json"
}

# write_skill <repo> <name> — a minimal SKILL.md carrying no proof artifact.
write_skill() {
    local repo="$1" nm="$2"
    mkdir -p "$repo/skills/$nm"
    printf -- '---\nname: %s\ndescription: "A demo skill for the proof gate."\n---\n\n# %s\n\nBody.\n' \
        "$nm" "$nm" > "$repo/skills/$nm/SKILL.md"
}

# setup_skill_repo — fake exobrain whose `base` branch declares one unproven shared
# skill (grandfathered, since the gate only looks at what BASE lacks). HEAD is left
# to the caller. Prints the repo path.
setup_skill_repo() {
    local repo="$TEST_DIR/skillrepo"
    mkdir -p "$repo/scripts"
    cp "$SCRIPTS_DIR/authoring-review.sh" "$repo/scripts/"
    chmod +x "$repo/scripts/authoring-review.sh"
    git -C "$repo" init -q
    git -C "$repo" config user.email t@t.test; git -C "$repo" config user.name tester
    write_skill "$repo" demo-alpha
    declare_skills "$repo" demo-alpha
    git -C "$repo" add -A; git -C "$repo" commit -q -m base --no-gpg-sign
    git -C "$repo" branch base
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
    o="$(run_review "$r" "knowledge/sample/profile.md: no ephemeral numbers -- drop the count." 2>&1)" && rc=0 || rc=$?
    assert_eq 1 "$rc" "violation exits 1" || return 1
    assert_contains "$o" "knowledge/sample/profile.md" "the finding is surfaced"
}

# The proof gate reads a registry name absent at BASE as a new shared skill. A
# rename presents exactly that, while changing nothing about the skill's reach —
# so it must pass, or renaming any shared skill becomes unlandable.
test_renamed_shared_skill_grandfathered() {
    local r; r="$(setup_skill_repo)"; make_fake_engine
    git -C "$r" mv skills/demo-alpha skills/demo-beta
    write_skill "$r" demo-beta
    declare_skills "$r" demo-beta
    git -C "$r" add -A; git -C "$r" commit -q -m rename --no-gpg-sign
    local o rc
    o="$(run_review "$r" "AUTHORING-OK" 2>&1)" && rc=0 || rc=$?
    assert_eq 0 "$rc" "a renamed shared skill does not trip the proof gate" || { echo "$o"; return 1; }
}

# The rename that rewords as it moves. A skill renamed *and* substantially
# rewritten leaves its SKILL.md below git's similarity threshold, so the one file
# that would prove the rename is exactly the one that fails to pair. A sibling
# file carried across is the same evidence, and the gate has to accept it —
# otherwise "rename a shared skill freely" holds only for renames that change
# nothing else.
test_reworded_rename_grandfathered() {
    local r; r="$(setup_skill_repo)"; make_fake_engine
    printf 'Shared reference text that pairs cleanly across the rename.\n' \
        > "$r/skills/demo-alpha/reference.md"
    git -C "$r" add -A; git -C "$r" commit -q -m sibling --no-gpg-sign
    git -C "$r" branch -f base HEAD

    git -C "$r" mv skills/demo-alpha skills/demo-beta
    # Rewrite the doc past recognition; only the sibling still pairs.
    printf -- '---\nname: demo-beta\ndescription: "Wholly different prose."\n---\n\n# demo-beta\n\n%s\n' \
        "$(for i in 1 2 3 4 5 6 7 8; do echo "Unrelated paragraph $i about something else entirely."; done)" \
        > "$r/skills/demo-beta/SKILL.md"
    declare_skills "$r" demo-beta
    git -C "$r" add -A; git -C "$r" commit -q -m rename --no-gpg-sign

    assert_eq "A" "$(git -C "$r" diff --name-status --find-renames base...HEAD -- '*SKILL.md' \
        | awk '$2 ~ /demo-beta/ {print substr($1,1,1)}')" \
        "fixture is honest: the SKILL.md itself does not pair" || return 1

    local o rc
    o="$(run_review "$r" "AUTHORING-OK" 2>&1)" && rc=0 || rc=$?
    assert_eq 0 "$rc" "a reworded rename is grandfathered via its sibling files" || { echo "$o"; return 1; }
}

# The counterpart guard: grandfathering a rename must not blunt the gate for a
# genuinely new, unproven shared skill.
test_new_shared_skill_still_blocked() {
    local r; r="$(setup_skill_repo)"; make_fake_engine
    write_skill "$r" demo-gamma
    declare_skills "$r" demo-alpha demo-gamma
    git -C "$r" add -A; git -C "$r" commit -q -m add --no-gpg-sign
    local o rc
    o="$(run_review "$r" "AUTHORING-OK" 2>&1)" && rc=0 || rc=$?
    assert_eq 2 "$rc" "an unproven new shared skill still blocks the land" || return 1
    assert_contains "$o" "demo-gamma" "the blocking skill is named"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

echo ""; echo "${BOLD}authoring-review.sh test suite${RESET}"; echo ""

run_test "proxy env stripped from engine call"  test_proxy_stripped_from_engine
run_test "reported violation exits non-zero"    test_violation_exits_nonzero
run_test "renamed shared skill grandfathered"   test_renamed_shared_skill_grandfathered
run_test "reworded rename grandfathered"        test_reworded_rename_grandfathered
run_test "new unproven shared skill blocked"    test_new_shared_skill_still_blocked

echo ""; echo "─────────────────────────────────────────────"
if [[ $TESTS_FAILED -eq 0 ]]; then
    printf "${GREEN}${BOLD}All %d tests passed${RESET}\n" "$TESTS_RUN"
else
    printf "${RED}${BOLD}%d of %d tests failed${RESET}\n" "$TESTS_FAILED" "$TESTS_RUN"
    printf '  - %s\n' "${FAILURES[@]}"
fi
echo "─────────────────────────────────────────────"
exit "$TESTS_FAILED"
