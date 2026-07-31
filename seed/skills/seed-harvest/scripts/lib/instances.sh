#!/usr/bin/env bash
# Instance-list resolution for seed-harvest. Sourced by scan.sh and the tests.
#
# An entry in .exobrain.json's `instances` array is either a GitHub slug
# (`owner/repo`) or an absolute local path to a checkout. Slugs cache under
# src/<repo>/ — the same gitignored convention exobrain-evolve uses for the seed.
# The list itself never lands in a tracked file: instance names can carry an org
# or client identity, and every tracked byte of this repo is public.

# entry_kind <entry> — "path" | "slug" | "invalid"
entry_kind() {
    case "$1" in
        "" ) echo invalid ;;
        /* ) echo path ;;
        */*/* ) echo invalid ;;
        */* ) echo slug ;;
        * ) echo invalid ;;
    esac
}

# entry_name <entry> — the short repo name used for the cache dir and reports.
entry_name() {
    local e="${1%/}"
    printf '%s' "${e##*/}"
}

# entry_local_path <repo-dir> <entry> — where this instance's checkout lives.
entry_local_path() {
    local repo="$1" entry="$2"
    case "$(entry_kind "$entry")" in
        path) printf '%s' "${entry%/}" ;;
        slug) printf '%s/src/%s' "$repo" "$(entry_name "$entry")" ;;
        *) return 1 ;;
    esac
}

# entry_clone_url <entry> — https URL for a slug; empty for a local path.
entry_clone_url() {
    [[ "$(entry_kind "$1")" == slug ]] || return 0
    printf 'https://github.com/%s.git' "${1%/}"
}

# read_instances <config-file> — one entry per line from the `instances` array.
# Missing file or missing key yields nothing (exit 0) — the caller prompts.
read_instances() {
    local cfg="$1"
    [[ -f "$cfg" ]] || return 0
    jq -r '(.instances // []) | .[] | select(type == "string") | select(length > 0)' "$cfg" 2>/dev/null
}

# is_exobrain_checkout <dir> — an exobrain instance carries a root AGENTS.md and
# a scopes.json. Guards against harvesting from an unrelated repo.
is_exobrain_checkout() {
    [[ -f "$1/AGENTS.md" && -f "$1/scopes.json" ]]
}

# instance_meta_dir <dir> — the meta-domain, whatever the instance calls its
# durable-content tree (knowledge/ current, domains/ on older instances).
instance_meta_dir() {
    local d
    for d in knowledge/exobrain domains/exobrain; do
        [[ -d "$1/$d" ]] && { printf '%s' "$d"; return 0; }
    done
    return 1
}
