#!/usr/bin/env bash
# test-skills-validate.sh — scripts/skills-validate.sh: every error it raises
# (a declaration without its SKILL.md, an external declaration without a full
# source, an override naming no declaration — in-tree or external), undeclared
# skill directories reported as info, its exit codes, and the directories it
# never walks. Each test asserts the exact set of lines its fixture raises.
#
#   skills/exobrain-tests/unit/test-skills-validate.sh            # run all
#   skills/exobrain-tests/unit/test-skills-validate.sh <pattern>  # filter by name

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

# assert_lines <marker> <expected lines…> — the output lines carrying that marker
# (✗ for errors, • for info) are exactly these, in any order.
assert_lines() {
    local mark="$1"; shift
    local got want
    got="$(printf '%s\n' "$OUT" | grep -F -- "$mark" | sed 's/^ *//' | sort)"
    want="$(printf '%s\n' "$@" | sed '/^$/d' | sort)"
    [[ "$got" == "$want" ]] && return 0
    echo "lines marked '$mark' differ (< expected, > got):"
    diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/  /'
    return 1
}

make_repo() {
    cd "$TEST_DIR" || return 1
    mkdir -p scripts
    cp "$SCRIPTS_DIR/skills-validate.sh" "$SCRIPTS_DIR/skills-registry.sh" scripts/
    printf '{"collections":{"people":{"kind":"person"}}}\n' > scopes.json
    printf '{"skills":[]}\n' > skills.json
}

skill() { mkdir -p "$1" && printf -- '---\nname: x\n---\n' > "$1/SKILL.md"; }

# A registry broken every way the script can see: a dangling override, a
# declaration with no directory, and a skill directory nobody declares.
broken_registry() {
    mkdir -p "$1"
    printf '{"skills":[{"from":"global","name":"leak","tier":"always"},{"name":"nodir","owner":"bob","tier":"optional"}]}\n' > "$1/skills.json"
    skill "$1/skills/stray"
}

check() { OUT="$(bash scripts/skills-validate.sh "$@" 2>&1)"; RC=$?; }

# ---------------------------------------------------------------------------

test_every_error_kind() {
    make_repo || return 1
    cat > skills.json <<'J'
{"skills":[
 {"name":"ok","owner":"alice","tier":"optional"},
 {"name":"missing","owner":"alice","tier":"optional"},
 {"name":"extok","owner":"alice","tier":"optional","source":{"repo":"r","path":"p","ref":"v1"}},
 {"name":"extbad","owner":"alice","tier":"optional","source":{"repo":"r","path":"p"}}
]}
J
    skill skills/ok
    mkdir -p people/alice
    cat > people/alice/skills.json <<'J'
{"skills":[
 {"from":"global","name":"ok","tier":"always"},
 {"from":"global","name":"ghost","tier":"always"},
 {"from":"external","name":"extok","owner":"alice","tier":"always"},
 {"from":"external","name":"extnope","owner":"alice","tier":"always"}
]}
J
    check
    assert_eq 1 "$RC" "errors fail the run" || return 1
    assert_lines "✗" \
        "✗ MISSING: declaration 'missing' in global — expected skills/missing/SKILL.md" \
        "✗ MISSING SOURCE: external declaration 'extbad' in global lacks source.{repo,path,ref}" \
        "✗ DANGLING OVERRIDE: 'ghost' (from global) in people/alice — no declaration there" \
        "✗ DANGLING OVERRIDE: 'extnope' (from external, owner 'alice') in people/alice — no matching external declaration"
}

test_undeclared_dirs_are_info() {
    make_repo || return 1
    printf '{"skills":[{"name":"ok","owner":"alice","tier":"optional"}]}\n' > skills.json
    skill skills/ok; skill skills/orphan
    mkdir -p people/alice && printf '{"skills":[]}\n' > people/alice/skills.json
    skill people/alice/skills/orphan2
    check
    assert_eq 0 "$RC" "info alone passes" || return 1
    assert_lines "•" \
        "• undeclared: skills/orphan (available; no declaration → off for everyone)" \
        "• undeclared: people/alice/skills/orphan2 (available; no declaration → off for everyone)"
    check --strict
    assert_eq 1 "$RC" "--strict fails on info" || return 1
}

test_clean_registry_passes() {
    make_repo || return 1
    printf '{"skills":[{"name":"ok","owner":"alice","tier":"optional"}]}\n' > skills.json
    skill skills/ok
    check --strict
    assert_eq 0 "$RC" || return 1
    assert_lines "✗" "" || return 1
    assert_lines "•" ""
}

# The positive control for the exclusion test below: the same broken registry
# in an ordinary scope is reported in full, so an exclusion that passes is the
# prune working, not the check having stopped.
test_broken_registry_is_seen_in_a_normal_scope() {
    make_repo || return 1
    broken_registry people/bob
    check
    assert_lines "✗" \
        "✗ MISSING: declaration 'nodir' in people/bob — expected people/bob/skills/nodir/SKILL.md" \
        "✗ DANGLING OVERRIDE: 'leak' (from global) in people/bob — no declaration there" || return 1
    assert_lines "•" "• undeclared: people/bob/skills/stray (available; no declaration → off for everyone)"
}

# Linker output, clones, worktrees, seed tooling, agent runtime dirs and caches
# are never registry scopes; a broken registry in any of them is not reported.
test_excluded_dirs_are_never_walked() {
    make_repo || return 1
    local d
    for d in .claude .agents seed src/clone tmp/wt .worktrees/w .agent-worktrees/w \
             .agent-runs/r .agent-control/c node_modules/pkg knowledge/x/node_modules/pkg \
             workspaces/2026/09/x/_cache/dump scripts/__pycache__/p; do
        broken_registry "$d"
    done
    check --strict
    assert_eq 0 "$RC" "nothing under an excluded dir may fail the run" || return 1
    assert_lines "✗" "" || return 1
    assert_lines "•" ""
}

# The schema requires only name and tier, so a declaration may carry no owner —
# and the row it becomes then holds an empty field between two others, which a
# tab-split `read` collapses. It must be checked like any other.
test_ownerless_declaration_is_checked() {
    make_repo || return 1
    printf '{"skills":[{"name":"noowner","tier":"optional"}]}\n' > skills.json
    check
    assert_eq 1 "$RC" "a declaration missing its SKILL.md fails the run" || return 1
    assert_lines "✗" "✗ MISSING: declaration 'noowner' in global — expected skills/noowner/SKILL.md"
}

# ---------------------------------------------------------------------------

echo
printf "${BOLD}skills-validate${RESET}\n"
run_test "every error kind is reported"                 test_every_error_kind
run_test "undeclared dirs are info; --strict fails"     test_undeclared_dirs_are_info
run_test "a clean registry passes --strict"             test_clean_registry_passes
run_test "broken registry seen in a normal scope"       test_broken_registry_is_seen_in_a_normal_scope
run_test "excluded dirs are never walked"               test_excluded_dirs_are_never_walked
run_test "an owner-less declaration is checked"         test_ownerless_declaration_is_checked

echo
if [[ $TESTS_FAILED -eq 0 ]]; then
    printf "${GREEN}${BOLD}%d/%d passed${RESET}\n" "$TESTS_PASSED" "$TESTS_RUN"
    exit 0
fi
printf "${RED}${BOLD}%d/%d failed${RESET}:\n" "$TESTS_FAILED" "$TESTS_RUN"
for f in ${FAILURES[@]+"${FAILURES[@]}"}; do printf "  ${RED}- %s${RESET}\n" "$f"; done
exit 1
