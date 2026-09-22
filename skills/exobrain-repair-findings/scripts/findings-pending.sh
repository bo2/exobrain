#!/usr/bin/env bash
# findings-pending.sh — list merged PRs carrying authoring-review findings that
# nobody has acted on yet: the ones an unattended land posted as a review on the
# PR instead of blocking on (scripts/persist.sh § authoring review).
#
#   skills/exobrain-repair-findings/scripts/findings-pending.sh [--limit <n>]
#
# Prints one PR per line — "<number>\t<title>" — oldest first, so a repair pass
# works through them in the order they landed. Nothing to repair prints nothing
# and exits 0.
#
# A PR qualifies when one of its reviews opens with the findings heading and it
# does not yet carry the REPAIRED_LABEL. Forge search does not match review text,
# so the script reads the reviews of the <limit> most recently merged PRs that
# lack the label (default 100) — a repair pass that runs daily stays well inside it.
#
# Needs `gh` authenticated against the repo's origin. GH_REPO overrides the repo.

set -uo pipefail

FINDINGS_HEADING="## Authoring review (unattended land, not blocking)"
REPAIRED_LABEL="findings-repaired"
LIMIT=100

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

# gh lists newest first; the repair order is oldest first. The heading is a plain
# literal (no quote or backslash), so it embeds in the jq filter as a string.
gh pr list "${REPO_ARGS[@]+"${REPO_ARGS[@]}"}" --state merged \
    --search "-label:$REPAIRED_LABEL" --limit "$LIMIT" \
    --json number,title,labels,reviews \
    --jq ".[] | select(any(.reviews[]?; .body | startswith(\"$FINDINGS_HEADING\")))
              | select(any(.labels[]?; .name == \"$REPAIRED_LABEL\") | not)
              | \"\\(.number)\\t\\(.title)\"" | sort -n
