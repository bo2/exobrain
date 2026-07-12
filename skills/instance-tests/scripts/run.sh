#!/usr/bin/env bash
# instance-tests — real-environment end-to-end tests of this exobrain instance.
#
#   run.sh --list                       # list cases + requirements
#   run.sh                              # all cases, default mode (probe)
#   run.sh --cases clone-and-connect    # selected cases (comma-separated)
#   run.sh --mode agent                 # mode passed to each case (probe|agent)
#   run.sh -h|--help
#
# Each case declares requirements in meta.json; a case whose requirements are unmet
# on this machine is SKIPPED (reported, not failed). See SKILL.md.
# Exit: 0 all passed | 1 some failed | 2 harness error.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTANCE_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"   # repo root: scripts→instance-tests→skills→root
CASES_DIR="$SCRIPT_DIR/cases"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

MODE="probe"; SEL_CASES=""; LIST=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)    MODE="$2"; shift 2 ;;
        --mode=*)  MODE="${1#*=}"; shift ;;
        --cases)   SEL_CASES="$2"; shift 2 ;;
        --cases=*) SEL_CASES="${1#*=}"; shift ;;
        --list)    LIST=1; shift ;;
        -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)         err "unknown argument: $1"; exit 2 ;;
    esac
done
case "$MODE" in probe|agent) ;; *) err "invalid --mode: $MODE (probe|agent)"; exit 2 ;; esac

command -v jq >/dev/null 2>&1 || { err "jq required"; exit 2; }
meta()  { jq -r --arg k "$2" '.[$k] // empty' "$1"; }
metaa() { jq -r --arg k "$2" '(.[$k] // [])[]' "$1"; }

# Plain while-read instead of `mapfile` (a bash 4 builtin) so this runs under
# macOS's stock bash 3.2.
ALL_CASES=()
while IFS= read -r c; do
    [[ -n "$c" ]] && ALL_CASES+=("$c")
done < <(find "$CASES_DIR" -mindepth 1 -maxdepth 1 -type d \
    -exec test -f '{}/meta.json' ';' -print 2>/dev/null | xargs -n1 basename 2>/dev/null | sort)

if [[ $LIST -eq 1 ]]; then
    printf '%-22s %-26s %s\n' CASE REQUIREMENTS DESCRIPTION
    for c in ${ALL_CASES[@]+"${ALL_CASES[@]}"}; do
        m="$CASES_DIR/$c/meta.json"
        printf '%-22s %-26s %s\n' "$c" "$(jq -r '(.requirements // [])|join(",")' "$m")" "$(meta "$m" description)"
    done
    exit 0
fi

if [[ -n "$SEL_CASES" ]]; then IFS=',' read -r -a CASES <<<"$SEL_CASES"; else CASES=(${ALL_CASES[@]+"${ALL_CASES[@]}"}); fi
[[ ${#CASES[@]} -eq 0 ]] && { err "no cases found"; exit 2; }

log "instance: $INSTANCE_DIR · mode=$MODE · cases: ${CASES[*]}"
PASS=0; FAIL=0; SKIP=0; FAILED=()
for c in "${CASES[@]}"; do
    cdir="$CASES_DIR/$c"; m="$cdir/meta.json"
    [[ -f "$m" ]] || { err "no such case: $c"; FAIL=$((FAIL+1)); FAILED+=("$c(missing)"); continue; }

    # Requirement gate (baseline + agent-mode extras).
    reqs=(); while IFS= read -r r; do [[ -n "$r" ]] && reqs+=("$r"); done < <(metaa "$m" requirements)
    [[ "$MODE" != probe ]] && while IFS= read -r r; do [[ -n "$r" ]] && reqs+=("$r"); done < <(metaa "$m" requirements_agent)
    unmet=""
    for r in ${reqs[@]+"${reqs[@]}"}; do check_requirement "$r" "$INSTANCE_DIR" || unmet="$unmet $r"; done
    if [[ -n "$unmet" ]]; then
        echo "${YELLOW}SKIP${RESET} $c — unmet requirement(s):$unmet"; SKIP=$((SKIP+1)); continue
    fi

    echo "${BOLD}── case: $c (mode=$MODE) ──${RESET}"
    if INSTANCE_DIR="$INSTANCE_DIR" CASE_DIR="$cdir" MODE="$MODE" bash "$cdir/run.sh"; then
        echo "${GREEN}PASS${RESET} $c"; PASS=$((PASS+1))
    else
        echo "${RED}FAIL${RESET} $c"; FAIL=$((FAIL+1)); FAILED+=("$c")
    fi
done

echo "─────────────────────────────────────────────"
printf '%s%d passed · %d failed · %d skipped%s\n' "$BOLD" "$PASS" "$FAIL" "$SKIP" "$RESET"
[[ $FAIL -gt 0 ]] && printf '  - %s\n' "${FAILED[@]}"
echo "─────────────────────────────────────────────"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
