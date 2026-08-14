#!/usr/bin/env bash
# test-seed-harvest.sh — tests for the seed-harvest helpers: instance-list
# resolution (lib/instances.sh), the candidate picker (pick.sh), and scan.sh's
# --list/--drift reporting.
#
#   seed/skills/seed-harvest/tests/test-seed-harvest.sh            # run all
#   seed/skills/seed-harvest/tests/test-seed-harvest.sh <pattern>  # filter by name
#
# Every test builds a fake seed and fake instances in a temp dir, so nothing
# reads the real tree and no test touches the network.

set -uo pipefail

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0; FAILURES=()
FILTER="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"          # .../seed-harvest/tests
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCAN="$SKILL_DIR/scripts/scan.sh"
PICK="$SKILL_DIR/scripts/pick.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; DIM='\033[0;90m'; BOLD='\033[1m'; RESET='\033[0m'

# shellcheck source=../scripts/lib/instances.sh
. "$SKILL_DIR/scripts/lib/instances.sh"

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

assert_eq()           { [[ "$1" == "$2" ]] || { echo "ASSERT_EQ${3:+ ($3)}: expected '$1', got '$2'"; return 1; }; }
assert_contains()     { [[ "$1" == *"$2"* ]] || { echo "ASSERT_CONTAINS${3:+ ($3)}: '$2' not in output"; echo "$1"; return 1; }; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || { echo "ASSERT_NOT_CONTAINS${3:+ ($3)}: '$2' present in output"; echo "$1"; return 1; }; }

# mk_exobrain <dir> — the minimum that reads as an exobrain checkout.
mk_exobrain() {
    mkdir -p "$1/scripts" "$1/skills" "$1/knowledge/exobrain" "$1/tools"
    printf '# spec\n' > "$1/AGENTS.md"
    printf '{}\n' > "$1/scopes.json"
    printf '# tools\n' > "$1/tools/README.md"
    printf '# propagation\n' > "$1/knowledge/exobrain/propagation.md"
    git -C "$1" init --quiet 2>/dev/null
    git -C "$1" add -A >/dev/null 2>&1
    git -C "$1" -c user.email=t@t -c user.name=t commit --quiet -m init >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# lib/instances.sh — entry classification
# ---------------------------------------------------------------------------

test_entry_kind_slug() { assert_eq "slug" "$(entry_kind 'acme/exobrain-alex')"; }
test_entry_kind_path() { assert_eq "path" "$(entry_kind '/srv/exo')"; }
test_entry_kind_rejects_bare()   { assert_eq "invalid" "$(entry_kind 'exobrain')"; }
test_entry_kind_rejects_deep()   { assert_eq "invalid" "$(entry_kind 'a/b/c')"; }
test_entry_kind_rejects_empty()  { assert_eq "invalid" "$(entry_kind '')"; }

test_entry_name_from_slug() { assert_eq "exobrain-alex" "$(entry_name 'acme/exobrain-alex')"; }
test_entry_name_from_path() { assert_eq "exo" "$(entry_name '/srv/exo/')"; }

test_slug_caches_under_src() {
    assert_eq "/seed/src/exobrain-alex" "$(entry_local_path /seed 'acme/exobrain-alex')"
}
test_path_entry_used_verbatim() {
    assert_eq "/srv/exo" "$(entry_local_path /seed '/srv/exo/')"
}
test_clone_url_only_for_slug() {
    assert_eq "https://github.com/acme/exobrain-alex.git" "$(entry_clone_url 'acme/exobrain-alex')"
    assert_eq "" "$(entry_clone_url '/srv/exo')"
}

# ---------------------------------------------------------------------------
# lib/instances.sh — config reading and checkout detection
# ---------------------------------------------------------------------------

test_read_instances_from_config() {
    printf '{"instances":["acme/one","/srv/two"],"agents":["claude"]}' > "$TEST_DIR/c.json"
    assert_eq "acme/one
/srv/two" "$(read_instances "$TEST_DIR/c.json")"
}
test_read_instances_missing_key_is_empty() {
    printf '{"agents":["claude"]}' > "$TEST_DIR/c.json"
    assert_eq "" "$(read_instances "$TEST_DIR/c.json")"
}
test_read_instances_missing_file_is_empty() {
    assert_eq "" "$(read_instances "$TEST_DIR/nope.json")"
}
test_read_instances_skips_non_strings() {
    printf '{"instances":["acme/one",null,42,""]}' > "$TEST_DIR/c.json"
    assert_eq "acme/one" "$(read_instances "$TEST_DIR/c.json")"
}

test_detects_exobrain_checkout() {
    mk_exobrain "$TEST_DIR/inst"
    is_exobrain_checkout "$TEST_DIR/inst" || { echo "should detect an exobrain"; return 1; }
}
test_rejects_non_exobrain_checkout() {
    mkdir -p "$TEST_DIR/plain"; printf 'x\n' > "$TEST_DIR/plain/README.md"
    is_exobrain_checkout "$TEST_DIR/plain" && { echo "should reject a plain repo"; return 1; }
    return 0
}
test_meta_dir_prefers_knowledge() {
    mk_exobrain "$TEST_DIR/inst"; mkdir -p "$TEST_DIR/inst/domains/exobrain"
    assert_eq "knowledge/exobrain" "$(instance_meta_dir "$TEST_DIR/inst")"
}
test_meta_dir_falls_back_to_domains() {
    mkdir -p "$TEST_DIR/old/domains/exobrain"
    assert_eq "domains/exobrain" "$(instance_meta_dir "$TEST_DIR/old")"
}

# ---------------------------------------------------------------------------
# pick.sh — the checkbox menu
# ---------------------------------------------------------------------------

pick_with() {   # pick_with <keystrokes-file> <candidates-file>
    SEED_HARVEST_INPUT="$1" "$PICK" "$2" 2>/dev/null
}

mk_candidates() {
    printf 'a\t1\tPrechecked candidate\nb\t0\tUnchecked candidate\nc\t0\tAnother one\n' > "$TEST_DIR/cand.tsv"
}

test_pick_accepts_prechecked_by_default() {
    mk_candidates; printf '\n' > "$TEST_DIR/keys"
    assert_eq "a" "$(pick_with "$TEST_DIR/keys" "$TEST_DIR/cand.tsv")"
}
test_pick_toggles_on() {
    mk_candidates; printf '2\n\n' > "$TEST_DIR/keys"
    assert_eq "a
b" "$(pick_with "$TEST_DIR/keys" "$TEST_DIR/cand.tsv")"
}
test_pick_toggles_off() {
    mk_candidates; printf '1\n\n' > "$TEST_DIR/keys"
    assert_eq "" "$(pick_with "$TEST_DIR/keys" "$TEST_DIR/cand.tsv")"
}
test_pick_select_all() {
    mk_candidates; printf 'a\n\n' > "$TEST_DIR/keys"
    assert_eq "a
b
c" "$(pick_with "$TEST_DIR/keys" "$TEST_DIR/cand.tsv")"
}
test_pick_select_none() {
    mk_candidates; printf 'n\n\n' > "$TEST_DIR/keys"
    assert_eq "" "$(pick_with "$TEST_DIR/keys" "$TEST_DIR/cand.tsv")"
}
test_pick_quit_aborts_nonzero() {
    mk_candidates; printf 'q\n' > "$TEST_DIR/keys"
    pick_with "$TEST_DIR/keys" "$TEST_DIR/cand.tsv" >/dev/null && { echo "q should exit non-zero"; return 1; }
    return 0
}
test_pick_ignores_bad_input() {
    mk_candidates; printf '99\nzzz\n2\n\n' > "$TEST_DIR/keys"
    assert_eq "a
b" "$(pick_with "$TEST_DIR/keys" "$TEST_DIR/cand.tsv")"
}
test_pick_headers_are_not_selectable() {
    printf '#Framework drift\ta\t\nx\t1\tOne\n' > "$TEST_DIR/cand.tsv"
    printf '\n' > "$TEST_DIR/keys"
    assert_eq "x" "$(pick_with "$TEST_DIR/keys" "$TEST_DIR/cand.tsv")"
}
test_pick_empty_candidates_errors() {
    : > "$TEST_DIR/cand.tsv"; printf '\n' > "$TEST_DIR/keys"
    pick_with "$TEST_DIR/keys" "$TEST_DIR/cand.tsv" >/dev/null && { echo "empty list should fail"; return 1; }
    return 0
}

# ---------------------------------------------------------------------------
# scan.sh — resolution and drift reporting
# ---------------------------------------------------------------------------

scan() {   # scan <mode> [arg]
    SEED_HARVEST_REPO="$TEST_DIR/seed" SEED_HARVEST_CONFIG="$TEST_DIR/seed/.exobrain.json" \
        "$SCAN" "$@" 2>&1
}

setup_seed() {
    mk_exobrain "$TEST_DIR/seed"
    printf '#!/bin/sh\necho hi\n' > "$TEST_DIR/seed/scripts/shared.sh"
}

test_scan_errors_without_instances() {
    setup_seed; printf '{"agents":[]}' > "$TEST_DIR/seed/.exobrain.json"
    local out; out="$(scan --list)"
    assert_contains "$out" "no instances configured"
}
test_scan_lists_local_path_entry() {
    setup_seed; mk_exobrain "$TEST_DIR/inst"
    printf '{"instances":["%s"]}' "$TEST_DIR/inst" > "$TEST_DIR/seed/.exobrain.json"
    local out; out="$(scan --list)"
    assert_contains "$out" "inst" && assert_contains "$out" "path" && assert_contains "$out" "clean"
}
test_scan_flags_dirty_checkout() {
    setup_seed; mk_exobrain "$TEST_DIR/inst"; printf 'edit\n' >> "$TEST_DIR/inst/AGENTS.md"
    printf '{"instances":["%s"]}' "$TEST_DIR/inst" > "$TEST_DIR/seed/.exobrain.json"
    assert_contains "$(scan --list)" "dirty"
}
test_scan_flags_absent_checkout() {
    setup_seed
    printf '{"instances":["/nonexistent/path/xyz"]}' > "$TEST_DIR/seed/.exobrain.json"
    assert_contains "$(scan --list)" "absent"
}
test_scan_flags_non_exobrain() {
    setup_seed; mkdir -p "$TEST_DIR/plain"; printf 'x\n' > "$TEST_DIR/plain/README.md"
    printf '{"instances":["%s"]}' "$TEST_DIR/plain" > "$TEST_DIR/seed/.exobrain.json"
    assert_contains "$(scan --list)" "not-an-exobrain"
}
test_scan_rejects_colliding_cache_paths() {
    setup_seed
    printf '{"instances":["one/exobrain-x","two/exobrain-x"]}' > "$TEST_DIR/seed/.exobrain.json"
    local out; out="$(scan --list)"
    assert_contains "$out" "resolve to the same local path"
}
test_scan_allows_distinct_names() {
    setup_seed
    printf '{"instances":["one/exobrain-a","two/exobrain-b"]}' > "$TEST_DIR/seed/.exobrain.json"
    assert_not_contains "$(scan --list)" "same local path"
}
test_scan_fetch_leaves_local_paths_untouched() {
    setup_seed; mk_exobrain "$TEST_DIR/inst"
    printf '{"instances":["%s"]}' "$TEST_DIR/inst" > "$TEST_DIR/seed/.exobrain.json"
    assert_contains "$(scan --fetch)" "left untouched"
}

test_drift_reports_changed_framework_file() {
    setup_seed; mk_exobrain "$TEST_DIR/inst"
    printf '# spec\nlocal improvement\n' > "$TEST_DIR/inst/AGENTS.md"
    printf '{"instances":["%s"]}' "$TEST_DIR/inst" > "$TEST_DIR/seed/.exobrain.json"
    assert_contains "$(scan --drift)" "differs	AGENTS.md"
}
test_drift_reports_instance_only_skill() {
    setup_seed; mk_exobrain "$TEST_DIR/inst"; mkdir -p "$TEST_DIR/inst/skills/triage-inbox"
    printf '{"instances":["%s"]}' "$TEST_DIR/inst" > "$TEST_DIR/seed/.exobrain.json"
    assert_contains "$(scan --drift)" "only-there	skills/triage-inbox"
}
test_drift_reports_instance_only_script() {
    setup_seed; mk_exobrain "$TEST_DIR/inst"; printf '#!/bin/sh\n' > "$TEST_DIR/inst/scripts/handy.sh"
    printf '{"instances":["%s"]}' "$TEST_DIR/inst" > "$TEST_DIR/seed/.exobrain.json"
    assert_contains "$(scan --drift)" "only-there	scripts/handy.sh"
}
test_drift_ignores_identical_files() {
    setup_seed; mk_exobrain "$TEST_DIR/inst"
    printf '{"instances":["%s"]}' "$TEST_DIR/inst" > "$TEST_DIR/seed/.exobrain.json"
    assert_not_contains "$(scan --drift)" "differs	AGENTS.md"
}
test_drift_maps_renamed_meta_dir() {
    setup_seed; mk_exobrain "$TEST_DIR/inst"
    rm -rf "$TEST_DIR/inst/knowledge"; mkdir -p "$TEST_DIR/inst/domains/exobrain"
    printf '# propagation\nolder wording\n' > "$TEST_DIR/inst/domains/exobrain/propagation.md"
    printf '{"instances":["%s"]}' "$TEST_DIR/inst" > "$TEST_DIR/seed/.exobrain.json"
    assert_contains "$(scan --drift)" "differs	domains/exobrain/propagation.md"
}
test_drift_marks_unavailable_checkout() {
    setup_seed
    printf '{"instances":["/nonexistent/path/xyz"]}' > "$TEST_DIR/seed/.exobrain.json"
    assert_contains "$(scan --drift)" "unavailable"
}
test_drift_filters_by_name() {
    setup_seed; mk_exobrain "$TEST_DIR/a"; mk_exobrain "$TEST_DIR/b"
    printf '# spec\nchanged\n' > "$TEST_DIR/b/AGENTS.md"
    printf '{"instances":["%s","%s"]}' "$TEST_DIR/a" "$TEST_DIR/b" > "$TEST_DIR/seed/.exobrain.json"
    local out; out="$(scan --drift b)"
    assert_contains "$out" "=== b" && assert_not_contains "$out" "=== a"
}

# ---------------------------------------------------------------------------

echo ""
echo -e "${BOLD}seed-harvest helpers${RESET}"
echo ""

for t in $(declare -F | awk '{print $3}' | grep '^test_' | sort); do
    run_test "${t#test_}" "$t"
done

echo ""
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}All $TESTS_PASSED tests passed${RESET}"
else
    echo -e "${RED}${BOLD}$TESTS_FAILED of $TESTS_RUN failed${RESET}"
    for f in ${FAILURES[@]+"${FAILURES[@]}"}; do echo "  - $f"; done
fi
echo ""
exit $(( TESTS_FAILED > 0 ? 1 : 0 ))
