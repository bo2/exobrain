#!/usr/bin/env bash
# run.sh — exobrain behavioral test suite (runs on the current instance).
#
# Snapshots the instance this skill is installed in into a throwaway copy, then
# runs concrete agent tasks against fresh copies of it (each N times) for every
# selected agent, checks pass/fail per run, and reports a k/N pass rate per
# agent+case. An instance self-tests by invoking this with no source argument —
# there is none; the suite always tests its own instance. (The seed tests an
# instance by building one and running *that* instance's copy of this suite.)
#
#   run.sh                              # all cases, all available agents (HEAD)
#   run.sh --working-tree              # test uncommitted local changes (pre-persist)
#   run.sh --agents claude             # claude only
#   run.sh --smoke                     # the trivial 'smoke' case, N=1
#   run.sh --cases a,b --runs 3        # selected cases, override N
#   run.sh --build-only                # provision + validate the template, stop
#   run.sh --list                      # list cases
#
# By default the suite snapshots HEAD (committed state). Pass --working-tree to snapshot
# the current working tree instead — committed + uncommitted (new, modified, deleted),
# honoring .gitignore — so you can verify a change before persisting it.
#
# Flags: --agents <a1,a2>  --cases <c1,c2>  --runs <N>  --smoke  --working-tree  --keep
#        --build-only  --list  -h|--help
#
# An agent whose CLI is missing or not runnable is skipped with a notice. The
# LLM-judge always runs on claude regardless of the agent under test.
#
# Exit: 0 every agent+case met its threshold | 1 some below | 2 harness/setup error.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/invoke.sh"
source "$HERE/lib/provision.sh"
source "$HERE/lib/judge.sh"
source "$HERE/lib/report.sh"

CASES_DIR="$TESTS_DIR/cases"

# ---- args -----------------------------------------------------------------
AGENTS_SEL="claude,codex"
SEL_CASES=""; RUNS_OVERRIDE=""; SMOKE=0; KEEP=0; BUILD_ONLY=0; LIST=0; WORKTREE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --agents)       AGENTS_SEL="$2"; shift 2 ;;
        --agents=*)     AGENTS_SEL="${1#*=}"; shift ;;
        --cases)        SEL_CASES="$2"; shift 2 ;;
        --cases=*)      SEL_CASES="${1#*=}"; shift ;;
        --runs)         RUNS_OVERRIDE="$2"; shift 2 ;;
        --runs=*)       RUNS_OVERRIDE="${1#*=}"; shift ;;
        --smoke)        SMOKE=1; shift ;;
        --working-tree|--dirty) WORKTREE=1; shift ;;
        --keep)         KEEP=1; shift ;;
        --build-only)   BUILD_ONLY=1; shift ;;
        --list)         LIST=1; shift ;;
        -h|--help)      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)              err "unknown arg: $1"; exit 2 ;;
    esac
done

command -v jq >/dev/null 2>&1 || { err "jq not on PATH"; exit 2; }

meta_field() { jq -r --arg k "$2" --arg d "$3" '.[$k] // $d' "$1"; }

# ---- discover cases -------------------------------------------------------
mapfile -t ALL_CASES < <(find "$CASES_DIR" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/meta.json' ';' -print 2>/dev/null | xargs -n1 basename 2>/dev/null | sort)

if [[ $LIST -eq 1 ]]; then
    for c in "${ALL_CASES[@]}"; do
        printf '%-32s %s\n' "$c" "$(meta_field "$CASES_DIR/$c/meta.json" description '')"
    done
    exit 0
fi

# ---- resolve agents (filter to runnable) ----------------------------------
IFS=',' read -r -a REQ_AGENTS <<<"$AGENTS_SEL"
AGENTS=()
for a in "${REQ_AGENTS[@]}"; do
    case "$a" in
        claude|codex) ;;
        *) err "unknown agent: $a (expected claude or codex)"; exit 2 ;;
    esac
    if agent_available "$a"; then
        AGENTS+=("$a")
    else
        log "skip agent '$a': CLI missing or not runnable on this machine"
    fi
done
[[ ${#AGENTS[@]} -eq 0 ]] && { err "no requested agent is available"; exit 2; }

# ---- select cases ---------------------------------------------------------
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
per_agent_sessions=0; per_agent_judge=0
for c in "${CASES[@]}"; do
    m="$CASES_DIR/$c/meta.json"; [[ -f "$m" ]] || continue
    prof="$(meta_field "$m" permission_profile action)"
    n="$(meta_field "$m" runs 3)"; [[ -n "$RUNS_OVERRIDE" ]] && n="$RUNS_OVERRIDE"
    [[ "$prof" == "static" || "$SMOKE" -eq 1 ]] && n=1
    [[ "$prof" != "static" ]] && per_agent_sessions=$((per_agent_sessions + n))
    [[ -f "$CASES_DIR/$c/rubric.md" ]] && per_agent_judge=$((per_agent_judge + n))
done
est_sessions=$((per_agent_sessions * ${#AGENTS[@]}))
est_judge=$((per_agent_judge * ${#AGENTS[@]}))
log "plan: agents=[${AGENTS[*]}], ${#CASES[@]} case(s) against this instance; ~${est_sessions} agent session(s) + up to ${est_judge} judge call(s)"
log ""

# ---- provision the template (once) ----------------------------------------
TEMPLATE="$RUN_ROOT/template"
if [[ $WORKTREE -eq 1 ]]; then
    log "source: working tree (uncommitted local changes included)"
    provision_working_tree "$TEMPLATE" || { err "provisioning the working tree failed"; exit 2; }
else
    log "source: HEAD (committed state)"
    provision_self "$TEMPLATE" || { err "provisioning from the current instance failed"; exit 2; }
fi
finalize_template "$TEMPLATE" || { err "template did not finalize (validate / safety)"; exit 2; }
TPL_BASE_COMMITS="$(git -C "$TEMPLATE" rev-list --count HEAD 2>/dev/null || echo 0)"
if [[ $BUILD_ONLY -eq 1 ]]; then
    log "[build-only] template ready at $TEMPLATE (base commits: $TPL_BASE_COMMITS)"
    exit 0
fi

# provision_instance <dest> — a fresh per-run copy of the finalized template.
provision_instance() {
    local dest="$1"
    make_run_copy "$TEMPLATE" "$dest"
    BASE_COMMITS="$TPL_BASE_COMMITS"
}

# ---- main loop: agents x cases x runs -------------------------------------
summary_init "$RUN_ROOT"
overall_setup_error=0

for agent in "${AGENTS[@]}"; do
  log "######## agent: $agent ########"
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
    [[ "$prof" == "static" || "$SMOKE" -eq 1 ]] && N=1

    log "=== $agent/$case  (profile=$prof, runs=$N, threshold=$thr) ==="
    passes=0; errors=0

    for ((i=1; i<=N; i++)); do
        rdir="$RUN_ROOT/$agent/$case/run-$i"
        inst="$rdir/instance"
        mkdir -p "$rdir"

        if ! provision_instance "$inst"; then
            err "  run $i: provisioning failed"; errors=$((errors+1))
            printf '{"status":"ERROR","reason":"provision"}\n' >"$rdir/result.json"
            continue
        fi

        [[ -f "$cdir/setup.sh" ]] && { BASE_COMMIT_COUNT="$BASE_COMMITS" HARNESS_LIB="$TESTS_DIR/lib" \
            bash "$cdir/setup.sh" "$inst" >"$rdir/setup.log" 2>&1 || log "  run $i: setup.sh returned non-zero (continuing)"; }

        # Pin a stable base ref (post-setup, pre-agent HEAD) so a check can diff the
        # agent's own changes no matter where it landed them — a worktree branch, or
        # committed/squash-merged onto trunk (which moves trunk). Shared across linked
        # worktrees via the common ref store.
        git -C "$inst" tag -f exobrain-base HEAD >/dev/null 2>&1 || true

        invoke_agent "$agent" "$inst" "$cdir/prompt.md" "$prof" "$tmo" "$model" "$ofmt" "$rdir/stdout.txt"
        ec=$?

        CASE_DIR="$cdir" BASE_COMMIT_COUNT="$BASE_COMMITS" HARNESS_LIB="$TESTS_DIR/lib" \
            bash "$cdir/check.sh" "$inst" "$rdir/stdout.txt" "$ec" >"$rdir/check.out" 2>&1
        rc=$?

        case "$rc" in
            0) status="PASS"; passes=$((passes+1)) ;;
            2) status="ERROR"; errors=$((errors+1)) ;;
            *) status="FAIL" ;;
        esac
        log "  run $i: $status ($agent rc=$ec, check rc=$rc)"
        printf '{"agent":"%s","status":"%s","engine_exit":%s,"check_exit":%s}\n' \
            "$agent" "$status" "$ec" "$rc" >"$rdir/result.json"

        [[ $KEEP -eq 0 ]] && rm -rf "$rdir"/instance* "$rdir/_build" 2>/dev/null
    done

    met=0
    if threshold_met "$passes" "$N" "$thr"; then met=1; fi
    if [[ "$thr" == "informational" ]]; then verdict_word="INFO"
    elif [[ $met -eq 1 ]]; then verdict_word="MET"
    else verdict_word="MISSED"; fi
    log "  -> $agent/$case: $passes/$N passed${errors:+, $errors error(s)} (threshold $thr -> $verdict_word)"
    summary_add "$agent/$case" "$passes" "$errors" "$N" "$thr" "$met"
  done
done

# ---- summary & exit -------------------------------------------------------
if summary_write "$RUN_ROOT"; then
    [[ $overall_setup_error -eq 1 ]] && exit 2
    exit 0
else
    [[ $overall_setup_error -eq 1 ]] && exit 2
    exit 1
fi
