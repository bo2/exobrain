#!/usr/bin/env bash
# report.sh — aggregate per-case results into a printed table + summary files.
# Sourced. Results accumulate in a TSV at $SUMMARY_TSV:
#   case <tab> passes <tab> errors <tab> total <tab> threshold <tab> met(0|1)

summary_init() {
    SUMMARY_TSV="$1/.summary.tsv"
    : >"$SUMMARY_TSV"
}

summary_add() {
    # case passes errors total threshold met
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" >>"$SUMMARY_TSV"
}

# summary_write <run_root> — emit summary.{txt,json}, print the table, and return
# 0 only if every case met its threshold (1 otherwise).
summary_write() {
    local run_root="$1"
    local txt="$run_root/summary.txt" json="$run_root/summary.json"
    local all_met=1

    {
        printf '%-34s %-8s %-7s %s\n' "CASE" "RESULT" "PASS" "THRESHOLD"
        printf '%-34s %-8s %-7s %s\n' "----" "------" "----" "---------"
    } >"$txt"

    printf '{\n  "cases": [\n' >"$json"
    local first=1
    while IFS=$'\t' read -r name passes errors total thr met; do
        [[ -z "$name" ]] && continue
        # informational cases report a rate but never gate the exit code.
        local verdict
        if [[ "$thr" == "informational" ]]; then
            verdict="INFO"
        elif [[ "$met" -eq 1 ]]; then
            verdict="PASS"
        else
            verdict="FAIL"; all_met=0
        fi
        local extra=""; [[ "$errors" -gt 0 ]] && extra=" (${errors} err)"
        printf '%-34s %-8s %-7s %s\n' "$name" "$verdict" "${passes}/${total}${extra}" "$thr" >>"$txt"

        [[ $first -eq 1 ]] || printf ',\n' >>"$json"
        first=0
        printf '    {"name": %s, "verdict": "%s", "passes": %s, "errors": %s, "total": %s, "threshold": "%s"}' \
            "$(json_str "$name")" "$verdict" "$passes" "$errors" "$total" "$thr" >>"$json"
    done <"$SUMMARY_TSV"
    printf '\n  ],\n  "all_met": %s\n}\n' "$([[ $all_met -eq 1 ]] && echo true || echo false)" >>"$json"

    log ""
    cat "$txt" >&2
    log ""
    log "summary: $txt"
    log "json:    $json"

    [[ $all_met -eq 1 ]]
}
