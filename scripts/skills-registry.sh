#!/usr/bin/env bash
# skills-registry.sh — resolve effective skills tiers for a connected agent.
#
# Format
# ------
# Each skills.json declares a list of explicit (name, scope, owner, tier)
# entries. Skills are physical directories at any scope but stay inert until a
# skills.json references them. Resolution reads the skills.json of every scope
# in the connected chain (see build_scope_chain) in priority order — shallow
# (global) to deep — keyed by (name, scope, owner). Deepest scope wins.
#
# Scope model (generalized)
# -------------------------
# A scope is any directory containing an AGENTS.md. Its `scope` value is the
# repo-relative path of that directory; the special value "global" is the repo
# root, and "external" marks a fetched third-party skill.
#
#   scope = "global"            → <repo>/skills/<name>/                 (owner "")
#   scope = "<path>"            → <repo>/<path>/skills/<name>/          (owner = leaf id)
#   scope = "external"          → fetched into <TARGET_DIR>/skills/<name>.<owner>/
#
# Entries may reference a skill owned by a *different* scope than the file they
# live in (that is how skills-promote.sh pins a deeper scope's tier onto a
# shallower scope's skill). So the entry's declared scope/owner identify the
# skill directory; the file the entry lives in only sets its priority.
#
# tier values: always | optional | off
#
# Public functions
# ----------------
#   build_scope_chain <repo_dir> <leaf...>
#       Print the connected scope chain as repo-relative scope values, one per
#       line, shallow→deep, deduped. Always starts with "global". A scope is
#       included iff that directory contains an AGENTS.md, so non-scope
#       collection dirs (people/, hosts/, …) are skipped automatically.
#
#   skills_resolve <repo_dir> <agent> <leaf...>
#       TSV: <name>\t<scope>\t<owner>\t<tier>\t<declared-by>, sorted by name.
#       declared-by is the scope path whose skills.json contributed the winning
#       entry. When <agent> is non-empty, drops entries whose `agent` is set and
#       != <agent>, or whose `skipAgents` contains <agent>. Empty disables it.
#
#   skills_dir_for <repo_dir> <scope> <owner> <name>
#       Absolute path to the skill directory implied by (scope, owner, name).
#       Empty for external (caller resolves the $TARGET_DIR-relative target).
#
#   skills_link_suffix <scope> <owner>     — filename suffix for the symlink
#   scope_type_for <repo_dir> <scope>      — human type label for a scope
#   scopes_collection_for_type <repo_dir> <type> — collection dir for a scope type
#   scopes_container_collections <repo_dir>      — collections that can hold a person
#   sanitize_suffix <path>                 — filename-safe form of a scope path
#   skills_extract_description <skill_md>  — YAML frontmatter `description`

# sanitize_suffix <path> — filename-safe scope suffix. "/" → "__" (a separator
# that can't be confused with a hyphen in an id), everything else lowercased and
# non-[a-z0-9._-] replaced with "-". people/oleg → people__oleg.
sanitize_suffix() {
    local p="$1"
    p="${p//\//__}"
    printf '%s' "$p" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g'
}

# scope_type_for <repo_dir> <scope> — type label for display (group/person/host/…).
# Looks up the parent collection dir in scopes.json; falls back to a sensible
# guess from the collection name. Pure cosmetics — wiring never depends on it.
scope_type_for() {
    local repo_dir="$1" scope="$2"
    [[ -z "$scope" || "$scope" == "global" ]] && { echo "global"; return; }
    local parent="${scope%/*}" coll
    coll="${parent##*/}"
    local label=""
    if [[ -f "$repo_dir/scopes.json" ]]; then
        label="$(jq -r --arg c "$coll" '(.scopes // [])[] | select(.collection==$c) | .type' \
            "$repo_dir/scopes.json" 2>/dev/null | head -1)"
    fi
    [[ -n "$label" && "$label" != "null" ]] && { echo "$label"; return; }
    case "$coll" in
        people) echo person ;;
        groups) echo group ;;
        teams)  echo team ;;
        hosts)  echo host ;;
        *)      echo "${coll:-scope}" ;;
    esac
}

# scopes_collection_for_type <repo_dir> <type> — collection dir name for a scope
# type (person→people, host→hosts, …), read from scopes.json. The inverse of
# scope_type_for; falls back to the conventional plural for known types. Pure
# vocabulary — wiring never depends on it; the setup wizard uses it to place scopes.
scopes_collection_for_type() {
    local repo_dir="$1" type="$2" coll=""
    if [[ -f "$repo_dir/scopes.json" ]] && command -v jq >/dev/null 2>&1; then
        coll="$(jq -r --arg t "$type" '(.scopes // [])[] | select(.type==$t) | .collection' \
            "$repo_dir/scopes.json" 2>/dev/null | head -1)"
    fi
    if [[ -z "$coll" || "$coll" == "null" ]]; then
        case "$type" in
            person) coll=people ;;
            host)   coll=hosts ;;
            team)   coll=teams ;;
            group)  coll=groups ;;
            *)      coll="${type}s" ;;
        esac
    fi
    printf '%s' "$coll"
}

# scopes_container_collections <repo_dir> — collection names that can *contain* a
# person scope: every scopes.json collection except the person and host pinpoint
# collections, in scopes.json order. The setup wizard uses these to offer "a
# person under a <group|team>" shapes.
scopes_container_collections() {
    local repo_dir="$1" person_coll host_coll
    person_coll="$(scopes_collection_for_type "$repo_dir" person)"
    host_coll="$(scopes_collection_for_type "$repo_dir" host)"
    if [[ -f "$repo_dir/scopes.json" ]] && command -v jq >/dev/null 2>&1; then
        jq -r --arg p "$person_coll" --arg h "$host_coll" \
            '(.scopes // [])[] | .collection | select(. != $p and . != $h)' \
            "$repo_dir/scopes.json" 2>/dev/null
    else
        printf '%s\n' groups teams
    fi
}

# build_scope_chain <repo_dir> <leaf...>
build_scope_chain() {
    local repo_dir="$1"; shift
    {
        printf '0\tglobal\n'
        local leaf
        for leaf in "$@"; do
            leaf="${leaf#/}"; leaf="${leaf%/}"
            [[ -z "$leaf" || "$leaf" == "global" ]] && continue
            local prefix="" seg depth=0
            local oldIFS="$IFS"; IFS='/'; local segs=($leaf); IFS="$oldIFS"
            for seg in "${segs[@]}"; do
                [[ -z "$seg" ]] && continue
                prefix="${prefix:+$prefix/}$seg"
                depth=$((depth + 1))
                [[ -f "$repo_dir/$prefix/AGENTS.md" ]] && printf '%s\t%s\n' "$depth" "$prefix"
            done
        done
    } | sort -t$'\t' -k1,1n -k2,2 -u | cut -f2
}

# _emit_scope <skills_json> <declared-by> <agent>
_emit_scope() {
    local file="$1" declared_by="$2" agent="$3"
    [[ -f "$file" ]] || return 0
    jq -r --arg d "$declared_by" --arg a "$agent" '
        (.skills // [])
        | .[]
        | select(
            $a == ""
            or (
                ((.agent // "") == "" or (.agent // "") == $a)
                and (((.skipAgents // []) | index($a)) | not)
            )
          )
        | [.name, .scope, .owner, .tier, $d] | @tsv
    ' "$file" 2>/dev/null || true
}

skills_resolve() {
    local repo_dir="$1" agent="$2"; shift 2
    local leaves=("$@") scope
    {
        while IFS= read -r scope; do
            if [[ "$scope" == "global" ]]; then
                _emit_scope "$repo_dir/skills.json" "global" "$agent"
            else
                _emit_scope "$repo_dir/$scope/skills.json" "$scope" "$agent"
            fi
        done < <(build_scope_chain "$repo_dir" "${leaves[@]}")
    } | awk -F'\t' '
        # Key on (name, scope, owner): same name in two scopes = two entries.
        # Last write wins; the chain feeds shallow→deep so deeper scopes win.
        { key = $1 "\t" $2 "\t" $3; row[key] = $0 }
        END { for (k in row) print row[k] }
    ' | sort
}

skills_dir_for() {
    local repo_dir="$1" scope="$2" owner="$3" name="$4"
    case "$scope" in
        global|"") echo "$repo_dir/skills/$name" ;;
        external)  echo "" ;; # caller handles target-dir-relative path
        *)         echo "$repo_dir/$scope/skills/$name" ;;
    esac
}

# Suffix in the symlink filename: <name>.<suffix>. Global skills get no suffix;
# external skills key on the author; everything else on the sanitized scope path
# (so people/oleg and groups/acme/people/oleg never collide).
skills_link_suffix() {
    local scope="$1" owner="$2"
    case "$scope" in
        global|"") echo "" ;;
        external)  sanitize_suffix "$owner" ;;
        *)         sanitize_suffix "$scope" ;;
    esac
}

# skills_resolve_external_json <repo_dir> <agent> <leaf...>
# JSON array of resolved external entries with full metadata. Tier resolved
# across scopes (deepest wins); source/skipAgents/notes/agent taken from
# whichever scope declares them.
skills_resolve_external_json() {
    local repo_dir="$1" agent="$2"; shift 2
    local leaves=("$@")
    local files=() prio=0 scope f
    while IFS= read -r scope; do
        if [[ "$scope" == "global" ]]; then f="$repo_dir/skills.json"; else f="$repo_dir/$scope/skills.json"; fi
        [[ -f "$f" ]] && files+=("$prio:$f")
        prio=$((prio + 1))
    done < <(build_scope_chain "$repo_dir" "${leaves[@]}")

    {
        local entry prio_val path
        for entry in "${files[@]}"; do
            prio_val="${entry%%:*}"
            path="${entry#*:}"
            jq --argjson p "$prio_val" \
               '(.skills // []) | map(select(.scope == "external") | . + {_prio: $p})' \
               "$path" 2>/dev/null
        done
    } | jq -s --arg a "$agent" '
        flatten
        | group_by([.name, .owner])
        | map(
            (max_by(._prio)) as $top
            | (map(select(.source))     | first | .source)     as $src
            | (map(select(.skipAgents)) | first | .skipAgents) as $skip
            | (map(select(.notes))      | first | .notes)      as $notes
            | (map(select(.agent))      | first | .agent)      as $agentf
            | $top
            | del(._prio)
            | if $src    then .source     = $src    else . end
            | if $skip   then .skipAgents = $skip   else . end
            | if $notes  then .notes      = $notes  else . end
            | if $agentf then .agent      = $agentf else . end
          )
        | map(select(
            $a == ""
            or (
                ((.agent // "") == "" or (.agent // "") == $a)
                and (((.skipAgents // []) | index($a)) | not)
            )
          ))
        | sort_by([.name, .owner])
    '
}

skills_extract_description() {
    local file="$1"
    [[ -f "$file" ]] || { echo ""; return 0; }
    awk '
        BEGIN { in_fm = 0 }
        /^---$/ { in_fm = !in_fm; if (!in_fm) exit; next }
        in_fm && /^description:/ {
            sub(/^description:[[:space:]]*/, "")
            if (length($0) >= 2 && (substr($0, 1, 1) == "\"" || substr($0, 1, 1) == "'\''")) {
                q = substr($0, 1, 1)
                sub("^" q, "")
                sub(q "$", "")
            }
            print
            exit
        }
    ' "$file"
}
