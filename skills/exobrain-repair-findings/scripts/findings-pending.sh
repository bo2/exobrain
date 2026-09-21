#!/usr/bin/env bash
# findings-pending.sh — list merged PRs carrying authoring-review findings that
# nobody has acted on yet: the ones an unattended land recorded in the PR body
# instead of blocking on (scripts/persist.sh § authoring review).
#
#   skills/exobrain-repair-findings/scripts/findings-pending.sh [--limit <n>]
#
# Prints one PR per line — "<number>\t<title>" — oldest first, so a repair pass
# works through them in the order they landed. Nothing to repair prints nothing
# and exits 0.
#
# A PR qualifies when its body carries the findings heading and it does not yet
# carry the REPAIRED_LABEL. The search narrows the candidate set; the heading is
# then verified in each body, because the search matches any prose mentioning the
# phrase (a PR about the persist machinery does). The forge is the system of record —
# no ledger of repaired PRs lives in the repo.
#
# Needs `gh` authenticated against the repo's origin. GH_REPO overrides the repo.

set -uo pipefail

FINDINGS_HEADING="## Authoring review (unattended land, not blocking)"
REPAIRED_LABEL="findings-repaired"
LIMIT=30

while [[ $# -gt 0 ]]; do
    case "$1" in
        --limit)   [[ $# -ge 2 ]] || { echo "findings-pending: --limit needs a number" >&2; exit 2; }
                   LIMIT="$2"; shift 2 ;;
        --limit=*) LIMIT="${1#*=}"; shift ;;
        --heading) echo "$FINDINGS_HEADING"; exit 0 ;;
        --label)   echo "$REPAIRED_LABEL"; exit 0 ;;
        -h|--help) grep '^#' "$0" | sed -n '2,20p' | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "findings-pending: unknown argument: $1" >&2; exit 2 ;;
    esac
done
[[ "$LIMIT" =~ ^[0-9]+$ ]] || { echo "findings-pending: --limit needs a number" >&2; exit 2; }

command -v gh >/dev/null || { echo "findings-pending: gh not found" >&2; exit 2; }

REPO_ARGS=()
if [[ -n "${GH_REPO:-}" ]]; then REPO_ARGS=(--repo "$GH_REPO"); fi

# Candidates: merged PRs whose body mentions the phrase and that aren't labelled
# repaired. `gh search` sorts newest first; the repair order is oldest first.
candidates="$(gh search prs "${REPO_ARGS[@]+"${REPO_ARGS[@]}"}" --merged --match body \
                 "unattended land" --limit "$LIMIT" --json number --jq '.[].number' 2>/dev/null)" || candidates=""
[[ -n "$candidates" ]] || exit 0

while IFS= read -r n; do
    [[ -n "$n" ]] || continue
    row="$(gh pr view "$n" "${REPO_ARGS[@]+"${REPO_ARGS[@]}"}" --json title,body,labels \
             --jq '[(.labels // [] | map(.name) | join(",")), .title, .body] | @tsv' 2>/dev/null)" || continue
    labels="${row%%$'\t'*}"; rest="${row#*$'\t'}"; title="${rest%%$'\t'*}"; body="${rest#*$'\t'}"
    # @tsv escapes the body's newlines as \n; the heading still matches as a substring.
    [[ "$body" == *"$FINDINGS_HEADING"* ]] || continue
    [[ ",$labels," == *",$REPAIRED_LABEL,"* ]] && continue
    printf '%s\t%s\n' "$n" "$title"
done <<< "$candidates" | sort -n
