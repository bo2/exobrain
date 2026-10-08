#!/usr/bin/env bash
# test-security-findings.sh — tests for scripts/security-findings.py: recording a
# finding at the root or in a scope, accepting, reopening and closing one, the
# review stamp, what the summary flags and its exit code, every registry error
# --check raises, and the two gates that read it: the validator (shape) and the
# healthcheck (what needs a person). Hermetic: every test builds a fake repo and
# pins "today".
#
#   skills/exobrain-tests/unit/test-security-findings.sh            # run all
#   skills/exobrain-tests/unit/test-security-findings.sh <pattern>  # filter by name

set -uo pipefail

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0; FAILURES=()
FILTER="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

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

assert_eq()           { [[ "$1" == "$2" ]] || { echo "ASSERT_EQ${3:+ ($3)}: expected '$1', got '$2'"; return 1; }; }
assert_contains()     { [[ "$1" == *"$2"* ]] || { echo "ASSERT_CONTAINS${3:+ ($3)}: '$2' not in output"; echo "$1"; return 1; }; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || { echo "ASSERT_NOT_CONTAINS${3:+ ($3)}: '$2' present"; echo "$1"; return 1; }; }

TODAY="2026-03-10"

# setup_repo — fake repo carrying the real script and one host scope.
setup_repo() {
    local repo; repo="$(cd "$TEST_DIR" && pwd -P)/exobrain"
    mkdir -p "$repo/scripts" "$repo/people/alice/hosts/h1" "$repo/knowledge/sample"
    cp "$REPO_DIR/scripts/security-findings.py" "$repo/scripts/"
    echo "# root" > "$repo/AGENTS.md"
    echo "# alice" > "$repo/people/alice/AGENTS.md"
    echo "# h1" > "$repo/people/alice/hosts/h1/AGENTS.md"
    echo "$repo"
}

# sf REPO [args] — run the script with today pinned (override with SECURITY_TODAY).
sf() {
    local repo="$1"; shift
    SECURITY_TODAY="${SECURITY_TODAY:-$TODAY}" python3 "$repo/scripts/security-findings.py" "$@"
}

# add REPO TITLE SEVERITY [extra args] — a finding with filler detail.
add() {
    local repo="$1" title="$2" severity="$3"; shift 3
    sf "$repo" add --title "$title" --severity "$severity" --surface "a host" \
        --impact "what it allows" --fix "the remedy" "$@"
}

field() { jq -r "$2" "$1"; }

# ---------------------------------------------------------------------------

test_add_records_at_the_root() {
    local r; r="$(setup_repo)"
    local id; id="$(add "$r" "Forge token is too broad" high)" || return 1
    assert_eq "forge-token-is-too-broad" "$id" "the id is the title's slug" || return 1
    local f="$r/security.json"
    assert_eq "open" "$(field "$f" '.findings[0].status')" || return 1
    assert_eq "$TODAY" "$(field "$f" '.findings[0].found')" || return 1
    assert_eq "person" "$(field "$f" '.findings[0].fixer')" "fixer defaults to a person" || return 1
    sf "$r" --check >/dev/null || { echo "a fresh registry must validate"; return 1; }
}

test_add_into_a_scope() {
    local r; r="$(setup_repo)"
    add "$r" "Host finding" low --scope people/alice/hosts/h1 --fixer agent >/dev/null || return 1
    assert_eq "host-finding" "$(field "$r/people/alice/hosts/h1/security.json" '.findings[0].id')" || return 1
    [[ ! -e "$r/security.json" ]] || { echo "the root registry must not be created"; return 1; }
    local out; out="$(sf "$r" list)" || return 1
    assert_contains "$out" "host-finding" "a scope registry is discovered" || return 1
    out="$(add "$r" "Nowhere" low --scope knowledge/sample 2>&1)"; local rc=$?
    assert_eq 2 "$rc" "a non-scope dir is refused" || return 1
    assert_contains "$out" "not a scope"
}

test_duplicate_id_is_refused_across_registries() {
    local r; r="$(setup_repo)"
    add "$r" "Same thing" low >/dev/null || return 1
    local out; out="$(add "$r" "Same thing" low --scope people/alice 2>&1)"; local rc=$?
    assert_eq 2 "$rc" "exit code" || return 1
    assert_contains "$out" "exists" || return 1
    add "$r" "Same thing" low --id same-thing-again >/dev/null || { echo "--id sidesteps the clash"; return 1; }
}

test_accept_reopen_close() {
    local r; r="$(setup_repo)"; local f="$r/security.json"
    add "$r" "Known risk" medium >/dev/null || return 1
    sf "$r" accept known-risk --reason "the agent needs it" --review-by 2026-06-01 || return 1
    assert_eq "accepted" "$(field "$f" '.findings[0].status')" || return 1
    assert_eq "2026-06-01" "$(field "$f" '.findings[0].accepted.review_by')" || return 1
    sf "$r" --check >/dev/null || return 1
    sf "$r" reopen known-risk || return 1
    assert_eq "open" "$(field "$f" '.findings[0].status')" || return 1
    assert_eq "null" "$(field "$f" '.findings[0].accepted')" "reopening drops the acceptance" || return 1
    sf "$r" close known-risk || return 1
    assert_eq "0" "$(field "$f" '.findings | length')" "a fixed finding is removed" || return 1
    sf "$r" close known-risk 2>/dev/null; assert_eq 2 "$?" "an unknown id is a usage error" || return 1
    sf "$r" accept x --reason "r" --review-by soon 2>/dev/null; assert_eq 2 "$?" "a bad review date is a usage error"
}

test_list_orders_by_severity() {
    local r; r="$(setup_repo)"
    add "$r" "Low one" low >/dev/null; add "$r" "High one" high >/dev/null; add "$r" "Medium one" medium >/dev/null
    local ids; ids="$(sf "$r" list --json | jq -r '[.[].id] | join(" ")')"
    assert_eq "high-one medium-one low-one" "$ids" || return 1
    assert_eq "security.json" "$(sf "$r" list --json | jq -r '.[0].registry')" "each row names its registry"
}

test_summary_is_silent_without_a_registry() {
    local r; r="$(setup_repo)"
    local out; out="$(sf "$r" summary)"; local rc=$?
    assert_eq 0 "$rc" "exit code" || return 1
    assert_eq "" "$out" "no output"
}

test_summary_clean_when_nothing_needs_a_person() {
    local r; r="$(setup_repo)"
    add "$r" "Fresh high" high >/dev/null; add "$r" "A low" low >/dev/null
    sf "$r" reviewed || return 1
    local out; out="$(sf "$r" summary)"; local rc=$?
    assert_eq 0 "$rc" "a new high finding and a fresh review need nobody yet" || return 1
    assert_contains "$out" "security: 2 open (1 high, 1 low)"
}

test_summary_flags_an_old_high_finding() {
    local r; r="$(setup_repo)"
    SECURITY_TODAY=2026-02-01 add "$r" "Old high" high >/dev/null
    SECURITY_TODAY=2026-02-01 add "$r" "Old medium" medium >/dev/null
    sf "$r" reviewed || return 1
    local out; out="$(sf "$r" summary)"; local rc=$?
    assert_eq 2 "$rc" "exit code" || return 1
    assert_contains "$out" "high, open 37d: old-high" || return 1
    assert_not_contains "$out" "old-medium" "only high findings age into attention" || return 1
    out="$(SECURITY_HIGH_DAYS=60 sf "$r" summary)"; rc=$?
    assert_eq 0 "$rc" "the threshold is tunable"
}

test_summary_flags_an_overdue_acceptance() {
    local r; r="$(setup_repo)"
    add "$r" "Kept risk" high >/dev/null; sf "$r" reviewed
    sf "$r" accept kept-risk --reason "needed" --review-by 2026-03-09 || return 1
    local out; out="$(sf "$r" summary)"; local rc=$?
    assert_eq 2 "$rc" "exit code" || return 1
    assert_contains "$out" "accepted risk past its review date (2026-03-09): kept-risk" || return 1
    assert_contains "$out" "0 open, 1 accepted" || return 1
    sf "$r" accept kept-risk --reason "needed" --review-by 2026-03-10 || return 1
    sf "$r" summary >/dev/null; assert_eq 0 "$?" "the review date itself is not overdue"
}

test_summary_flags_a_stale_or_missing_review() {
    local r; r="$(setup_repo)"
    add "$r" "Something" low >/dev/null
    local out; out="$(sf "$r" summary)"; local rc=$?
    assert_eq 2 "$rc" "a registry never reviewed needs a person" || return 1
    assert_contains "$out" "never reviewed: security.json" || return 1
    SECURITY_TODAY=2026-02-01 sf "$r" reviewed || return 1
    assert_eq "2026-02-01" "$(field "$r/security.json" '.reviewed')" || return 1
    assert_eq "1" "$(field "$r/security.json" '.findings | length')" "the stamp keeps the findings" || return 1
    out="$(sf "$r" summary)"; rc=$?
    assert_eq 2 "$rc" "exit code" || return 1
    assert_contains "$out" "last reviewed 37d ago: security.json" || return 1
    out="$(SECURITY_REVIEW_DAYS=0 sf "$r" summary)"; rc=$?
    assert_eq 0 "$rc" "0 disables the review check"
}

test_check_reports_every_registry_error() {
    local r; r="$(setup_repo)"
    cat > "$r/security.json" <<'JSON'
{"reviewed": "last week", "extra": 1, "findings": [
  {"id": "Bad Id", "title": "t", "severity": "high", "status": "open", "found": "2026-01-01", "surface": "s", "impact": "i", "fix": "f", "fixer": "person"},
  {"id": "sev", "title": "t", "severity": "critical", "status": "open", "found": "2026-01-01", "surface": "s", "impact": "i", "fix": "f", "fixer": "person"},
  {"id": "acc", "title": "t", "severity": "low", "status": "accepted", "found": "2026-01-01", "surface": "s", "impact": "i", "fix": "f", "fixer": "person"},
  {"id": "stray", "title": "t", "severity": "low", "status": "open", "found": "2026-01-01", "surface": "s", "impact": "i", "fix": "f", "fixer": "person", "accepted": {"reason": "r", "review_by": "2026-02-01"}},
  {"id": "typo", "title": "t", "severity": "low", "status": "open", "found": "yesterday", "surface": "", "impact": "i", "fix": "f", "fixer": "robot", "sevrity": "x"},
  {"id": "dup", "title": "t", "severity": "low", "status": "open", "found": "2026-01-01", "surface": "s", "impact": "i", "fix": "f", "fixer": "agent"}
]}
JSON
    cat > "$r/people/alice/security.json" <<'JSON'
{"findings": [{"id": "dup", "title": "t", "severity": "low", "status": "open", "found": "2026-01-01", "surface": "s", "impact": "i", "fix": "f", "fixer": "agent"}]}
JSON
    echo "not json" > "$r/people/alice/hosts/h1/security.json"
    local out; out="$(sf "$r" --check 2>&1)"; local rc=$?
    assert_eq 1 "$rc" "exit code" || return 1
    assert_contains "$out" "reviewed must be a YYYY-MM-DD date" || return 1
    assert_contains "$out" "unknown key 'extra'" || return 1
    assert_contains "$out" "'Bad Id': id must be non-empty kebab-case" || return 1
    assert_contains "$out" "'sev': severity must be one of" || return 1
    assert_contains "$out" "'acc': an accepted finding needs accepted.reason" || return 1
    assert_contains "$out" "'stray': only an accepted finding carries the accepted block" || return 1
    assert_contains "$out" "'typo': unknown key 'sevrity'" || return 1
    assert_contains "$out" "'typo': surface must be a non-empty string" || return 1
    assert_contains "$out" "'typo': fixer must be one of" || return 1
    assert_contains "$out" "'typo': found must be a YYYY-MM-DD date" || return 1
    assert_contains "$out" "finding 'dup' is also declared in security.json" || return 1
    assert_contains "$out" "people/alice/hosts/h1/security.json: unreadable" || return 1
}

test_an_invalid_ledger_stops_every_command() {
    local r; r="$(setup_repo)"
    echo '{"findings": [{"id": "x"}]}' > "$r/security.json"
    local out; out="$(sf "$r" summary 2>&1)"; local rc=$?
    assert_eq 1 "$rc" "summary must not read a ledger it cannot trust as clean" || return 1
    assert_contains "$out" "title must be a non-empty string" || return 1
    add "$r" "Another" low >/dev/null 2>&1; assert_eq 1 "$?" "add refuses too"
}

test_writes_keep_the_schema_reference_and_unicode() {
    local r; r="$(setup_repo)"
    echo '{"$schema": "./security.schema.json", "findings": []}' > "$r/security.json"
    add "$r" "Имя в заголовке" low --id unicode-title >/dev/null || return 1
    assert_eq "./security.schema.json" "$(field "$r/security.json" '.["$schema"]')" || return 1
    grep -q "Имя в заголовке" "$r/security.json" || { echo "non-ASCII text must be written as is"; return 1; }
    [[ ! -e "$r/security.json.tmp" ]] || { echo "the temp file must not linger"; return 1; }
}

# with_gates REPO — add the real validator and healthcheck to the fake repo.
with_gates() {
    cp "$REPO_DIR/scripts/validate-exobrain.sh" "$REPO_DIR/scripts/changed-paths.sh" "$REPO_DIR/scripts/exobrain-healthcheck.sh" "$1/scripts/"
    chmod +x "$1/scripts/"*.sh "$1/scripts/"*.py
}

test_validator_runs_the_check() {
    local r; r="$(setup_repo)"; with_gates "$r"
    add "$r" "Fine" low >/dev/null || return 1
    local out; out="$("$r/scripts/validate-exobrain.sh" 2>&1)" || { echo "a valid ledger must validate: $out"; return 1; }
    echo '{"findings": [{"id": "x"}]}' > "$r/security.json"
    out="$("$r/scripts/validate-exobrain.sh" 2>&1)"; local rc=$?
    assert_eq 1 "$rc" "an invalid ledger fails validation" || return 1
    assert_contains "$out" "security-findings.py --check failed" || return 1
    assert_contains "$out" "title must be a non-empty string"
}

test_healthcheck_names_what_needs_a_person() {
    local r; r="$(setup_repo)"; with_gates "$r"
    SECURITY_TODAY=2026-02-01 add "$r" "Old high" high >/dev/null
    local out; out="$(SECURITY_TODAY="$TODAY" "$r/scripts/exobrain-healthcheck.sh" 2>&1)"; local rc=$?
    assert_eq 0 "$rc" "the healthcheck stays advisory" || return 1
    assert_contains "$out" "security: 1 open (1 high) — needs attention" || return 1
    assert_contains "$out" "  - high, open 37d: old-high" || return 1
    assert_contains "$out" "security-findings.py list"
}

test_healthcheck_quiet_when_nothing_needs_a_person() {
    local r; r="$(setup_repo)"; with_gates "$r"
    add "$r" "Fresh" high >/dev/null; sf "$r" reviewed
    local out; out="$(SECURITY_TODAY="$TODAY" "$r/scripts/exobrain-healthcheck.sh" 2>&1)"
    assert_not_contains "$out" "security" "no line for a ledger that needs nobody" || return 1
    echo "not json" > "$r/security.json"
    out="$(SECURITY_TODAY="$TODAY" "$r/scripts/exobrain-healthcheck.sh" 2>&1)"; local rc=$?
    assert_eq 0 "$rc" "a broken ledger never breaks session start" || return 1
    assert_not_contains "$out" "security" "the validator, not the healthcheck, reports a broken ledger"
}

# ---------------------------------------------------------------------------

run_test "add records at the root"                      test_add_records_at_the_root
run_test "add into a scope"                             test_add_into_a_scope
run_test "duplicate id refused across registries"       test_duplicate_id_is_refused_across_registries
run_test "accept, reopen, close"                        test_accept_reopen_close
run_test "list orders by severity"                      test_list_orders_by_severity
run_test "summary: silent without a registry"           test_summary_is_silent_without_a_registry
run_test "summary: clean when nothing needs a person"   test_summary_clean_when_nothing_needs_a_person
run_test "summary: an old high finding"                 test_summary_flags_an_old_high_finding
run_test "summary: an overdue acceptance"               test_summary_flags_an_overdue_acceptance
run_test "summary: a stale or missing review"           test_summary_flags_a_stale_or_missing_review
run_test "check: every registry error"                  test_check_reports_every_registry_error
run_test "an invalid ledger stops every command"        test_an_invalid_ledger_stops_every_command
run_test "writes keep the schema reference and unicode" test_writes_keep_the_schema_reference_and_unicode
run_test "validator runs the check"                     test_validator_runs_the_check
run_test "healthcheck names what needs a person"        test_healthcheck_names_what_needs_a_person
run_test "healthcheck quiet when nothing needs anyone"  test_healthcheck_quiet_when_nothing_needs_a_person

echo
if [[ $TESTS_FAILED -eq 0 ]]; then
    printf "${GREEN}${BOLD}%d/%d passed${RESET}\n" "$TESTS_PASSED" "$TESTS_RUN"
    exit 0
fi
printf "${RED}${BOLD}%d/%d failed${RESET}:\n" "$TESTS_FAILED" "$TESTS_RUN"
for f in ${FAILURES[@]+"${FAILURES[@]}"}; do printf "  ${RED}- %s${RESET}\n" "$f"; done
exit 1
