#!/usr/bin/env bash
# exobrain-healthcheck.sh — read-only check that this checkout is wired and
# current for the running agent. It detects five issues and SUGGESTS the fix;
# it never writes, never runs connect-agent.sh, and never pulls (see AGENTS.md →
# "Setup and relink safety" — relink and pull are human-driven):
#
#   - not connected  → suggest: scripts/connect-agent.sh <agent>
#   - links stale    → suggest: scripts/connect-agent.sh <agent> --relink
#   - trunk behind   → suggest: git pull --ff-only (in the main checkout)
#   - mount missing, behind, dirty, off its default branch, or unreachable
#     → suggest: scripts/mounts.sh enable|sync <name>, or name what sync won't touch
#   - compat shim past its removal date → name it; the fix is a change, not a command
#     (the ledger: knowledge/exobrain/compat.md)
#
# Connection markers and trunk freshness come from the main checkout. Codex
# surfaces and skills are checked in the active checkout, including a worktree.
#
# Usage:
#   scripts/exobrain-healthcheck.sh [claude|codex|openclaw] [-v]
#
# With no agent argument it checks every connected agent (or reports none).
# Always exits 0 — advisory, safe to wire into a session-start hook where a
# non-zero exit could block the session.

set -uo pipefail

VERBOSE=false
AGENT=""
for a in "$@"; do
    case "$a" in
        -v|--verbose)          VERBOSE=true ;;
        claude|codex|openclaw)  AGENT="$a" ;;
    esac
done

here="$(cd "$(dirname "$0")/.." && pwd)"
# Resolve the MAIN checkout: parent of the shared git dir. From the main
# checkout that's itself; from a worktree it's the original checkout, where
# connect-agent.sh writes the generated links.
common="$(git -C "$here" rev-parse --git-common-dir 2>/dev/null || echo "$here/.git")"
case "$common" in /*) ;; *) common="$here/$common" ;; esac
MAIN="$(cd "$(dirname "$common")" 2>/dev/null && pwd || echo "$here")"

# Generated proof that connect-agent.sh connected each agent — distinct from the
# committed .claude/settings.json, which is present in every checkout.
connected() {
    case "$1" in
        claude)   [[ -f "$MAIN/.claude/CLAUDE.md" ]] ;;
        codex)    [[ -e "$MAIN/.codex" ]] ;;
        openclaw) [[ -e "$MAIN/.openclaw" ]] ;;
    esac
}

# Where connect-agent.sh links skills/sidecars for each agent.
target_dir() {
    case "$1" in
        claude)   printf '%s' "$MAIN/.claude" ;;
        codex)    printf '%s' "$here/.agents" ;;
        openclaw) printf '%s' "${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}" ;;
    esac
}

# Where connect-agent.sh links skills — Codex uses repo-local .agents/skills; the
# others use <target_dir>/skills. (Codex resolves skills at the repo root, so the
# stale-link scan must look there, not under ~/.codex.)
skills_dir() {
    case "$1" in
        codex) printf '%s' "$here/.agents/skills" ;;
        *)     printf '%s' "$(target_dir "$1")/skills" ;;
    esac
}

# Compatibility shims past their removal date (knowledge/exobrain/compat.md § Ledger).
# Reads this checkout, not $MAIN: the ledger is tracked content, which a worktree
# carries, unlike the generated links. Advisory like the rest of this script — it
# names the shim and its date; removing it is a change the agent proposes and the
# human lands.
compat_due_report() {
    local ledger="$here/knowledge/exobrain/compat.md" today id heals remove d
    local due=()
    [[ -f "$ledger" ]] || return 0
    today="$(date +%F)"
    while IFS='|' read -r _lead id heals _files _added remove _rest; do
        id="${id// /}"; remove="${remove// /}"
        [[ "$remove" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || continue
        [[ "$today" > "$remove" ]] || continue
        heals="$(sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' <<<"$heals")"
        due+=("COMPAT $id (due $remove) — $heals")
    done < <(grep -E '^\|[[:space:]]*[0-9]{4}[[:space:]]*\|' "$ledger" 2>/dev/null)
    [[ ${#due[@]} -eq 0 ]] && return 0
    echo "⚠ ${#due[@]} compatibility shim(s) past the removal date:"
    for d in ${due[@]+"${due[@]}"}; do echo "  - $d"; done
    echo "  Remove the marked code, the tests covering it, and the ledger row (knowledge/exobrain/compat.md)."
}

problems=()

check_codex_surface() {
    local config="$here/.exobrain.json" fix leaves_text leaf resolved row name scope owner tier suffix skill
    local leaves=()
    [[ -f "$config" ]] || config="$MAIN/.exobrain.json"
    if [[ "$here" == "$MAIN" ]]; then
        fix="run: scripts/connect-agent.sh codex --relink"
    else
        fix="restore worktree links: bash scripts/link-worktree-context.sh \"$MAIN\" \"$here\""
    fi
    [[ -s "$here/AGENTS.override.md" ]] || \
        problems+=("codex: missing or empty AGENTS.override.md in $here — $fix")
    [[ -d "$here/.agents/skills" ]] || \
        problems+=("codex: missing skills directory in $here — $fix")
    if [[ -L "$here/.agents" || -L "$here/.agents/skills" ]]; then
        problems+=("codex: skills parent must be a real directory in $here; link individual skill folders")
    fi
    if ! command -v jq >/dev/null 2>&1; then
        problems+=("codex: cannot verify expected skills without jq")
        return
    fi
    if ! leaves_text="$(jq -r '(.connected_scopes // [])[]' "$config" 2>/dev/null)"; then
        problems+=("codex: cannot read connected scopes from $config")
        return
    fi
    while IFS= read -r leaf; do
        [[ -z "$leaf" ]] || leaves+=("$leaf")
    done <<< "$leaves_text"
    source "$here/scripts/skills-registry.sh"
    if ! resolved="$(skills_resolve "$here" codex ${leaves[@]+"${leaves[@]}"})"; then
        problems+=("codex: cannot resolve expected skills in $here")
        return
    fi
    while IFS= read -r row; do
        [[ -n "$row" ]] || continue
        name="${row%%$'\t'*}"; row="${row#*$'\t'}"
        scope="${row%%$'\t'*}"; row="${row#*$'\t'}"
        owner="${row%%$'\t'*}"; row="${row#*$'\t'}"
        tier="${row%%$'\t'*}"
        [[ "$tier" == always ]] || continue
        suffix="$(skills_link_suffix "$scope" "$owner")"
        skill="$here/.agents/skills/${name}${suffix:+.$suffix}/SKILL.md"
        [[ -s "$skill" ]] || problems+=("codex: missing skill $name in $here — $fix")
    done <<< "$resolved"
}

# 1. Configured at all?
if [[ ! -f "$MAIN/.exobrain.json" ]]; then
    echo "⚠ exobrain isn't set up in this checkout (no .exobrain.json)."
    echo "  Run: scripts/connect-agent.sh <claude|codex|openclaw>"
    compat_due_report
    exit 0
fi

# 2. Which agents to check — the named one, else every connected agent.
agents=()
if [[ -n "$AGENT" ]]; then
    agents=("$AGENT")
else
    for a in claude codex openclaw; do
        connected "$a" && agents+=("$a")
    done
fi

if [[ ${#agents[@]} -eq 0 ]]; then
    echo "⚠ exobrain is configured but no agent is connected here."
    echo "  Run: scripts/connect-agent.sh <claude|codex|openclaw>"
    compat_due_report
    exit 0
fi

# 3. Per agent: connected? then check its links for staleness.
for a in ${agents[@]+"${agents[@]}"}; do
    if ! connected "$a"; then
        problems+=("$a: not connected — run: scripts/connect-agent.sh $a")
        continue
    fi
    td="$(target_dir "$a")"
    [[ "$a" != codex ]] || check_codex_surface
    # Dangling symlinks among the linked skills/sidecars = stale links (a
    # skills.json change without a relink, a moved source, a partial relink).
    broken="$(find -L "$(skills_dir "$a")" "$td" -maxdepth 1 -type l 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${broken:-0}" -gt 0 ]]; then
        problems+=("$a: $broken stale link(s) under $td — run: scripts/connect-agent.sh $a --relink")
    fi
done

# fetch_age_s <git-common-dir> — seconds since origin was last fetched into that
# repository (FETCH_HEAD's mtime); a very large number when it never was.
fetch_age_s() {
    local now last=0
    now="$(date +%s)"; [[ "$now" =~ ^[0-9]+$ ]] || now=0
    if [[ -f "$1/FETCH_HEAD" ]]; then
        last="$(stat -f %m "$1/FETCH_HEAD" 2>/dev/null || stat -c %Y "$1/FETCH_HEAD" 2>/dev/null || echo 0)"
    fi
    [[ "$last" =~ ^[0-9]+$ ]] || last=0
    echo $(( now - last ))
}

# bounded_fetch <checkout> <git-common-dir> — fetch origin, throttled (skipped if
# it was fetched in the last 5 min) and bounded by a watchdog that kills it after
# 6s, so a slow or absent network degrades to silence instead of blocking startup.
# Returns 0 when fresh or fetched, 1 when the fetch failed or timed out.
bounded_fetch() {
    local dir="$1" gd="$2" fpid wpid status
    (( $(fetch_age_s "$gd") > 300 )) || return 0
    git -C "$dir" fetch --quiet origin >/dev/null 2>&1 &
    fpid=$!
    { sleep 6; kill "$fpid"; } >/dev/null 2>&1 &
    wpid=$!
    wait "$fpid" 2>/dev/null && status=0 || status=1
    kill "$wpid" 2>/dev/null || true
    wait "$wpid" 2>/dev/null || true
    return $status
}

# 4. Trunk freshness (advisory): is the MAIN checkout behind its upstream?
# Inform only — never pull.
fresh=""
branch="$(git -C "$MAIN" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
upstream="$(git -C "$MAIN" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
if [[ -n "$branch" && -n "$upstream" ]]; then
    bounded_fetch "$MAIN" "$common" || true
    behind="$(git -C "$MAIN" rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)"
    [[ "$behind" =~ ^[0-9]+$ ]] || behind=0
    (( behind > 0 )) && fresh="$branch is $behind commit(s) behind $upstream — run: git pull --ff-only (in the main checkout)"
fi

# 5. Mounts (advisory): is each mount this machine enabled present, on its
# default branch, clean, and current with its origin? The same bounded fetch
# refreshes what "current" means; nothing is pulled or reset — sync is
# scripts/mounts.sh, and anything it would not touch is only reported. A mount
# whose last successful fetch is over a day old is reported as possibly stale.
mount_notes=()
if [[ -f "$here/mounts.json" && -f "$here/scripts/skills-registry.sh" ]] && command -v jq >/dev/null 2>&1; then
    source "$here/scripts/skills-registry.sh"
    while IFS=$'\x1f' read -r m_name _; do
        [[ -n "$m_name" ]] && mount_name_ok "$m_name" || continue
        mount_enabled "$here" "$m_name" || continue
        m_dir="$(mount_dir "$here" "$m_name")"
        if ! git -C "$m_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            mount_notes+=("$m_name: enabled, but no checkout at $m_dir — run: scripts/mounts.sh enable $m_name")
            continue
        fi
        m_gd="$(git -C "$m_dir" rev-parse --absolute-git-dir 2>/dev/null)"
        bounded_fetch "$m_dir" "$m_gd" && m_fetched=true || m_fetched=false
        m_age="$(mount_fetched_age "$m_dir")"
        if [[ -z "$m_age" ]] && ! $m_fetched; then
            mount_notes+=("$m_name: origin unreachable and never fetched — its knowledge may be stale")
        elif [[ -n "$m_age" ]] && (( m_age > 86400 )); then
            mount_notes+=("$m_name: last fetched from origin $(( m_age / 86400 )) day(s) ago — its knowledge may be stale; run: scripts/mounts.sh sync $m_name")
        fi
        m_def="$(git -C "$m_dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
        m_def="${m_def#origin/}"
        if [[ -z "$m_def" ]]; then
            for c in main trunk master; do
                if git -C "$m_dir" rev-parse --verify --quiet "refs/remotes/origin/$c" >/dev/null; then m_def="$c"; break; fi
            done
        fi
        [[ -n "$m_def" ]] || { mount_notes+=("$m_name: origin's default branch unknown — run: scripts/mounts.sh sync $m_name"); continue; }
        m_br="$(git -C "$m_dir" symbolic-ref --quiet --short HEAD 2>/dev/null || echo "detached HEAD")"
        if [[ "$m_br" != "$m_def" ]]; then
            mount_notes+=("$m_name: $m_dir is on $m_br, not $m_def — sync leaves it as is")
            continue
        fi
        if [[ -n "$(git -C "$m_dir" status --porcelain --untracked-files=no 2>/dev/null)" ]]; then
            mount_notes+=("$m_name: uncommitted changes in $m_dir — change a mount through its own worktree and persist flow")
            continue
        fi
        read -r m_ahead m_behind < <(git -C "$m_dir" rev-list --left-right --count "HEAD...origin/$m_def" 2>/dev/null || echo "0 0")
        if (( m_ahead > 0 )); then
            mount_notes+=("$m_name: $m_ahead local commit(s) on $m_def not on origin — sync leaves it as is")
        elif (( m_behind > 0 )); then
            mount_notes+=("$m_name: $m_behind commit(s) behind origin/$m_def — run: scripts/mounts.sh sync $m_name")
        fi
    done < <(mounts_list "$here")
fi

# Output — connection problems, the freshness advisory, mount notes, and due compat
# shims are independent; print whichever fired, else (verbose) the all-clear.
compat="$(compat_due_report)"

if [[ ${#problems[@]} -gt 0 ]]; then
    echo "⚠ exobrain connection needs attention:"
    for p in ${problems[@]+"${problems[@]}"}; do echo "  - $p"; done
    echo "  Suggestions only — connect-agent.sh is run by you, the human, not the agent."
fi

[[ -n "$fresh" ]] && echo "⚠ $fresh"
if [[ ${#mount_notes[@]} -gt 0 ]]; then
    echo "⚠ mount(s) need attention:"
    for p in ${mount_notes[@]+"${mount_notes[@]}"}; do echo "  - $p"; done
fi
[[ -n "$compat" ]] && echo "$compat"

if [[ ${#problems[@]} -eq 0 && -z "$fresh" && ${#mount_notes[@]} -eq 0 && -z "$compat" ]]; then
    $VERBOSE && echo "✓ exobrain: ${agents[*]} connected and linked ($here), trunk current ($MAIN)."
fi
exit 0
