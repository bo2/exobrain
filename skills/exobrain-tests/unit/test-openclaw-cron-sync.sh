#!/usr/bin/env bash
# test-openclaw-cron-sync.sh — tests for scripts/openclaw-cron-sync.py: registry
# validation (--check), the reconciliation plan (--dry-run), and the add / edit /
# rm calls of a real sync — against a fake `openclaw` binary that records every
# call and answers `cron list --json` from a fixture file, so nothing reads a
# real gateway.
#
#   skills/exobrain-tests/unit/test-openclaw-cron-sync.sh            # run all
#   skills/exobrain-tests/unit/test-openclaw-cron-sync.sh <pattern>  # filter by name

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

assert_eq()           { [[ "$1" == "$2" ]] || { echo "ASSERT_EQ${3:+ ($3)}: expected '$1', got '$2'"; return 1; }; }
assert_contains()     { [[ "$1" == *"$2"* ]] || { echo "ASSERT_CONTAINS${3:+ ($3)}: '$2' not in output"; echo "$1"; return 1; }; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || { echo "ASSERT_NOT_CONTAINS${3:+ ($3)}: '$2' present in output"; echo "$1"; return 1; }; }

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

# setup_repo — fake exobrain carrying the real sync script and one person scope.
# The physical path (pwd -P): the sync script canonicalizes its repo root, and
# macOS mktemp answers under the /var -> /private/var symlink.
setup_repo() {
    local repo; repo="$(cd "$TEST_DIR" && pwd -P)/exobrain"
    mkdir -p "$repo/scripts" "$repo/people/pat"
    cp "$SCRIPTS_DIR/openclaw-cron-sync.py" "$repo/scripts/"
    chmod +x "$repo/scripts/openclaw-cron-sync.py"
    printf '# Exobrain\n\nFake.\n' > "$repo/AGENTS.md"
    printf '# pat\n' > "$repo/people/pat/AGENTS.md"
    echo "$repo"
}

# install_fake_openclaw — a shim that logs each call to calls.log, answers
# `cron list --json` from gateway.json, and appends a stub job on `cron add`.
install_fake_openclaw() {
    local bin="$TEST_DIR/bin"
    mkdir -p "$bin"
    echo '{"jobs": []}' > "$TEST_DIR/gateway.json"
    : > "$TEST_DIR/calls.log"
    cat > "$bin/openclaw" <<SHIM
#!/usr/bin/env bash
STATE="$TEST_DIR"
printf '%s\n' "\$*" >> "\$STATE/calls.log"
if [[ "\$1 \$2" == "cron list" ]]; then
    cat "\$STATE/gateway.json"
elif [[ "\$1 \$2" == "cron add" ]]; then
    python3 - "\$STATE/gateway.json" "\$@" <<'PY'
import json, sys
path, args = sys.argv[1], sys.argv[2:]
key = args[args.index("--declaration-key") + 1]
data = json.load(open(path))
data["jobs"].append({"id": f"fake-{len(data['jobs']) + 1}", "declarationKey": key})
json.dump(data, open(path, "w"))
PY
fi
exit 0
SHIM
    chmod +x "$bin/openclaw"
}

# a minimal valid agent job, declared in the person scope's crons.json
write_registry() {   # $1 = repo, rest = optional extra json for the job object
    cat > "$1/people/pat/crons.json" <<'JSON'
{"jobs": [{
  "name": "daily-thing",
  "schedule": {"cron": "0 12 * * *", "tz": "Europe/Berlin"},
  "payload": {"kind": "agent", "message": "Work in {ROOT}. Do the thing."},
  "delivery": {"mode": "none"}
}]}
JSON
}

sync_cmd() {   # $1 = repo, rest = args — runs the sync with the fake on PATH
    local repo="$1"; shift
    PATH="$TEST_DIR/bin:$PATH" "$repo/scripts/openclaw-cron-sync.py" "$@"
}

# ---------------------------------------------------------------------------
# --check: registry validation, no gateway
# ---------------------------------------------------------------------------

test_check_valid_registry() {
    local repo; repo=$(setup_repo); write_registry "$repo"
    local out; out=$("$repo/scripts/openclaw-cron-sync.py" --check 2>&1) || { echo "$out"; return 1; }
    assert_contains "$out" "1 job(s) valid"
}

test_check_needs_no_openclaw_binary() {
    local repo; repo=$(setup_repo); write_registry "$repo"
    PATH="/usr/bin:/bin" "$repo/scripts/openclaw-cron-sync.py" --check >/dev/null 2>&1 \
        || { echo "--check should not need the openclaw binary"; return 1; }
}

test_check_rejects_duplicate_names() {
    local repo; repo=$(setup_repo); write_registry "$repo"
    cp "$repo/people/pat/crons.json" "$repo/crons.json"
    local out; out=$("$repo/scripts/openclaw-cron-sync.py" --check 2>&1)
    assert_eq 1 $? "exit code" || return 1
    assert_contains "$out" "already declared"
}

test_check_rejects_model_pin() {
    local repo; repo=$(setup_repo)
    cat > "$repo/crons.json" <<'JSON'
{"jobs": [{"name": "x", "schedule": {"cron": "0 1 * * *", "tz": "UTC"},
           "payload": {"kind": "agent", "message": "m", "model": "some/model"}}]}
JSON
    local out; out=$("$repo/scripts/openclaw-cron-sync.py" --check 2>&1)
    assert_eq 1 $? "exit code" || return 1
    assert_contains "$out" "model is not declarable"
}

test_check_rejects_cron_without_tz() {
    local repo; repo=$(setup_repo)
    cat > "$repo/crons.json" <<'JSON'
{"jobs": [{"name": "x", "schedule": {"cron": "0 1 * * *"},
           "payload": {"kind": "agent", "message": "m"}}]}
JSON
    local out; out=$("$repo/scripts/openclaw-cron-sync.py" --check 2>&1)
    assert_eq 1 $? "exit code" || return 1
    assert_contains "$out" "needs an IANA tz"
}

test_check_rejects_announce_without_target() {
    local repo; repo=$(setup_repo)
    cat > "$repo/crons.json" <<'JSON'
{"jobs": [{"name": "x", "schedule": {"every": "1h"},
           "payload": {"kind": "agent", "message": "m"},
           "delivery": {"mode": "announce"}}]}
JSON
    local out; out=$("$repo/scripts/openclaw-cron-sync.py" --check 2>&1)
    assert_eq 1 $? "exit code" || return 1
    assert_contains "$out" "announce delivery needs channel and to"
}

# ---------------------------------------------------------------------------
# Reconciliation
# ---------------------------------------------------------------------------

test_sync_refuses_worktree() {
    local repo; repo=$(setup_repo); write_registry "$repo"; install_fake_openclaw
    echo "gitdir: /somewhere/.git/worktrees/x" > "$repo/.git"
    local out; out=$(sync_cmd "$repo" --dry-run 2>&1)
    assert_eq 1 $? "exit code" || return 1
    assert_contains "$out" "linked worktree" || return 1
    "$repo/scripts/openclaw-cron-sync.py" --check >/dev/null 2>&1 \
        || { echo "--check should still work from a worktree"; return 1; }
}

test_dry_run_plans_add_without_executing() {
    local repo; repo=$(setup_repo); write_registry "$repo"; install_fake_openclaw
    local out; out=$(sync_cmd "$repo" --dry-run 2>&1) || { echo "$out"; return 1; }
    assert_contains "$out" "add  exobrain.daily-thing" || return 1
    assert_not_contains "$(cat "$TEST_DIR/calls.log")" "cron add"
}

test_sync_adds_missing_job_then_patches_it() {
    local repo; repo=$(setup_repo); write_registry "$repo"; install_fake_openclaw
    local out; out=$(sync_cmd "$repo" 2>&1) || { echo "$out"; return 1; }
    local calls; calls=$(cat "$TEST_DIR/calls.log")
    assert_contains "$calls" "cron add --declaration-key exobrain.daily-thing" || return 1
    assert_contains "$calls" "cron edit fake-1" || return 1
    assert_contains "$calls" "--no-deliver"
}

test_sync_expands_root_in_message() {
    local repo; repo=$(setup_repo); write_registry "$repo"; install_fake_openclaw
    sync_cmd "$repo" >/dev/null 2>&1
    assert_contains "$(cat "$TEST_DIR/calls.log")" "Work in $repo." "expanded {ROOT}"
}

test_sync_noop_when_gateway_matches() {
    local repo; repo=$(setup_repo); write_registry "$repo"; install_fake_openclaw
    cat > "$TEST_DIR/gateway.json" <<JSON
{"jobs": [{"id": "j1", "declarationKey": "exobrain.daily-thing", "name": "daily-thing",
           "enabled": true,
           "schedule": {"kind": "cron", "expr": "0 12 * * *", "tz": "Europe/Berlin"},
           "sessionTarget": "isolated",
           "payload": {"kind": "agentTurn", "message": "Work in $repo. Do the thing."},
           "delivery": {"mode": "none"}}]}
JSON
    local out; out=$(sync_cmd "$repo" 2>&1) || { echo "$out"; return 1; }
    assert_contains "$out" "in sync" || return 1
    assert_not_contains "$(cat "$TEST_DIR/calls.log")" "cron edit"
}

test_sync_patches_drifted_field() {
    local repo; repo=$(setup_repo); write_registry "$repo"; install_fake_openclaw
    cat > "$TEST_DIR/gateway.json" <<JSON
{"jobs": [{"id": "j1", "declarationKey": "exobrain.daily-thing", "name": "daily-thing",
           "enabled": true,
           "schedule": {"kind": "cron", "expr": "30 9 * * *", "tz": "Europe/Berlin"},
           "sessionTarget": "isolated",
           "payload": {"kind": "agentTurn", "message": "Work in $repo. Do the thing."},
           "delivery": {"mode": "none"}}]}
JSON
    local out; out=$(sync_cmd "$repo" 2>&1) || { echo "$out"; return 1; }
    assert_contains "$out" "edit exobrain.daily-thing" || return 1
    assert_contains "$out" "schedule.expr" || return 1
    assert_contains "$(cat "$TEST_DIR/calls.log")" "cron edit j1"
}

test_sync_removes_stale_and_spares_foreign() {
    local repo; repo=$(setup_repo); write_registry "$repo"; install_fake_openclaw
    cat > "$TEST_DIR/gateway.json" <<'JSON'
{"jobs": [{"id": "j8", "declarationKey": "exobrain.retired-job", "name": "old"},
          {"id": "j9", "declarationKey": "pets-checkup", "name": "native"},
          {"id": "j10", "name": "undeclared native"}]}
JSON
    local out; out=$(sync_cmd "$repo" 2>&1) || { echo "$out"; return 1; }
    local calls; calls=$(cat "$TEST_DIR/calls.log")
    assert_contains "$calls" "cron rm j8" || return 1
    assert_not_contains "$calls" "rm j9" || return 1
    assert_not_contains "$calls" "rm j10"
}

test_sync_command_job_uses_argv() {
    local repo; repo=$(setup_repo); install_fake_openclaw
    cat > "$repo/crons.json" <<'JSON'
{"jobs": [{"name": "nightly-fetch",
           "schedule": {"cron": "0 7 * * *", "tz": "UTC", "stagger": "0s"},
           "payload": {"kind": "command", "argv": ["{ROOT}/scripts/fetch.sh"],
                       "timeoutSeconds": 60}}]}
JSON
    sync_cmd "$repo" >/dev/null 2>&1
    local calls; calls=$(cat "$TEST_DIR/calls.log")
    assert_contains "$calls" "--command-argv" || return 1
    assert_contains "$calls" "$repo/scripts/fetch.sh" "expanded {ROOT} in argv" || return 1
    assert_contains "$calls" "--exact" "0s stagger pins the minute"
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

run_test "check: valid registry passes"                 test_check_valid_registry
run_test "check: works without the openclaw binary"     test_check_needs_no_openclaw_binary
run_test "check: duplicate names rejected"              test_check_rejects_duplicate_names
run_test "check: model pin rejected"                    test_check_rejects_model_pin
run_test "check: cron without tz rejected"              test_check_rejects_cron_without_tz
run_test "check: announce without target rejected"      test_check_rejects_announce_without_target
run_test "sync: refuses to run from a linked worktree"  test_sync_refuses_worktree
run_test "sync: dry-run plans add, executes nothing"    test_dry_run_plans_add_without_executing
run_test "sync: adds missing job then patches it"       test_sync_adds_missing_job_then_patches_it
run_test "sync: expands {ROOT} in messages"             test_sync_expands_root_in_message
run_test "sync: no-op when gateway matches"             test_sync_noop_when_gateway_matches
run_test "sync: patches drifted field"                  test_sync_patches_drifted_field
run_test "sync: removes stale, spares foreign jobs"     test_sync_removes_stale_and_spares_foreign
run_test "sync: command job uses argv"                  test_sync_command_job_uses_argv

echo
if [[ $TESTS_FAILED -eq 0 ]]; then
    printf "${GREEN}${BOLD}%d/%d passed${RESET}\n" "$TESTS_PASSED" "$TESTS_RUN"
    exit 0
fi
printf "${RED}${BOLD}%d/%d failed${RESET}:\n" "$TESTS_FAILED" "$TESTS_RUN"
for f in ${FAILURES[@]+"${FAILURES[@]}"}; do printf "  ${RED}- %s${RESET}\n" "$f"; done
exit 1
