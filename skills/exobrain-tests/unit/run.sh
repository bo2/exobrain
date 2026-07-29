#!/usr/bin/env bash
# unit suite — deterministic tests of this instance's framework machinery.
#
#   run.sh --list                          # list harnesses + what each covers
#   run.sh                                 # every harness
#   run.sh --harnesses connect-agent       # selected harnesses (comma-separated)
#   run.sh --filter seed_scope             # pass a name filter through to each harness
#   run.sh -h|--help
#
# Hermetic and free: each harness builds fake exobrains in temp dirs and calls the
# scripts under <repo>/scripts/ directly. No agent CLI, no network, no credentials,
# no usage — so unlike the behavior/ and onboarding/ suites this one is safe to run
# on every change to the machinery it covers.
# Exit: 0 all passed | 1 some failed | 2 harness error.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTANCE_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"   # repo root: unit→exobrain-tests→skills→root

RED='\033[0;31m'; GREEN='\033[0;32m'; DIM='\033[0;90m'; BOLD='\033[1m'; RESET='\033[0m'

# name|script|what it covers
HARNESSES='connect-agent|test-connect-agent.sh|scripts/connect-agent.sh + scripts/skills-registry.sh
authoring-review|test-authoring-review.sh|scripts/authoring-review.sh
compat-ledger|test-compat-ledger.sh|the compat-shim gates in validate-exobrain.sh + exobrain-healthcheck.sh'

SEL=""; FILTER=""; LIST=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --harnesses)   SEL="$2"; shift 2 ;;
        --harnesses=*) SEL="${1#*=}"; shift ;;
        --filter)      FILTER="$2"; shift 2 ;;
        --filter=*)    FILTER="${1#*=}"; shift ;;
        --list)        LIST=1; shift ;;
        -h|--help)     grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)             echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

if [[ $LIST -eq 1 ]]; then
    printf "${BOLD}unit harnesses${RESET}\n\n"
    while IFS='|' read -r name script covers; do
        [[ -n "$name" ]] || continue
        printf "  %-18s %s\n" "$name" "$covers"
    done <<< "$HARNESSES"
    exit 0
fi

# A selection naming something that doesn't exist is a harness error, not a pass:
# a typo'd --harnesses must never look like a clean run.
if [[ -n "$SEL" ]]; then
    for want in ${SEL//,/ }; do
        grep -q "^$want|" <<< "$HARNESSES" || { echo "unknown harness: $want" >&2; exit 2; }
    done
fi

printf "${BOLD}exobrain-tests / unit${RESET}  ${DIM}%s${RESET}\n\n" "$INSTANCE_DIR"

ran=0; failed=0; FAILED_NAMES=()
while IFS='|' read -r name script covers; do
    [[ -n "$name" ]] || continue
    if [[ -n "$SEL" ]]; then
        grep -q "\b$name\b" <<< "${SEL//,/ }" || continue
    fi
    path="$SCRIPT_DIR/$script"
    [[ -f "$path" ]] || { echo "missing harness script: $path" >&2; exit 2; }
    printf "${DIM}── %s${RESET}\n" "$covers"
    if bash "$path" ${FILTER:+"$FILTER"}; then :; else
        failed=$((failed + 1)); FAILED_NAMES+=("$name")
    fi
    ran=$((ran + 1)); echo ""
done <<< "$HARNESSES"

if [[ $ran -eq 0 ]]; then echo "no harnesses selected" >&2; exit 2; fi
plural=""; [[ $ran -ne 1 ]] && plural="es"
if [[ $failed -gt 0 ]]; then
    printf "${RED}${BOLD}%d/%d harness%s failed${RESET}: %s\n" "$failed" "$ran" "$plural" "${FAILED_NAMES[*]}"
    exit 1
fi
printf "${GREEN}${BOLD}All %d harness%s passed${RESET}\n" "$ran" "$plural"
exit 0
