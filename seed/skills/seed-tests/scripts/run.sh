#!/usr/bin/env bash
# run.sh — seed-tests: test the canonical seed end to end.
#
# Builds a fresh instance from the seed via create-instance (a builder agent),
# verifies the bootstrap (the create-valid static checks), then runs the universal
# exobrain-tests behavior suite against the built instance.
#
#   run.sh                       # build via claude, verify, run all behavioral cases
#   run.sh --builder codex       # build via a different agent
#   run.sh --agents claude       # pass-through to the behavior suite (agents/cases/runs/…)
#   run.sh --list                # list the behavioral cases (delegates)
#
# Separately, the deterministic connector harness lives beside this script:
#   ./test-connect-agent.sh      # hermetic registry/connector unit tests (no agents)
#
# Exit: 0 build+bootstrap+suite all pass | 1 a check failed | 2 harness/setup error.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../seed-tests/scripts
SEED_REPO="$(cd "$HERE/../../../.." && pwd)"           # <repo> — the seed
ETESTS="$SEED_REPO/skills/exobrain-tests/behavior"     # the universal behavior suite

[[ -f "$ETESTS/run.sh" ]] || { echo "ERROR: exobrain-tests behavior suite not found at $ETESTS" >&2; exit 2; }
source "$ETESTS/lib/common.sh"     # log/err, agent_available, REPO_DIR (=seed)
source "$ETESTS/lib/invoke.sh"     # invoke_agent
source "$HERE/lib/build.sh"        # render_build_prompt, build_raw_instance

BUILDER="claude"
PASS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --builder)   BUILDER="$2"; shift 2 ;;
        --builder=*) BUILDER="${1#*=}"; shift ;;
        --list)      "$ETESTS/run.sh" --list; exit 0 ;;
        -h|--help)   grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)           PASS+=("$1"); shift ;;
    esac
done

command -v jq >/dev/null 2>&1 || { err "jq not on PATH"; exit 2; }
agent_available "$BUILDER" || { err "builder agent '$BUILDER' is missing or not runnable"; exit 2; }

TS="$(date +%Y%m%d-%H%M%S)"
RUN_ROOT="$SEED_REPO/tmp/seed-tests/$TS"
mkdir -p "$RUN_ROOT"
BUILD="$RUN_ROOT/instance"
log "seed-tests run root: $RUN_ROOT"

# 1. Build an instance from the seed (exercises the create-instance bootstrap).
log "[seed-tests] building an instance from the seed via create-instance ($BUILDER)…"
build_raw_instance "$BUILD" "$BUILDER" \
    || { err "from-seed build failed — see $BUILD/build.stdout.txt"; exit 2; }

# 2. Verify the bootstrap (static checks; no agent).
log "[seed-tests] verifying the bootstrap (create-valid)…"
if CASE_DIR="$HERE/cases/create-valid" HARNESS_LIB="$ETESTS/lib" \
       bash "$HERE/cases/create-valid/check.sh" "$BUILD" "" 0; then
    log "[seed-tests] bootstrap OK"
else
    err "[seed-tests] create-valid failed on the built instance"
    exit 1
fi

# 3. Finish initializing the instance: commit it, so it's a normal committed repo
#    (create-instance leaves committing to the user; the suite snapshots HEAD).
git -C "$BUILD" add -A
git -C "$BUILD" -c user.email=harness@exobrain.test -c user.name='exobrain harness' \
    commit -q -m "harness: initial instance snapshot" || true

# 4. Run the built instance's OWN behavior suite, exactly as any instance self-tests.
INST_SUITE="$BUILD/skills/exobrain-tests/behavior/run.sh"
[[ -f "$INST_SUITE" ]] || { err "built instance has no exobrain-tests behavior suite at $INST_SUITE"; exit 2; }
log "[seed-tests] running the built instance's own behavior suite…"
exec "$INST_SUITE" ${PASS[@]+"${PASS[@]}"}
