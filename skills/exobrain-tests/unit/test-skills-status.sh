#!/usr/bin/env bash
# test-skills-status.sh — scripts/skills-status.sh --all, the repo-wide catalog of
# declared skills: every column lands under its own heading whatever fields a
# declaration leaves out, an external declaration reads as external, and the walk
# finds every scope wherever the checkout sits but never one in an excluded dir.
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

# make_repo [subdir] — a catalog with one declaration of each shape: owned and
# forced, owner-less, and owner-less external. With a subdir, the checkout sits
# that far below the test dir, so its absolute path can carry any segment.
make_repo() {
    mkdir -p "$TEST_DIR${1:+/$1}" && cd "$TEST_DIR${1:+/$1}" || return 1
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

# declare_in DIR NAME — a scope at DIR declaring one owned skill, with its SKILL.md.
declare_in() {
    mkdir -p "$1/skills/$2"
    printf '{"skills":[{"name":"%s","owner":"bob","tier":"optional"}]}\n' "$2" > "$1/skills.json"
    printf -- '---\nname: %s\ndescription: x\n---\n' "$2" > "$1/skills/$2/SKILL.md"
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

# A checkout that itself sits under a src/ directory: a '*/src/*' path filter matched
# every file beneath it and catalogued nothing; the walk must judge only the
# directories below the checkout.
test_catalog_from_a_checkout_under_src() {
    make_repo "src/exobrain" || return 1
    assert_eq "owned global alice always force" "$(cols owned)" || return 1
    assert_eq "noowner global - optional -" "$(cols noowner)" || return 1
}

# Clones, worktrees, vendored packages, git internals, seed tooling and caches are
# never registry scopes. The positive control shows the same declaration is
# catalogued from an ordinary scope.
test_excluded_dirs_are_not_catalogued() {
    make_repo || return 1
    declare_in people/bob visible
    local d
    for d in src/clone people/x/src/nested tmp/wt knowledge/y/tmp/z node_modules/pkg \
             .git/sub seed workspaces/2026/09/w/_cache/dump; do
        declare_in "$d" hidden
    done
    assert_eq "visible people/bob bob optional -" "$(cols visible)" "the ordinary scope is catalogued" || return 1
    [[ -z "$(row hidden)" ]] || { echo "catalogued from an excluded dir: $(row hidden)"; return 1; }
}

# ---------------------------------------------------------------------------

echo
printf "${BOLD}skills-status --all${RESET}\n"
run_test "an owned declaration's columns"               test_owned_declaration_columns
run_test "an owner-less declaration's columns"          test_ownerless_declaration_columns
run_test "an owner-less external reads as external"     test_ownerless_external_reads_as_external
run_test "catalog from a checkout under src/"          test_catalog_from_a_checkout_under_src
run_test "excluded dirs are not catalogued"            test_excluded_dirs_are_not_catalogued

echo
if [[ $TESTS_FAILED -eq 0 ]]; then
    printf "${GREEN}${BOLD}%d/%d passed${RESET}\n" "$TESTS_PASSED" "$TESTS_RUN"
    exit 0
fi
printf "${RED}${BOLD}%d/%d failed${RESET}:\n" "$TESTS_FAILED" "$TESTS_RUN"
for f in ${FAILURES[@]+"${FAILURES[@]}"}; do printf "  ${RED}- %s${RESET}\n" "$f"; done
exit 1
