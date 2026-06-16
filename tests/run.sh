#!/usr/bin/env bash
# run.sh — exobrain behavioral test harness.
#
# Builds a sample instance from the local seed by running exobrain-create via
# `claude -p`, then runs concrete agent tasks against fresh copies of it (each N
# times), checks pass/fail per run, and reports a k/N pass rate per case.
#
#   tests/run.sh                      # all cases, each at its configured N
#   tests/run.sh --smoke              # just the trivial 'smoke' case, N=1
#   tests/run.sh --cases a,b --runs 3 # selected cases, override N
#   tests/run.sh --build-only         # build + validate the template, then stop
#   tests/run.sh --list               # list available cases
#
# Flags: --cases <c1,c2>  --runs <N>  --smoke  --keep  --fresh-per-run
#        --build-only  --list  -h|--help
#
# Exit: 0 every case met its threshold | 1 some below | 2 harness/setup error.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/invoke.sh"
source "$HERE/lib/instance.sh"
source "$HERE/lib/judge.sh"
source "$HERE/lib/report.sh"

CASES_DIR="$TESTS_DIR/cases"

# ---- args -----------------------------------------------------------------
SEL_CASES=""; RUNS_OVERRIDE=""; SMOKE=0; KEEP=0; FRESH=0; BUILD_ONLY=0; LIST=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --cases)        SEL_CASES="$2"; shift 2 ;;
        --cases=*)      SEL_CASES="${1#*=}"; shift ;;
        --runs)         RUNS_OVERRIDE="$2"; shift 2 ;;
        --runs=*)       RUNS_OVERRIDE="${1#*=}"; shift ;;
        --smoke)        SMOKE=1; shift ;;
        --keep)         KEEP=1; shift ;;
        --fresh-per-run) FRESH=1; shift ;;
        --build-only)   BUILD_ONLY=1; shift ;;
        --list)         LIST=1; shift ;;
        -h|--help)      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)              err "unknown arg: $1"; exit 2 ;;
    esac
done

command -v claude >/dev/null 2>&1 || { err "claude not on PATH"; exit 2; }
command -v jq     >/dev/null 2>&1 || { err "jq not on PATH"; exit 2; }

meta_field() { jq -r --arg k "$2" --arg d "$3" '.[$k] // $d' "$1"; }

# ---- discover cases -------------------------------------------------------
mapfile -t ALL_CASES < <(find "$CASES_DIR" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/meta.json' ';' -print 2>/dev/null | xargs -n1 basename 2>/dev/null | sort)

if [[ $LIST -eq 1 ]]; then
    for c in "${ALL_CASES[@]}"; do
        printf '%-32s %s\n' "$c" "$(meta_field "$CASES_DIR/$c/meta.json" description '')"
    done
    exit 0
fi

if [[ $SMOKE -eq 1 ]]; then
    CASES=(smoke)
elif [[ -n "$SEL_CASES" ]]; then
    IFS=',' read -r -a CASES <<<"$SEL_CASES"
else
    CASES=("${ALL_CASES[@]}")
fi
[[ ${#CASES[@]} -eq 0 ]] && { err "no cases selected"; exit 2; }

# ---- run root -------------------------------------------------------------
TS="$(date +%Y%m%d-%H%M%S)"
RUN_ROOT="$REPO_DIR/tmp/test-runs/$TS"
mkdir -p "$RUN_ROOT"
log "run root: $RUN_ROOT"

# ---- estimate -------------------------------------------------------------
est_sessions=1; est_judge=0
for c in "${CASES[@]}"; do
    m="$CASES_DIR/$c/meta.json"; [[ -f "$m" ]] || continue
    prof="$(meta_field "$m" permission_profile action)"
    n="$(meta_field "$m" runs 3)"; [[ -n "$RUNS_OVERRIDE" ]] && n="$RUNS_OVERRIDE"
    [[ "$prof" == "static" ]] && n=1
    [[ "$SMOKE" -eq 1 ]] && n=1
    [[ "$prof" != "static" ]] && est_sessions=$((est_sessions + n))
    [[ -f "$CASES_DIR/$c/rubric.md" ]] && est_judge=$((est_judge + n))
done
log "plan: ${#CASES[@]} case(s); ~${est_sessions} agent session(s) + up to ${est_judge} judge call(s)"
log ""

# ---- build template -------------------------------------------------------
TEMPLATE="$RUN_ROOT/template"
TPL_BASE_COMMITS=0
if [[ $FRESH -eq 0 ]]; then
    build_template "$RUN_ROOT" || { err "template build failed — see $RUN_ROOT/build.stdout.txt"; exit 2; }
    TPL_BASE_COMMITS="$(git -C "$TEMPLATE" rev-list --count HEAD 2>/dev/null || echo 0)"
    if [[ $BUILD_ONLY -eq 1 ]]; then
        log "[build-only] template ready at $TEMPLATE (base commits: $TPL_BASE_COMMITS)"
        exit 0
    fi
fi

# provision_instance <dest> — fresh build or copy of the template; sets BASE_COMMITS
provision_instance() {
    local dest="$1"
    if [[ $FRESH -eq 1 ]]; then
        local sub="$(dirname "$dest")/_build"
        build_template "$sub" || return 1
        mv "$sub/template" "$dest"
        BASE_COMMITS="$(git -C "$dest" rev-list --count HEAD 2>/dev/null || echo 0)"
    else
        make_run_copy "$TEMPLATE" "$dest"
        BASE_COMMITS="$TPL_BASE_COMMITS"
    fi
}

# ---- main loop ------------------------------------------------------------
summary_init "$RUN_ROOT"
overall_setup_error=0

for case in "${CASES[@]}"; do
    cdir="$CASES_DIR/$case"
    meta="$cdir/meta.json"
    if [[ ! -f "$meta" ]]; then err "no such case: $case"; overall_setup_error=1; continue; fi

    prof="$(meta_field "$meta" permission_profile action)"
    thr="$(meta_field "$meta" pass_threshold all)"
    tmo="$(meta_field "$meta" timeout_seconds 300)"
    model="$(meta_field "$meta" model '')"
    ofmt="$(meta_field "$meta" output_format text)"
    N="$(meta_field "$meta" runs 3)"
    [[ -n "$RUNS_OVERRIDE" ]] && N="$RUNS_OVERRIDE"
    [[ "$prof" == "static" ]] && N=1
    [[ "$SMOKE" -eq 1 ]] && N=1

    log "=== case: $case  (profile=$prof, runs=$N, threshold=$thr) ==="
    passes=0; errors=0

    for ((i=1; i<=N; i++)); do
        rdir="$RUN_ROOT/$case/run-$i"
        inst="$rdir/instance"
        mkdir -p "$rdir"

        if ! provision_instance "$inst"; then
            err "  run $i: provisioning failed"; errors=$((errors+1))
            printf '{"status":"ERROR","reason":"provision"}\n' >"$rdir/result.json"
            continue
        fi

        [[ -f "$cdir/setup.sh" ]] && { BASE_COMMIT_COUNT="$BASE_COMMITS" HARNESS_LIB="$TESTS_DIR/lib" \
            bash "$cdir/setup.sh" "$inst" >"$rdir/setup.log" 2>&1 || log "  run $i: setup.sh returned non-zero (continuing)"; }

        invoke_agent "$inst" "$cdir/prompt.md" "$prof" "$tmo" "$model" "$ofmt" "$rdir/stdout.txt"
        ec=$?

        CASE_DIR="$cdir" BASE_COMMIT_COUNT="$BASE_COMMITS" HARNESS_LIB="$TESTS_DIR/lib" \
            bash "$cdir/check.sh" "$inst" "$rdir/stdout.txt" "$ec" >"$rdir/check.out" 2>&1
        rc=$?

        case "$rc" in
            0) status="PASS"; passes=$((passes+1)) ;;
            2) status="ERROR"; errors=$((errors+1)) ;;
            *) status="FAIL" ;;
        esac
        log "  run $i: $status (claude rc=$ec, check rc=$rc)"
        printf '{"status":"%s","claude_exit":%s,"check_exit":%s}\n' "$status" "$ec" "$rc" >"$rdir/result.json"

        [[ $KEEP -eq 0 ]] && rm -rf "$rdir"/instance* "$rdir/_build" 2>/dev/null
    done

    met=0
    if threshold_met "$passes" "$N" "$thr"; then met=1; fi
    log "  -> $case: $passes/$N passed${errors:+, $errors error(s)} (threshold $thr -> $([[ $met -eq 1 ]] && echo MET || echo MISSED))"
    summary_add "$case" "$passes" "$errors" "$N" "$thr" "$met"
done

# ---- summary & exit -------------------------------------------------------
if summary_write "$RUN_ROOT"; then
    [[ $overall_setup_error -eq 1 ]] && exit 2
    exit 0
else
    [[ $overall_setup_error -eq 1 ]] && exit 2
    exit 1
fi
