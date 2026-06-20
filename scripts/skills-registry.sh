#!/usr/bin/env bash
# skills-registry.sh — resolve effective skills tiers for a connected agent.
#
# Format (declaration / override model)
# -------------------------------------
# A skills.json lives in a scope directory and holds two record kinds:
#
#   DECLARATION (no `from`) — introduces a skill that lives in THIS scope's
#       skills/<name>/ folder. The folder is its home scope, so a declaration
#       carries no scope field. Holds `owner` (who to ask; also whose connection
#       auto-enables it), a recommended `tier`, and an optional `force` flag.
#   OVERRIDE (`from` set) — references a skill declared in another scope (`from`
#       = that home scope, or "external") and sets a tier for the referencing
#       scope. Used to opt in (any tier) or opt out (`off`).
#
# Resolution reads the skills.json of every scope in the connected chain (see
# build_scope_chain) shallow (global) → deep, keyed by the skill's identity
# (home-scope + name, or external + name + owner):
#
#   - a declaration contributes its tier IFF `force` is true OR `owner` is one of
#     the connecting user's self ids (a connected person-scope leaf basename);
#   - an override always contributes its tier (including `off`);
#   - the deepest contribution wins; a skill with no contribution is off.
#
# Placement therefore expresses only POTENTIAL audience — a skill dropped in a
# shared scope reaches just its owner until someone sets `force` (a reviewed act)
# or another scope overrides it in. Everyone else discovers it via
# `skills-status.sh --all` and opts in with an override.
#
# Scope model (generalized — a scope is any dir with an AGENTS.md)
# ---------------------------------------------------------------
# A skill's home scope is the repo-relative path of its declaring directory; the
# special value "global" is the repo root, and "external" marks a fetched
# third-party skill. The resolver discovers scopes from the filesystem rather
# than assuming a fixed ladder.
#
#   home = "global"            → <repo>/skills/<name>/                 (owner free metadata)
#   home = "<path>"            → <repo>/<path>/skills/<name>/          (e.g. people/oleg, groups/acme)
#   home = "external"          → fetched into the agent's skills dir as <name>.<owner>/
#
# tier values: always | optional | unlisted | off
#
# Public functions
# ----------------
#   build_scope_chain <repo_dir> <leaf...>
#       Print the connected scope chain as repo-relative scope values, one per
#       line, shallow→deep, deduped. Always starts with "global". A scope is
#       included iff that directory contains an AGENTS.md, so non-scope
#       collection dirs (people/, hosts/, …) are skipped automatically.
#
#   owner_self_ids <repo_dir> <leaf...>
#       JSON array of the connecting user's "self" owner ids — the leaf basenames
#       of connected person-type scopes. A declaration auto-enables for its owner;
#       these are the ids that satisfy that owner-match.
#
#   skills_resolve <repo_dir> <agent> <leaf...>
#       TSV: <name>\t<home-scope>\t<owner>\t<tier>\t<declared-by>, sorted by name.
#       One row per skill with an effective (possibly off) tier. home-scope drives
#       skills_dir_for / skills_link_suffix exactly like a scope column, so
#       downstream consumers are unchanged. When <agent> is non-empty, drops
#       entries whose `agent` is set and != <agent>, or whose `skipAgents`
#       contains <agent>. Empty disables that filter.
#
#   skills_dir_for <repo_dir> <home-scope> <owner> <name>
#       Absolute path to the skill directory implied by (home-scope, owner, name).
#       Empty for external (caller resolves the $TARGET_DIR-relative target).
#
#   skills_link_suffix <home-scope> <owner>  — filename suffix for the symlink
#   scope_type_for <repo_dir> <scope>        — human type label for a scope
#   scopes_collection_for_type <repo_dir> <type> — collection dir for a scope type
#   sanitize_suffix <path>                   — filename-safe form of a scope path
#   skills_resolve_external_json <repo_dir> <agent> <leaf...>
#                                            — JSON array of resolved external skills
#   skills_extract_description <skill_md>    — YAML frontmatter `description`
#   tools_resolve <repo_dir> <leaf...>       — TSV <name>\t<doc-path> of visible tools
#   tools_extract_summary <tool_md>          — the tool doc's one-line purpose

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

# build_scope_chain <repo_dir> <leaf...>
# For each connected leaf, walk its path segments from the root down; a segment
# prefix is a scope iff that directory contains an AGENTS.md. Union across leaves,
# dedup, sort shallow→deep (then by path for a stable order among equal depths).
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
                # if/fi (not &&) so a false test doesn't leave the loop — and thus
                # the whole function — with a non-zero status under a `set -e` caller.
                if [[ -f "$repo_dir/$prefix/AGENTS.md" ]]; then
                    printf '%s\t%s\n' "$depth" "$prefix"
                fi
            done
        done
    } | sort -t$'\t' -k1,1n -k2,2 -u | cut -f2
}

# owner_self_ids <repo_dir> <leaf...> — JSON array of the connecting user's "self"
# owner ids. A declaration auto-enables for its owner, so these are the ids that
# satisfy owner-match. The authoritative source is the explicit `person` key in
# `.exobrain.json` (string or array) — identity is location-independent, not a
# function of where the person scope sits. When that key is absent (older configs,
# or callers that pass leaves with no config), fall back to deriving ids from the
# basenames of connected person-type scopes.
owner_self_ids() {
    local repo_dir="$1"; shift
    local cfg="$repo_dir/.exobrain.json" stored
    if [[ -f "$cfg" ]]; then
        stored="$(jq -c '(.person // empty) | if type == "array" then . else [.] end' "$cfg" 2>/dev/null)"
        if [[ -n "$stored" && "$stored" != "[]" && "$stored" != "null" ]]; then echo "$stored"; return; fi
    fi
    local s ids=()
    while IFS= read -r s; do
        [[ -z "$s" || "$s" == "global" ]] && continue
        [[ "$(scope_type_for "$repo_dir" "$s")" == "person" ]] && ids+=("${s##*/}")
    done < <(build_scope_chain "$repo_dir" "$@")
    if [[ ${#ids[@]} -eq 0 ]]; then echo '[]'; else printf '%s\n' "${ids[@]}" | jq -R . | jq -cs .; fi
}

# skills_resolve <repo_dir> <agent> <leaf...>
# Resolve effective skill tiers across the connected chain under the declaration/
# override model. Emits TSV: name<TAB>home-scope<TAB>owner<TAB>tier<TAB>declared-by,
# one row per skill with an effective (non-off) tier, sorted by name. home-scope
# drives skills_dir_for / skills_link_suffix exactly like the old `scope` column,
# so downstream consumers (connect-agent, status, validate) are unchanged.
#
#   declaration (no `from`) — contributes its tier IFF force==true OR owner is a
#       connected self id.
#   override    (`from` set) — always contributes its tier (incl. off) at its
#       declaring depth.
#   Deepest contribution wins; a skill with no contribution is off (omitted).
skills_resolve() {
    local repo_dir="$1" agent="$2"; shift 2
    local self; self="$(owner_self_ids "$repo_dir" "$@")"
    local depth=0 scope f
    {
        while IFS= read -r scope; do
            if [[ "$scope" == "global" ]]; then f="$repo_dir/skills.json"; else f="$repo_dir/$scope/skills.json"; fi
            [[ -f "$f" ]] && jq -c --arg s "$scope" --argjson d "$depth" \
                '(.skills // [])[] | . + {_scope:$s, _depth:$d}' "$f" 2>/dev/null
            depth=$((depth + 1))
        done < <(build_scope_chain "$repo_dir" "$@")
    } | jq -rs --arg agent "$agent" --argjson self "$self" '
        def idof:
            if (.from // null) != null
            then (if .from == "external" then "external|\(.name)|\(.owner)" else "\(.from)|\(.name)" end)
            else (if (.source // null) != null then "external|\(.name)|\(.owner)" else "\(._scope)|\(.name)" end)
            end;
        ( map(select(
            $agent == "" or (
                ((.agent // "") == "" or (.agent // "") == $agent)
                and (((.skipAgents // []) | index($agent)) | not)
            )
          )) ) as $all
        | ( [ $all[] | select((.from // null) == null)
              | { key: idof,
                  value: { home: (if (.source // null) != null then "external" else ._scope end),
                           owner: (.owner // "") } } ]
            | from_entries ) as $meta
        | [ $all[]
            | { id: idof, depth: ._depth, tier: .tier, src: ._scope,
                keep: ( if (.from // null) != null then true
                        else ( (.force // false)
                               or ( .owner as $o | ($self | index($o)) != null ) ) end ) } ]
        | map(select(.keep))
        | group_by(.id)
        | map( (sort_by([.depth, .src]) | last) as $w
               | { id: $w.id, tier: $w.tier, src: $w.src,
                   home:  ($meta[$w.id].home  // ($w.id | split("|")[0])),
                   owner: ($meta[$w.id].owner // (if ($w.id | startswith("external|")) then ($w.id | split("|")[2]) else "" end)) } )
        | .[]
        | [ (.id | split("|")[1]), .home, .owner, .tier, .src ] | @tsv
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
# external skills key on the author; everything else on the sanitized home-scope
# path (so people/oleg and groups/acme/people/oleg never collide).
skills_link_suffix() {
    local scope="$1" owner="$2"
    case "$scope" in
        global|"") echo "" ;;
        external)  sanitize_suffix "$owner" ;;
        *)         sanitize_suffix "$scope" ;;
    esac
}

# skills_resolve_external_json <repo_dir> <agent> <leaf...>
# JSON array of external skills with effective tier + source, under the
# declaration/override model. An external skill is a declaration carrying
# `source` (identity = name+owner, the source author). Its effective tier follows
# the same rules as in-tree: the declaration fires iff force or owner-self;
# overrides with from="external" apply; deepest wins; no contribution = off.
# Output per skill: {name, owner, tier, source}. The fetcher consumes this.
skills_resolve_external_json() {
    local repo_dir="$1" agent="$2"; shift 2
    local self; self="$(owner_self_ids "$repo_dir" "$@")"
    local depth=0 scope f
    {
        while IFS= read -r scope; do
            if [[ "$scope" == "global" ]]; then f="$repo_dir/skills.json"; else f="$repo_dir/$scope/skills.json"; fi
            [[ -f "$f" ]] && jq -c --arg s "$scope" --argjson d "$depth" \
                '(.skills // [])[] | . + {_scope:$s, _depth:$d}' "$f" 2>/dev/null
            depth=$((depth + 1))
        done < <(build_scope_chain "$repo_dir" "$@")
    } | jq -s --arg agent "$agent" --argjson self "$self" '
        def extid: "\(.name)|\(.owner)";
        ( map(select(
            $agent == "" or (
                ((.agent // "") == "" or (.agent // "") == $agent)
                and (((.skipAgents // []) | index($agent)) | not)
            )
          )) ) as $all
        | ( [ $all[] | select((.from // null) == null and .source != null)
              | { key: extid, value: { name: .name, owner: .owner, source: .source } } ]
            | from_entries ) as $meta
        | ( [ $all[]
              | select( ((.from // null) == "external") or ((.from // null) == null and .source != null) )
              | { id: extid, depth: ._depth, tier: .tier,
                  keep: ( if (.from // null) == "external" then true
                          else ( (.force // false)
                                 or ( .owner as $o | ($self | index($o)) != null ) ) end ) } ]
            | map(select(.keep)) ) as $contribs
        | [ $meta | to_entries[]
            | .key as $id | .value as $m
            | ($contribs | map(select(.id == $id))) as $cs
            | (if ($cs | length) > 0 then ($cs | sort_by(.depth) | last | .tier) else "off" end) as $eff
            | { name: $m.name, owner: $m.owner, tier: $eff, source: $m.source } ]
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

# tools_resolve <repo_dir> <leaf...>
# Resolve the visible tool catalog across the connected chain. Unlike skills,
# tools carry no tiers/force/owner — a tool doc's presence at a scope lists it for
# everyone whose chain includes that scope. Walk build_scope_chain shallow→deep,
# glob each scope's tools/*.md (excluding README.md and the example-tool template),
# and dedupe by name with the deepest scope winning on collision. Emits TSV:
# <name>\t<repo-relative-doc-path>, sorted by name.
tools_resolve() {
    local repo_dir="$1"; shift
    local scope dir f name rel
    {
        while IFS= read -r scope; do
            if [[ "$scope" == "global" ]]; then dir="$repo_dir/tools"; else dir="$repo_dir/$scope/tools"; fi
            [[ -d "$dir" ]] || continue
            for f in "$dir"/*.md; do
                [[ -e "$f" ]] || continue   # guard the no-match literal glob
                name="$(basename "$f" .md)"
                [[ "$name" == "README" || "$name" == "example-tool" ]] && continue
                rel="${f#"$repo_dir"/}"
                printf '%s\t%s\n' "$name" "$rel"
            done
        done < <(build_scope_chain "$repo_dir" "$@")
    } | awk -F'\t' '{ last[$1] = $0 } END { for (k in last) print last[k] }' | sort
    # build_scope_chain emits shallow→deep, so the last line per name is the
    # deepest scope's — awk keeps it; the final sort restores name order.
}

# tools_extract_summary <tool_md> — the tool doc's one-line purpose: the first
# non-blank, non-heading content line (skipping any leading YAML frontmatter).
# Mirrors skills_extract_description, but tool docs open with prose rather than a
# frontmatter field, so it reads the first content line instead.
tools_extract_summary() {
    local file="$1"
    [[ -f "$file" ]] || { echo ""; return 0; }
    awk '
        BEGIN { in_fm = 0 }
        NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; next }
        in_fm && /^---[[:space:]]*$/  { in_fm = 0; next }
        in_fm { next }
        /^[[:space:]]*$/ { next }   # skip blank lines
        /^#/ { next }               # skip headings
        { print; exit }
    ' "$file"
}
