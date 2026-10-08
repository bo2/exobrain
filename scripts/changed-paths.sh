#!/usr/bin/env bash
# changed-paths.sh — the one reading of "which paths does this branch change" shared by
# the gates that scope themselves to a change: mount-isolation.py, validate-exobrain.sh,
# persist.sh. Git quotes a path holding a byte outside ASCII ("\320\272…") unless
# core.quotePath is off, and a gate that looks the quoted form up in the tree finds no
# such file and skips it. This prints every path verbatim, NUL-terminated, each once.
#
#   scripts/changed-paths.sh [--committed] [--added] <repo> [<base>] [-- <pathspec>...]
#
#   <base>        the ref the branch is compared against (its commits since the merge
#                 base, as `git diff <base>...HEAD`); without it, only the uncommitted
#                 changes are listed
#   --committed   only what the branch's commits change — the working tree is ignored
#   --added       only paths the branch adds, not ones it edits, renames or removes
#
# A removed path is listed too: the caller decides whether a removal counts. A rename
# lists its new name. Read the output with `while IFS= read -r -d '' p`, or split it
# on NUL.

set -uo pipefail

usage() { echo "usage: changed-paths.sh [--committed] [--added] <repo> [<base>] [-- <pathspec>...]" >&2; exit 2; }

committed=0 added=0 args=() pathspec=()
while (( $# )); do
    case "$1" in
        --committed) committed=1 ;;
        --added)     added=1 ;;
        --)          shift; pathspec=("$@"); break ;;
        -*)          usage ;;
        *)           args+=("$1") ;;
    esac
    shift
done
(( ${#args[@]} >= 1 && ${#args[@]} <= 2 )) || usage
repo="${args[0]}" base="${args[1]:-}"
[[ -d "$repo" ]] || { echo "changed-paths: not a directory: $repo" >&2; exit 2; }

g() { git -C "$repo" -c core.quotePath=false "$@"; }

# status_paths — the paths out of `git status --porcelain -z`: "XY path" records, a
# rename or copy followed by one more record holding the source path, which is dropped.
status_paths() {
    local rec xy skip=0
    while IFS= read -r -d '' rec; do
        if (( skip )); then skip=0; continue; fi
        xy="${rec:0:2}"
        case "$xy" in R?|C?|?R|?C) skip=1 ;; esac
        if (( added )); then case "$xy" in '??'|A?|?A) ;; *) continue ;; esac; fi
        printf '%s\0' "${rec:3}"
    done
}

{
    if [[ -n "$base" ]]; then
        filt=()
        (( added )) && filt=(--diff-filter=A)
        g diff --name-only -z ${filt[@]+"${filt[@]}"} "$base...HEAD" -- ${pathspec[@]+"${pathspec[@]}"} 2>/dev/null || true
    fi
    if (( ! committed )); then
        g status --porcelain -z --untracked-files=all -- ${pathspec[@]+"${pathspec[@]}"} 2>/dev/null | status_paths
    fi
} | sort -z -u
