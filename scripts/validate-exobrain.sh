#!/usr/bin/env bash
# validate-exobrain.sh — deterministic checks against the conventions in
# AGENTS.md. Fast and free (sub-second on a clean repo); runs from the
# pre-push hook installed by connect-agent.sh and is also runnable manually.
#
# Catches:
#   - AGENTS.md inside a content tree (domains/, workspaces/) — any other dir is
#     a valid scope, so only content-tree placement is rejected.
#   - Custom UPPERCASE.md filenames (allowed: standard open-source +
#     AI/tool entry-point conventions).
#   - JSON syntax errors in skills.json and scopes.json files.
#   - scopes.json shape (type + collection; reserved/kebab-case rules).
#   - Skills registry integrity (delegated to skills-validate.sh).
#   - Duplicate feed-card IDs (canonical seed only) — the NNNN filename prefix is
#     a never-reused provenance key; concurrent PRs can collide on one.
#   - Agent attribution in outgoing commit messages (CLAUDE.md § Git history
#     hygiene): "Co-Authored-By: Claude" trailers, "Generated with" footers.
#   - Denylist leaks (optional): when the gitignored local/denylist.txt exists —
#     in this checkout or, from a worktree, in the main checkout — its patterns
#     must not appear in tracked content, outgoing commit messages, or the
#     branch name. Absent file → check skipped (degrades open).
#
# Tools need no schema check: a tool is a self-contained doc under tools/, and
# its presence at a scope is its registration (see domains/exobrain/tools.md).
#
# Exits 0 if clean, 1 with a violation list if anything fails.
#
# Usage:
#   scripts/validate-exobrain.sh             # full validation
#   scripts/validate-exobrain.sh --quiet     # exit code only, no output

set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
QUIET=false
[[ "${1:-}" == "--quiet" ]] && QUIET=true

VIOLATIONS=()
record() { VIOLATIONS+=("$1"); }

# find_repo <find-expr...> — list repo files matching the expression, PRUNING
# clone/generated/vendor dirs so find never descends into them. A plain
# `-not -path` only filters output while find still walks the whole tree, which
# on a big checkout (large src/ clones, agent worktrees) makes the validator —
# and the pre-push hook that runs it — take minutes. Pruning keeps it sub-second.
find_repo() {
    find "$REPO_DIR" \
        \( -path "$REPO_DIR/.git" -o -path "$REPO_DIR/.claude" -o -path "$REPO_DIR/src" \
           -o -path "$REPO_DIR/.src" -o -path "$REPO_DIR/.worktrees" \
           -o -path "$REPO_DIR/.agent-worktrees" -o -path "$REPO_DIR/.agent-runs" \
           -o -path "$REPO_DIR/.agent-control" -o -path "$REPO_DIR/.agents" \
           -o -path "$REPO_DIR/tmp" -o -name node_modules -o -name __pycache__ \) -prune \
        -o "$@" -print 2>/dev/null
}

# ---------------------------------------------------------------------------
# AGENTS.md placement — the scope flag. Any dir may carry one (it becomes a scope);
# forbidden only inside content trees (domains/, workspaces/), where the entry point
# is README.md. Path segments may not contain the reserved scope-suffix separator
# "__".
# ---------------------------------------------------------------------------

while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel="${f#"$REPO_DIR"/}"
    [[ "$rel" == "AGENTS.md" ]] && continue   # root scope — always fine
    dir="${rel%/AGENTS.md}"
    case "$dir" in
        domains|domains/*|workspaces|workspaces/*)
            record "AGENTS.md inside a content tree (use README.md as the entry point): $rel" ;;
    esac
    [[ "$dir" == *__* ]] && record "scope path contains reserved separator '__': $rel"
done < <(find_repo -name 'AGENTS.md')

# ---------------------------------------------------------------------------
# Custom UPPERCASE.md filenames
# ---------------------------------------------------------------------------

# Recognized UPPERCASE filenames (open-source conventions + AI/tool entry-points).
ALLOWED_UPPERCASE=$'AGENTS\nREADME\nCLAUDE\nCODEX\nOPENCLAW\nSKILL\nMEMORY\nTIMELINE\nCONTRIBUTING\nLICENSE\nCHANGELOG\nCODE_OF_CONDUCT\nMAINTAINERS\nSECURITY\nNOTICE\nAUTHORS\nGOVERNANCE\nROADMAP\nUPGRADING'

while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    base="$(basename "$f" .md)"
    # Lowercase-or-mixed-case files are fine here; only flag ALL-UPPERCASE
    # (or UPPER_WITH_UNDERSCORES / UPPER-WITH-DASHES) names.
    if [[ "$base" =~ ^[A-Z][A-Z0-9_-]*$ ]]; then
        if ! grep -qxF "$base" <<<"$ALLOWED_UPPERCASE"; then
            record "Custom UPPERCASE filename: ${f#"$REPO_DIR"/} (use lowercase kebab-case unless it's a standard convention)"
        fi
    fi
done < <(find_repo -name '*.md' -not -path '*/_raw/*')

# ---------------------------------------------------------------------------
# JSON syntax — skills.json files, scopes.json files
# ---------------------------------------------------------------------------

while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if ! jq -e . "$f" >/dev/null 2>&1; then
        record "Invalid JSON: ${f#"$REPO_DIR"/}"
    fi
done < <(find_repo \( -name 'skills.json' -o -name 'scopes.json' \))

# ---------------------------------------------------------------------------
# scopes.json shape (optional file) — each entry needs type + collection; no
# collection may be named "global"; collection names must be simple segments.
# ---------------------------------------------------------------------------

if [[ -f "$REPO_DIR/scopes.json" ]] && jq -e . "$REPO_DIR/scopes.json" >/dev/null 2>&1; then
    while IFS=$'\t' read -r type collection; do
        [[ -z "$type" || "$type" == "null" ]] && record "scopes.json: entry missing 'type'"
        if [[ -z "$collection" || "$collection" == "null" ]]; then
            record "scopes.json: entry '$type' missing 'collection'"
        elif [[ "$collection" == "global" ]]; then
            record "scopes.json: collection 'global' is reserved"
        elif ! [[ "$collection" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
            record "scopes.json: collection '$collection' is not a simple kebab-case segment"
        fi
    done < <(jq -r '(.scopes // [])[] | [(.type // ""), (.collection // "")] | @tsv' "$REPO_DIR/scopes.json" 2>/dev/null)
fi

# ---------------------------------------------------------------------------
# Feed card IDs (canonical seed only) — the NNNN filename prefix is a never-reused
# provenance key (see seed/feed/README.md); two cards sharing one breaks adoption
# tracking. Concurrent PRs branched off the same trunk can each grab the next ID.
# Self-skips in a rendered instance, which carries no seed/feed.
# ---------------------------------------------------------------------------

if [[ -d "$REPO_DIR/seed/feed" ]]; then
    while IFS= read -r id; do
        [[ -z "$id" ]] && continue
        record "duplicate feed card id $id (seed/feed/$id-*.md): IDs are never-reused provenance keys"
    done < <(
        for f in "$REPO_DIR"/seed/feed/[0-9]*.md; do
            [[ -e "$f" ]] || continue
            base="$(basename "$f")"
            printf '%s\n' "${base%%-*}"
        done | sort | uniq -d
    )
fi

# ---------------------------------------------------------------------------
# Outgoing-history hygiene — the checks below look only at commits not yet on
# the remote default branch, so adopting them never flags history
# retroactively. Both need a remote default branch to diff against; without
# one (fresh clone, no remote) they're skipped. From a worktree, the main
# checkout is resolved via the shared git common dir so the gitignored local/
# scope (which worktrees don't carry) is still found.
# ---------------------------------------------------------------------------

common="$(git -C "$REPO_DIR" rev-parse --git-common-dir 2>/dev/null || true)"
MAIN_ROOT="$REPO_DIR"
if [[ -n "$common" ]]; then
    case "$common" in /*) : ;; *) common="$REPO_DIR/$common" ;; esac
    MAIN_ROOT="$(cd "$(dirname "$common")" 2>/dev/null && pwd || echo "$REPO_DIR")"
fi

default_ref="$(git -C "$REPO_DIR" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
if [[ -z "$default_ref" ]]; then
    for cand in origin/main origin/trunk origin/master; do
        if git -C "$REPO_DIR" rev-parse --verify --quiet "$cand" >/dev/null 2>&1; then
            default_ref="$cand"; break
        fi
    done
fi

# ---------------------------------------------------------------------------
# Agent-neutral history (CLAUDE.md § Git history hygiene, feed card 0024) —
# outgoing commit messages carry no agent attribution. Line-anchored so a rule
# *describing* the forbidden footer inline doesn't false-positive.
# ---------------------------------------------------------------------------

if [[ -n "$default_ref" ]]; then
    while IFS= read -r hit; do
        [[ -z "$hit" ]] && continue
        record "agent attribution in outgoing commit message: $hit"
    done < <(git -C "$REPO_DIR" log --format='%s%n%b' "$default_ref..HEAD" 2>/dev/null \
             | grep -i -E '^(co-authored-by:[[:space:]]*claude|🤖?[[:space:]]*generated with)' | head -10)
fi

# ---------------------------------------------------------------------------
# Denylist leak gate — private term list. Each non-comment line of
# local/denylist.txt (this checkout first, else the main checkout) is a
# case-insensitive ERE that must not appear in tracked content, outgoing
# commit messages, or the branch name. The list itself lives in the gitignored
# local/ scope so it never ships; absent file → skipped (degrades open).
# ---------------------------------------------------------------------------

denylist=""
for cand in "$REPO_DIR/local/denylist.txt" "$MAIN_ROOT/local/denylist.txt"; do
    [[ -f "$cand" ]] && { denylist="$cand"; break; }
done

if [[ -n "$denylist" ]]; then
    pat_file="$(mktemp "${TMPDIR:-/tmp}/exobrain-denylist.XXXXXX")"
    grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$denylist" > "$pat_file" || true
    if [[ -s "$pat_file" ]]; then
        # 1. Tracked file content (working-tree versions; untracked never scanned).
        while IFS= read -r hit; do
            [[ -z "$hit" ]] && continue
            record "denylist match in tracked content: $hit"
        done < <(git -C "$REPO_DIR" grep -I -i -n -E -f "$pat_file" -- . 2>/dev/null | head -20)

        # 2. Outgoing commit messages.
        if [[ -n "$default_ref" ]]; then
            while IFS= read -r hit; do
                [[ -z "$hit" ]] && continue
                record "denylist match in outgoing commit message: $hit"
            done < <(git -C "$REPO_DIR" log --format='%h %s%n%b' "$default_ref..HEAD" 2>/dev/null \
                     | grep -i -E -f "$pat_file" | head -10)
        fi

        # 3. Branch name.
        branch="$(git -C "$REPO_DIR" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
        if [[ -n "$branch" ]] && printf '%s\n' "$branch" | grep -q -i -E -f "$pat_file"; then
            record "denylist match in branch name: $branch"
        fi
    fi
    rm -f "$pat_file"
fi

# ---------------------------------------------------------------------------
# Skills registry — delegate to existing scripts/skills-validate.sh
# ---------------------------------------------------------------------------

if [[ -x "$REPO_DIR/scripts/skills-validate.sh" ]]; then
    skills_output="$("$REPO_DIR/scripts/skills-validate.sh" 2>&1)"
    skills_status=$?
    if [[ $skills_status -ne 0 ]]; then
        record "skills-validate.sh failed:"
        while IFS= read -r line; do
            record "  $line"
        done <<<"$skills_output"
    fi
fi

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

if [[ ${#VIOLATIONS[@]} -eq 0 ]]; then
    $QUIET || echo "exobrain validation: clean (0 violations)"
    exit 0
fi

if ! $QUIET; then
    echo "exobrain validation: ${#VIOLATIONS[@]} violation(s):"
    for v in "${VIOLATIONS[@]}"; do
        echo "  - $v"
    done
    echo ""
    echo "See AGENTS.md § Conventions for the naming and scope rules."
fi
exit 1
