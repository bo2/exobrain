#!/usr/bin/env bash
# mounts.sh — manage this checkout's mounts: other exobrain instances whose
# knowledge domains it reads from a local checkout. mounts.json declares them;
# .exobrain.json holds each machine's state. See knowledge/exobrain/mounts.md.
#
#   mounts.sh status [<name>]               # each declared mount and its checkout; no network
#   mounts.sh enable <name> [--path <dir>]  # clone into src/<name>/ (or verify <dir>), then enable
#   mounts.sh disable <name>                # stop indexing it; the checkout stays where it is
#   mounts.sh sync [<name>]                 # fetch, then fast-forward a clean checkout on its default branch
#
# A pull of this instance runs sync from the post-merge and post-rewrite hooks
# connect-agent.sh installs. enable and disable write only .exobrain.json and the
# new clone; neither relinks,
# so run scripts/connect-agent.sh --relink afterwards for the knowledge index to
# follow. sync never resets, stashes, rebases, or switches branches: a
# checkout that is dirty, off its default branch, ahead, or diverged is reported
# and left as it is. Each repository's default branch is resolved from its origin.
#
# Exit: 0 ok | 1 a mount needs attention | 2 usage error.

set -uo pipefail
# A pull hook can run this with the host repository's GIT_DIR (and friends)
# exported — git exports them for `git --git-dir=… pull` — and left set, they
# would point every `git -C <mount>` below at the host instead.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_PREFIX

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=skills-registry.sh
source "$SCRIPT_DIR/skills-registry.sh"

usage() { sed -n '2,17s/^# \{0,1\}//p' "$0"; }
die_usage() { echo "mounts.sh: $1" >&2; echo "Run: scripts/mounts.sh --help" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || { echo "mounts.sh: jq is required" >&2; exit 2; }

# declared_field <name> <field#> — a field of the mount's mounts.json entry
# (1 name, 2 repo, 3 audience, 4 skip_domains); empty when undeclared.
declared_field() {
    local want="$1" n="$2" row
    row="$(mounts_list "$REPO_DIR" | awk -F$'\x1f' -v w="$want" '$1 == w { print; exit }')"
    [[ -n "$row" ]] || return 0
    awk -F$'\x1f' -v n="$n" '{ print $n }' <<< "$row"
}

require_declared() {
    local name="$1"
    mount_name_ok "$name" || die_usage "'$name' is not a mount name (kebab-case)"
    [[ -n "$(declared_field "$name" 1)" ]] || die_usage "'$name' is not declared in mounts.json"
}

# url_key <url> — a repository URL reduced to host/path, so the https, ssh, and
# scp-like spellings of one repository compare equal.
url_key() {
    local u="$1"
    u="${u#file://}"; u="${u#ssh://}"; u="${u#https://}"; u="${u#http://}"; u="${u#git://}"
    u="${u#*@}"
    [[ "$u" == /* ]] || u="${u/://}"
    u="${u%/}"; u="${u%.git}"
    printf '%s' "$u" | tr '[:upper:]' '[:lower:]'
}

# config_write_target — the real file behind the state-holding .exobrain.json. A
# worktree's copy is a link to the main checkout's; writing through tmp + mv would
# replace the link with a private copy, so the link is resolved first.
config_write_target() {
    local cfg; cfg="$(mounts_config_file "$REPO_DIR")"
    while [[ -L "$cfg" ]]; do
        local t; t="$(readlink "$cfg")"
        case "$t" in /*) cfg="$t" ;; *) cfg="$(dirname "$cfg")/$t" ;; esac
    done
    printf '%s' "$cfg"
}

# set_state <name> <jq-filter-on-the-entry> [<path>] — update .mounts[<name>],
# keeping every other key of the file and of the entry; the filter sees <path>
# as $p.
set_state() {
    local name="$1" filter="$2" cfg existing='{}'
    cfg="$(config_write_target)"
    [[ -f "$cfg" ]] && existing="$(cat "$cfg")"
    jq --arg n "$name" --arg p "${3:-}" ".mounts = ((.mounts // {}) | .[\$n] = ((.[\$n] // {}) | $filter))" <<< "$existing" \
        > "$cfg.tmp.$$" && mv "$cfg.tmp.$$" "$cfg"
}

relink_hint() { echo "  Next: scripts/connect-agent.sh --relink"; }

# default_branch <dir> [online] — the origin's default branch. With "online", an
# unset origin/HEAD is asked of the remote first; offline, the conventional names
# are tried among the refs already fetched.
default_branch() {
    local dir="$1" online="${2:-}" ref c
    ref="$(git -C "$dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"
    if [[ -z "$ref" && "$online" == online ]]; then
        git -C "$dir" remote set-head origin --auto >/dev/null 2>&1 || true
        ref="$(git -C "$dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"
    fi
    if [[ -n "$ref" ]]; then printf '%s' "${ref#origin/}"; return 0; fi
    for c in main trunk master; do
        if git -C "$dir" rev-parse --verify --quiet "refs/remotes/origin/$c" >/dev/null; then printf '%s' "$c"; return 0; fi
    done
}

# fetch_age <dir> — "fetched 3h ago"-style age of the last successful fetch.
fetch_age() {
    local s; s="$(mount_fetched_age "$1")"
    if   [[ -z "$s" ]];   then echo "never fetched"
    elif (( s < 3600 ));  then echo "fetched $((s / 60))m ago"
    elif (( s < 86400 )); then echo "fetched $((s / 3600))h ago"
    else                        echo "fetched $((s / 86400))d ago"
    fi
}

is_checkout() { [[ -d "$1" ]] && git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1; }

# state_line <dir> <default> — branch · ahead/behind · clean/dirty, from local refs.
state_line() {
    local dir="$1" def="$2" br ahead behind dirty
    br="$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null || echo "detached HEAD")"
    dirty="clean"
    [[ -z "$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null)" ]] || dirty="uncommitted changes"
    if [[ -z "$def" ]]; then
        printf 'on %s · default branch unknown (run sync) · %s' "$br" "$dirty"; return
    fi
    read -r ahead behind < <(git -C "$dir" rev-list --left-right --count "HEAD...origin/$def" 2>/dev/null || echo "? ?")
    printf 'on %s%s · %s ahead, %s behind origin/%s · %s' "$br" \
        "$([[ "$br" == "$def" ]] && echo "" || echo " (default: $def)")" "$ahead" "$behind" "$def" "$dirty"
}

cmd_status() {
    local only="${1:-}" rows name repo audience skip dir
    [[ -z "$only" ]] || require_declared "$only"
    rows="$(mounts_list "$REPO_DIR")"
    if [[ -z "$rows" ]]; then echo "No mounts declared (mounts.json)."; return 0; fi
    while IFS=$'\x1f' read -r name repo audience skip; do
        [[ -n "$name" ]] && mount_name_ok "$name" || continue
        [[ -z "$only" || "$name" == "$only" ]] || continue
        dir="$(mount_dir "$REPO_DIR" "$name")"
        echo "$name — readable by $audience"
        echo "  repo:  $repo"
        if ! mount_enabled "$REPO_DIR" "$name"; then
            echo "  state: not enabled on this machine — scripts/mounts.sh enable $name"
        elif ! is_checkout "$dir"; then
            echo "  state: enabled, but no checkout at $dir — scripts/mounts.sh enable $name"
        else
            echo "  path:  $dir"
            echo "  state: $(state_line "$dir" "$(default_branch "$dir")") · $(fetch_age "$dir")"
        fi
    done <<< "$rows"
    return 0
}

cmd_enable() {
    local name="" path_arg=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)   path_arg="${2:-}"; [[ -n "$path_arg" ]] || die_usage "--path needs a directory"; shift ;;
            --path=*) path_arg="${1#*=}" ;;
            -*)       die_usage "unknown option $1" ;;
            *)        [[ -z "$name" ]] || die_usage "one mount at a time"; name="$1" ;;
        esac
        shift
    done
    [[ -n "$name" ]] || die_usage "enable needs a mount name"
    require_declared "$name"
    local repo dir
    repo="$(declared_field "$name" 2)"
    if [[ -n "$path_arg" ]]; then
        case "$path_arg" in
            "~")   path_arg="$HOME" ;;
            "~/"*) path_arg="$HOME/${path_arg#"~/"}" ;;
            /*)    ;;
            *)     path_arg="$(pwd)/$path_arg" ;;
        esac
        dir="${path_arg%/}"
    else
        dir="$(mount_dir "$REPO_DIR" "$name")"
    fi

    if [[ -e "$dir" ]]; then
        is_checkout "$dir" || { echo "✗ $dir exists but is not a git checkout — pick another --path" >&2; return 1; }
        local origin
        origin="$(git -C "$dir" remote get-url origin 2>/dev/null)"
        if [[ "$(url_key "$origin")" != "$(url_key "$repo")" ]]; then
            echo "✗ $dir is a checkout of '${origin:-no origin}', not $repo — left untouched" >&2
            return 1
        fi
        git -C "$dir" fetch --quiet origin 2>/dev/null || echo "  (could not fetch origin — the checkout is used as it is)"
        echo "✓ $name: using the existing checkout at $dir ($(fetch_age "$dir"))"
    else
        mkdir -p "$(dirname "$dir")"
        echo "Cloning $repo into $dir …"
        git clone --quiet "$repo" "$dir" || { echo "✗ clone failed — nothing recorded" >&2; return 1; }
        touch "$(git -C "$dir" rev-parse --absolute-git-dir)/exobrain-last-fetch"
        echo "✓ $name: cloned"
    fi

    if [[ -n "$path_arg" ]]; then
        set_state "$name" '.enabled = true | .path = $p' "$dir" || return 1
    else
        set_state "$name" '.enabled = true' || return 1
    fi
    echo "✓ $name enabled in $(config_write_target)"
    relink_hint
}

cmd_disable() {
    local name="${1:-}"
    [[ -n "$name" ]] || die_usage "disable needs a mount name"
    require_declared "$name"
    set_state "$name" '.enabled = false'
    echo "✓ $name disabled; its checkout at $(mount_dir "$REPO_DIR" "$name") is left in place"
    relink_hint
}

# domain_set <dir> — the mount's domain dirs, one line, to tell whether a sync
# changed what the knowledge index lists.
domain_set() { (cd "$1" && ls -d knowledge/*/README.md 2>/dev/null | tr '\n' ' '); }

sync_one() {
    local name="$1" dir def br ahead behind before
    dir="$(mount_dir "$REPO_DIR" "$name")"
    if ! is_checkout "$dir"; then
        echo "! $name: no checkout at $dir — scripts/mounts.sh enable $name"; return 1
    fi
    if ! git -C "$dir" fetch --quiet origin 2>/dev/null; then
        echo "! $name: could not fetch origin — using the checkout as it is ($(fetch_age "$dir"))"; return 1
    fi
    mount_fetched_age "$dir" >/dev/null
    def="$(default_branch "$dir" online)"
    [[ -n "$def" ]] || { echo "! $name: cannot tell origin's default branch — left as is"; return 1; }
    br="$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null || echo "detached HEAD")"
    if [[ "$br" != "$def" ]]; then
        echo "! $name: on $br, not its default branch $def — left as is"; return 1
    fi
    if [[ -n "$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null)" ]]; then
        echo "! $name: uncommitted changes in $dir — left as is"; return 1
    fi
    read -r ahead behind < <(git -C "$dir" rev-list --left-right --count "HEAD...origin/$def" 2>/dev/null || echo "0 0")
    if (( ahead > 0 && behind > 0 )); then
        echo "! $name: diverged from origin/$def ($ahead ahead, $behind behind) — left as is"; return 1
    fi
    if (( ahead > 0 )); then
        echo "! $name: $ahead commit(s) on $def not on origin — left as is"; return 1
    fi
    if (( behind == 0 )); then echo "✓ $name: up to date with origin/$def"; return 0; fi
    before="$(domain_set "$dir")"
    if ! git -C "$dir" merge --ff-only --quiet "origin/$def" >/dev/null 2>&1; then
        echo "! $name: fast-forward to origin/$def failed — left as is"; return 1
    fi
    echo "✓ $name: fast-forwarded $behind commit(s) to origin/$def"
    if [[ "$(domain_set "$dir")" != "$before" ]]; then
        echo "  Its domains changed; the knowledge index follows on relink:"
        relink_hint
    fi
    return 0
}

cmd_sync() {
    local only="${1:-}" rows name rc=0 any=false
    [[ -z "$only" ]] || require_declared "$only"
    rows="$(mounts_list "$REPO_DIR")"
    while IFS=$'\x1f' read -r name _; do
        [[ -n "$name" ]] || continue
        [[ -z "$only" || "$name" == "$only" ]] || continue
        mount_name_ok "$name" || continue
        if ! mount_enabled "$REPO_DIR" "$name"; then
            if [[ -n "$only" ]]; then echo "! $name: not enabled on this machine — scripts/mounts.sh enable $name"; rc=1; fi
            continue
        fi
        any=true
        sync_one "$name" || rc=1
    done <<< "$rows"
    if ! $any && [[ -z "$only" ]]; then echo "No mounts enabled on this machine."; fi
    return $rc
}

case "${1:-}" in
    status)         shift; cmd_status "$@" ;;
    enable)         shift; cmd_enable "$@" ;;
    disable)        shift; cmd_disable "$@" ;;
    sync)           shift; cmd_sync "$@" ;;
    -h|--help|help) usage ;;
    "")             usage >&2; exit 2 ;;
    *)              die_usage "unknown command '$1'" ;;
esac
