#!/usr/bin/env bash
# scan.sh — the mechanical half of seed-harvest: resolve the instance list, make
# each checkout available, and report where an instance's framework files differ
# from this seed's. Judgment (is this difference universal?) stays with the agent.
#
#   scan.sh --list            resolve the list; print name/kind/path/state
#   scan.sh --fetch           clone-or-pull each slug into src/, then --list
#   scan.sh --drift [name]    per-instance framework drift vs this seed
#
# Read-only with respect to your working checkouts: a local-path entry is never
# pulled, fetched, or written. Only slug entries touch the network, and only into
# the gitignored src/ cache.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/instances.sh
. "$HERE/lib/instances.sh"

REPO_DIR="${SEED_HARVEST_REPO:-$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null || pwd)}"
CONFIG="${SEED_HARVEST_CONFIG:-$REPO_DIR/.exobrain.json}"

mode="${1:---list}"
want="${2:-}"

entries=()
while IFS= read -r e; do [[ -n "$e" ]] && entries+=("$e"); done < <(read_instances "$CONFIG")

if [[ ${#entries[@]} -eq 0 ]]; then
    cat >&2 <<'EOF'
seed-harvest: no instances configured.

Add the exobrain instances to harvest from to .exobrain.json (gitignored,
per-machine — the list never lands in a tracked file):

  { "instances": ["owner/repo", "/abs/path/to/a/checkout"] }
EOF
    exit 3
fi

# Two slugs from different owners can share a repo name and would then resolve to
# the same src/ cache dir — silently harvesting one repo twice. Refuse rather than
# guess which was meant.
dupes="$(for e in ${entries[@]+"${entries[@]}"}; do printf '%s\n' "$(entry_local_path "$REPO_DIR" "$e" 2>/dev/null)"; done | sort | uniq -d)"
if [[ -n "$dupes" ]]; then
    echo "seed-harvest: these instances resolve to the same local path:" >&2
    printf '  %s\n' $dupes >&2
    echo "Give one of them an explicit absolute path in .exobrain.json." >&2
    exit 4
fi

# state_of <path> — what we can say about a checkout without touching it.
state_of() {
    local p="$1"
    [[ -d "$p" ]] || { echo "absent"; return; }
    is_exobrain_checkout "$p" || { echo "not-an-exobrain"; return; }
    if [[ -n "$(git -C "$p" status --porcelain 2>/dev/null)" ]]; then echo "dirty"; else echo "clean"; fi
}

do_fetch() {
    local e kind path url
    for e in ${entries[@]+"${entries[@]}"}; do
        kind="$(entry_kind "$e")"
        [[ "$kind" == slug ]] || { printf 'skip\t%s\t(local path — left untouched)\n' "$(entry_name "$e")"; continue; }
        path="$(entry_local_path "$REPO_DIR" "$e")"
        url="$(entry_clone_url "$e")"
        if [[ -d "$path/.git" ]]; then
            if git -C "$path" pull --ff-only >/dev/null 2>&1; then
                printf 'pulled\t%s\t%s\n' "$(entry_name "$e")" "$path"
            else
                printf 'stale\t%s\t%s (pull failed — using cached state)\n' "$(entry_name "$e")" "$path"
            fi
        else
            mkdir -p "$(dirname "$path")"
            if git clone --quiet "$url" "$path" >/dev/null 2>&1; then
                printf 'cloned\t%s\t%s\n' "$(entry_name "$e")" "$path"
            else
                printf 'failed\t%s\t%s (clone failed — check access)\n' "$(entry_name "$e")" "$url"
            fi
        fi
    done
}

do_list() {
    local e path
    printf '%s\t%s\t%s\t%s\n' NAME KIND STATE PATH
    for e in ${entries[@]+"${entries[@]}"}; do
        path="$(entry_local_path "$REPO_DIR" "$e" 2>/dev/null || echo '-')"
        printf '%s\t%s\t%s\t%s\n' "$(entry_name "$e")" "$(entry_kind "$e")" "$(state_of "$path")" "$path"
    done
}

# Framework files whose path is stable enough to diff mechanically. The meta-domain
# is resolved per instance (knowledge/ now, domains/ on older ones).
framework_paths() {
    printf '%s\n' AGENTS.md CLAUDE.md CODEX.md OPENCLAW.md skills.schema.json tools/README.md
    (cd "$REPO_DIR" && ls scripts/*.sh 2>/dev/null)
    (cd "$REPO_DIR" && ls -d skills/exobrain-* 2>/dev/null)
}

# report_diff <label> <seed-file> <their-file> — emit a `differs` row with a size
# hint (+added/-removed) so the agent can triage before reading each diff. A file
# the instance lacks is silently skipped: it means the instance is behind, which is
# adoption's business, not the harvest's.
report_diff() {
    local label="$1" mine="$2" theirs="$3" add del
    [[ -e "$theirs" ]] || return 0
    diff -q "$mine" "$theirs" >/dev/null 2>&1 && return 0
    add="$(diff "$mine" "$theirs" 2>/dev/null | grep -c '^>' || true)"
    del="$(diff "$mine" "$theirs" 2>/dev/null | grep -c '^<' || true)"
    printf 'differs\t%s\t+%s/-%s\n' "$label" "$add" "$del"
}

do_drift() {
    local e name path meta seed_meta f rel
    seed_meta="$(instance_meta_dir "$REPO_DIR" || echo knowledge/exobrain)"
    for e in ${entries[@]+"${entries[@]}"}; do
        name="$(entry_name "$e")"
        [[ -n "$want" && "$want" != "$name" ]] && continue
        path="$(entry_local_path "$REPO_DIR" "$e" 2>/dev/null || true)"
        printf '\n=== %s (%s) ===\n' "$name" "${path:--}"
        if [[ ! -d "$path" ]] || ! is_exobrain_checkout "$path"; then
            printf 'unavailable\t(run --fetch, or fix the path)\n'; continue
        fi
        meta="$(instance_meta_dir "$path" || echo '')"

        while IFS= read -r f; do
            [[ -n "$f" ]] || continue
            if [[ -d "$REPO_DIR/$f" ]]; then
                while IFS= read -r rel; do
                    report_diff "$rel" "$REPO_DIR/$rel" "$path/$rel"
                done < <(cd "$REPO_DIR" && find "$f" -type f | sort -u)
            else
                report_diff "$f" "$REPO_DIR/$f" "$path/$f"
            fi
        done < <(framework_paths)

        # The meta-domain, mapped across the knowledge/ vs domains/ rename.
        if [[ -n "$meta" ]]; then
            while IFS= read -r rel; do
                report_diff "$meta/$rel" "$REPO_DIR/$seed_meta/$rel" "$path/$meta/$rel"
            done < <(cd "$REPO_DIR/$seed_meta" && ls *.md 2>/dev/null)
        fi

        # Things this instance has that the seed lacks — the richest harvest lane.
        while IFS= read -r rel; do
            [[ -e "$REPO_DIR/skills/$rel" ]] || printf 'only-there\tskills/%s\n' "$rel"
        done < <(cd "$path/skills" 2>/dev/null && ls -d */ 2>/dev/null | tr -d /)
        while IFS= read -r rel; do
            [[ -e "$REPO_DIR/scripts/$rel" ]] || printf 'only-there\tscripts/%s\n' "$rel"
        done < <(cd "$path/scripts" 2>/dev/null && ls *.sh 2>/dev/null)
    done
}

case "$mode" in
    --list) do_list ;;
    --fetch) do_fetch; echo; do_list ;;
    --drift) do_drift ;;
    *) echo "usage: scan.sh [--list|--fetch|--drift [name]]" >&2; exit 2 ;;
esac
