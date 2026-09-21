#!/usr/bin/env bash
# test-skills-status.sh — scripts/skills-status.sh --all, the repo-wide catalog of
# declared skills: every column lands under its own heading whatever fields a
# declaration leaves out, and an external declaration reads as external.
#
#   skills/exobrain-tests/unit/test-skills-status.sh            # run all
#   skills/exobrain-tests/unit/test-skills-status.sh <pattern>  # filter by name

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

assert_eq() { [[ "$1" == "$2" ]] || { echo "ASSERT_EQ${3:+ ($3)}: expected '$1', got '$2'"; return 1; }; }

# A catalog with one declaration of each shape: owned and forced, owner-less, and
# owner-less external.
make_repo() {
    cd "$TEST_DIR" || return 1
    mkdir -p scripts skills/owned skills/noowner
    cp "$SCRIPTS_DIR/skills-status.sh" "$SCRIPTS_DIR/skills-registry.sh" scripts/
    printf '{"collections":{"people":{"kind":"person"}}}\n' > scopes.json
    cat > skills.json <<'J'
{"skills":[
 {"name":"owned","owner":"alice","tier":"always","force":true},
 {"name":"noowner","tier":"optional"},
 {"name":"extnoowner","tier":"optional","source":{"repo":"r","path":"p","ref":"v1"}}
]}
J
    printf -- '---\nname: owned\ndescription: Owned skill.\n---\n' > skills/owned/SKILL.md
    printf -- '---\nname: noowner\ndescription: Nobody owns it.\n---\n' > skills/noowner/SKILL.md
}

# row NAME — that skill's catalog row: name, scope, owner, tier, force, description.
row() { bash scripts/skills-status.sh --all 2>/dev/null | awk -v n="$1" '$1 == n'; }
cols() { row "$1" | awk '{print $1, $2, $3, $4, $5}'; }

# ---------------------------------------------------------------------------

test_owned_declaration_columns() {
    make_repo || return 1
    assert_eq "owned global alice always force" "$(cols owned)" || return 1
    [[ "$(row owned)" == *"Owned skill."* ]] || { echo "description missing: $(row owned)"; return 1; }
}

# An empty owner between two fields is the case a tab-split read collapses,
# moving the tier under OWNER and the force flag under TIER.
test_ownerless_declaration_columns() {
    make_repo || return 1
    assert_eq "noowner global - optional -" "$(cols noowner)" || return 1
    [[ "$(row noowner)" == *"Nobody owns it."* ]] || { echo "description missing: $(row noowner)"; return 1; }
}

test_ownerless_external_reads_as_external() {
    make_repo || return 1
    assert_eq "extnoowner global - optional -" "$(cols extnoowner)" || return 1
    [[ "$(row extnoowner)" == *"(external)"* ]] || { echo "not marked external: $(row extnoowner)"; return 1; }
}

# ---------------------------------------------------------------------------

echo
printf "${BOLD}skills-status --all${RESET}\n"
run_test "an owned declaration's columns"               test_owned_declaration_columns
run_test "an owner-less declaration's columns"          test_ownerless_declaration_columns
run_test "an owner-less external reads as external"     test_ownerless_external_reads_as_external

echo
if [[ $TESTS_FAILED -eq 0 ]]; then
    printf "${GREEN}${BOLD}%d/%d passed${RESET}\n" "$TESTS_PASSED" "$TESTS_RUN"
    exit 0
fi
printf "${RED}${BOLD}%d/%d failed${RESET}:\n" "$TESTS_FAILED" "$TESTS_RUN"
for f in ${FAILURES[@]+"${FAILURES[@]}"}; do printf "  ${RED}- %s${RESET}\n" "$f"; done
exit 1
