#!/usr/bin/env bash
# connect-agent.sh — wire exobrain scope content into an AI agent's surface.
#
#   connect-agent.sh <claude|codex|openclaw> [--relink] [--configure] [--render-specs-only]
#                     [--handle <id>] [--host <name>] [--scope <path>]... [--guest]
#
# A scope is any directory containing an AGENTS.md. The connected scopes (recorded
# in .exobrain.json `connected_scopes`) plus each one's AGENTS.md-bearing ancestors
# are unioned and resolved innermost-wins — skills, specs, the optional-skills
# index. See knowledge/exobrain/ for the model.
#
# Identity is resolved from one of four sources, in precedence order:
#   explicit flags (--handle/--host/--scope/--guest)  >  existing/parent config  >
#   interactive prompts (first-time setup)             >  guest (global only).
# --handle/--host name-match a person/host scope and connect the deepest EXISTING
# one (host leaf, else person) — flags never scaffold; only the interactive wizard
# does. --scope adds any standalone scope; --guest connects nothing.
# The connecting person's id is stored as `person` for skill owner-match.
#
# Agent surfaces — each agent gets its OWN surface; no two agents ever write the
# same generated file (the composed content is agent-specific — filtered skills
# index, per-agent paths — so a shared file would let the last writer clobber it):
#   claude   → .claude/CLAUDE.md @-imports .claude/connected-scopes.md (a manifest of
#              live source specs) + .claude/optional-skills.md + .claude/tools-index.md
#              + .claude/knowledge-index.md
#   codex    → in-repo AGENTS.override.md (read natively; outranks AGENTS.md at the
#              same dir level); skills in repo-local .agents/skills/
#   openclaw → ~/.openclaw/workspace/USER.md, marker-block injection
#
# --render-specs-only builds the in-repo context surface (scope specs, skills,
# optional-skills index, per-agent injection) and stops before any write outside
# the target dir — no shell-profile edits, no sibling clones, no git hooks, no
# connect marker. It lets a throwaway copy (a test sandbox, a CI checkout) be
# wired exactly like a real checkout with zero global side effects. Codex's
# surface lands entirely in the checkout (AGENTS.override.md, .agents/skills);
# openclaw's USER.md lands in the OPENCLAW_WORKSPACE copy dir, which a render
# requires to be set — it refuses rather than default to the real home config.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=skills-registry.sh
source "$SCRIPT_DIR/skills-registry.sh"

# --------------------------------------------------------------------------
# Linking helpers
# --------------------------------------------------------------------------

link_path() {
    local src="${1%/}" dst="$2" label="$3"
    [[ -e "$src" || -d "$src" ]] || return 0
    if [[ -L "$dst" ]]; then
        local existing; existing="$(readlink "$dst")"
        if [[ "${existing%/}" == "$src" ]]; then echo "  ✓ $label"; return; fi
        rm "$dst"
    elif [[ -e "$dst" ]]; then
        echo "  SKIP $label (real path exists, remove manually)"; return
    fi
    ln -s "$src" "$dst"
    echo "  + $label"
}

clean_stale() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0
    find "$dir" -maxdepth 1 -type l ! -exec test -e {} \; -delete 2>/dev/null || true
}

# inject_block <file> <block_id> <content_file> <label>
inject_block() {
    local file="$1" block_id="$2" content_file="$3" label="$4"
    local begin="<!-- BEGIN $block_id -->" end="<!-- END $block_id -->"
    if [[ ! -f "$file" ]]; then
        { echo "$begin"; cat "$content_file"; echo "$end"; } > "$file"
        echo "  + $label (created)"
    elif grep -qF "$begin" "$file" && grep -qF "$end" "$file"; then
        awk -v begin="$begin" -v end="$end" -v cfile="$content_file" '
            $0 == begin { print; while ((getline line < cfile) > 0) print line; skip=1; next }
            $0 == end   { skip=0; print; next }
            !skip { print }
        ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
        echo "  ✓ $label (updated)"
    else
        { echo ""; echo "$begin"; cat "$content_file"; echo "$end"; } >> "$file"
        echo "  + $label (block appended)"
    fi
}

install_hook() {
    echo ""; echo "Installing git hooks..."
    local hooks_dir hook_tmp
    # --git-common-dir answers relative to the repo, so anchor it there: resolved
    # against the caller's cwd instead, a connect run from outside the checkout
    # writes its hooks into whatever directory the human happened to be standing in.
    hooks_dir="$(git -C "$REPO_DIR" rev-parse --git-common-dir)"
    [[ "$hooks_dir" == /* ]] || hooks_dir="$REPO_DIR/$hooks_dir"
    hooks_dir="$hooks_dir/hooks"
    mkdir -p "$hooks_dir"

    # Re-link after pulling new commits. `post-merge` fires on `git pull`
    # (fast-forward and merge); `post-rewrite` fires on `git pull --rebase`
    # (guarded to skip plain `commit --amend`). Both keep the agent surface fresh.
    hook_tmp="$hooks_dir/post-merge.tmp.$$"
    cat > "$hook_tmp" << 'HOOK'
#!/usr/bin/env bash
# Auto-generated by connect-agent.sh — re-links exobrain after a merge/pull.
REPO_DIR="$(git rev-parse --show-toplevel)"
for a in claude codex openclaw; do
    "$REPO_DIR/scripts/connect-agent.sh" "$a" --relink 2>/dev/null || true
done
HOOK
    chmod +x "$hook_tmp"; mv -f "$hook_tmp" "$hooks_dir/post-merge"
    echo "  ✓ $hooks_dir/post-merge"

    hook_tmp="$hooks_dir/post-rewrite.tmp.$$"
    cat > "$hook_tmp" << 'HOOK'
#!/usr/bin/env bash
# Auto-generated by connect-agent.sh — re-links after a rebase-based pull.
[[ "$1" == "rebase" ]] || exit 0   # ignore commit --amend
REPO_DIR="$(git rev-parse --show-toplevel)"
for a in claude codex openclaw; do
    "$REPO_DIR/scripts/connect-agent.sh" "$a" --relink 2>/dev/null || true
done
HOOK
    chmod +x "$hook_tmp"; mv -f "$hook_tmp" "$hooks_dir/post-rewrite"
    echo "  ✓ $hooks_dir/post-rewrite"

    hook_tmp="$hooks_dir/pre-push.tmp.$$"
    cat > "$hook_tmp" << 'HOOK'
#!/usr/bin/env bash
# Auto-generated by connect-agent.sh — validates exobrain conventions before push.
REPO_DIR="$(git rev-parse --show-toplevel)"
if [[ -x "$REPO_DIR/scripts/validate-exobrain.sh" ]]; then
    "$REPO_DIR/scripts/validate-exobrain.sh" || {
        echo "Push blocked by exobrain validation. Fix the above, or 'git push --no-verify'." >&2
        exit 1
    }
fi
HOOK
    chmod +x "$hook_tmp"; mv -f "$hook_tmp" "$hooks_dir/pre-push"
    echo "  ✓ $hooks_dir/pre-push"
}

is_interactive() { [[ -t 0 && -t 1 ]]; }

# --------------------------------------------------------------------------
# Config + wizard
# --------------------------------------------------------------------------

CONFIG="$REPO_DIR/.exobrain.json"
CONNECTED_LEAVES=()
PERSON_ID=""   # the connecting user's person id; persisted as .person for owner-match
PERSON_PATH="" # resolved person scope path (set by resolve_identity)
HOST_PATH=""   # resolved host scope path   (set by resolve_identity)

load_config() {
    [[ -f "$CONFIG" ]] || return 1
    local arr
    arr="$(jq -r '(.connected_scopes // []) | .[]' "$CONFIG" 2>/dev/null)" || return 1
    CONNECTED_LEAVES=()
    while IFS= read -r l; do [[ -n "$l" ]] && CONNECTED_LEAVES+=("$l"); done <<< "$arr"
    PERSON_ID="$(jq -r '(.person // "")' "$CONFIG" 2>/dev/null)"
    return 0
}

# save_config — write connected_scopes[] + agents[] + person, preserving any other
# keys (e.g. a tools block owned by a setup skill). `person` is written only when
# PERSON_ID is set, so a guest/host-only connection leaves it absent.
save_config() {
    local leaves_json agents_json existing="{}"
    [[ -f "$CONFIG" ]] && existing="$(cat "$CONFIG")"
    if [[ ${#CONNECTED_LEAVES[@]} -eq 0 ]]; then
        leaves_json='[]'
    else
        leaves_json="$(printf '%s\n' ${CONNECTED_LEAVES[@]+"${CONNECTED_LEAVES[@]}"} | jq -R . | jq -s .)"
    fi
    agents_json="$(jq -r '(.agents // [])' <<< "$existing" 2>/dev/null || echo '[]')"
    agents_json="$(jq --arg a "$AGENT" '. as $cur | ($cur + [$a]) | unique' <<< "$agents_json")"
    jq -n --argjson e "$existing" --argjson c "$leaves_json" --argjson ag "$agents_json" --arg p "$PERSON_ID" \
        '$e + {connected_scopes: $c, agents: $ag} + (if $p == "" then {} else {person: $p} end)' \
        > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
    echo "  ✓ $CONFIG"
}

# scaffold_scope <path> <type-label> — create a scope dir with a stub AGENTS.md.
scaffold_scope() {
    local path="$1" label="$2"
    local dir="$REPO_DIR/$path"
    mkdir -p "$dir"
    if [[ ! -f "$dir/AGENTS.md" ]]; then
        local id="${path##*/}"
        printf '# %s — %s scope\n\nAgent context specific to this %s.\n' "$id" "$label" "$label" \
            > "$dir/AGENTS.md"
        echo "  + $path/AGENTS.md ($label scope)"
    fi
}

# Scope discovery (find_scope_by_name, list_connectable_scopes) and handle
# classification (person_scope_ids, handle_taken_by, is_generic_handle) come from
# skills-registry.sh.

# resolve_identity <handle> <host> — set PERSON_PATH, HOST_PATH, PERSON_ID by
# name-match (person anywhere; host within the person's subtree), falling back to
# the conventional collection location when a scope doesn't exist yet.
resolve_identity() {
    local handle="$1" host="$2" person_coll host_coll found line
    person_coll="$(scopes_collection_for_type "$REPO_DIR" person)"
    host_coll="$(scopes_collection_for_type "$REPO_DIR" host)"
    found="$(find_scope_by_name "$REPO_DIR" "$handle" "$person_coll")"
    PERSON_PATH="${found%%$'\n'*}"
    [[ -z "$PERSON_PATH" ]] && PERSON_PATH="$person_coll/$handle"
    HOST_PATH=""
    found="$(find_scope_by_name "$REPO_DIR" "$host" "$host_coll")"
    while IFS= read -r line; do
        [[ -n "$line" && "$line" == "$PERSON_PATH/"* ]] && { HOST_PATH="$line"; break; }
    done <<< "$found"
    [[ -z "$HOST_PATH" ]] && HOST_PATH="$PERSON_PATH/$host_coll/$host"
    PERSON_ID="$handle"
}

# sanitize_id <raw> — lowercase, restrict to [a-z0-9._-] for a scope leaf id.
sanitize_id() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g'; }

# multi_select <preselect-csv> <item...> — a checkbox menu on /dev/tty. Items whose
# path is in the comma-separated <preselect-csv> start checked. Sets the SELECTED
# variable (a local declared by the caller) to the checked items, in listed order.
multi_select() {
    local preselect="$1"; shift
    # `checked` is an indexed array parallel to `items` (0/1 per position), not an
    # associative array keyed by path: bash 3.2 has no `declare -A`. The loops count
    # positions rather than expanding `${!items[@]}`, which errors on an empty array
    # under `set -u` in that same shell.
    local items=("$@") idx input n mark _pre p
    local checked=()
    for ((idx = 0; idx < ${#items[@]}; idx++)); do checked[$idx]=0; done
    IFS=',' read -r -a _pre <<< "$preselect"
    # `if` blocks, not a trailing `[[ … ]] && …`: a loop whose final iteration tests
    # false ends non-zero, and a loop that closes a function's body hands that status
    # to a `set -e` caller — which aborts the wizard. Same reason below.
    for p in ${_pre[@]+"${_pre[@]}"}; do
        [[ -n "$p" ]] || continue
        for ((idx = 0; idx < ${#items[@]}; idx++)); do
            if [[ "${items[$idx]}" == "$p" ]]; then checked[$idx]=1; fi
        done
    done
    while true; do
        echo "" >/dev/tty
        echo "Scopes to connect (type a number to toggle, Enter to accept):" >/dev/tty
        n=1
        for ((idx = 0; idx < ${#items[@]}; idx++)); do
            mark="[ ]"; [[ "${checked[$idx]}" == 1 ]] && mark="[x]"
            printf '  %2d. %s %s\n' "$n" "$mark" "${items[$idx]}" >/dev/tty
            n=$((n + 1))
        done
        printf 'Toggle # (Enter to accept): ' >/dev/tty
        read -r input </dev/tty || true
        [[ -z "$input" ]] && break
        if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#items[@]} )); then
            idx=$((input - 1))
            checked[$idx]=$(( 1 - ${checked[$idx]} ))
        else
            echo "  ? enter a listed number, or Enter to accept" >/dev/tty
        fi
    done
    SELECTED=()
    for ((idx = 0; idx < ${#items[@]}; idx++)); do
        if [[ "${checked[$idx]}" == 1 ]]; then SELECTED+=("${items[$idx]}"); fi
    done
}

# prompt_handle <default> — ask on /dev/tty until the answer is a usable person id,
# then echo it. Three gates, because identity is name-matched and the id sticks:
#   - a machine login (admin, root, ubuntu, …) is never offered as the default and
#     is confirmed before it is accepted — it names a role, not a person;
#   - an id an existing person scope holds is confirmed too, since connecting joins
#     that person's scope rather than making one;
#   - an id a non-person scope holds is refused: name-match would wire that scope in.
prompt_handle() {
    local default="$1" id ans taken type path
    is_generic_handle "$default" && default=""
    while true; do
        if [[ -n "$default" ]]; then
            printf 'Your handle (a short id for your person scope) [%s]: ' "$default" >/dev/tty
        else
            printf 'Your handle (a short id naming you, not your machine login): ' >/dev/tty
        fi
        read -r id </dev/tty || true
        id="$(sanitize_id "${id:-$default}")"
        [[ -n "$id" ]] || { echo "  ? a handle is required" >/dev/tty; continue; }
        default=""
        if is_generic_handle "$id"; then
            printf "  ! '%s' is a machine login, not a person — it names nobody and collides on the next machine.\n" "$id" >/dev/tty
            printf "    Use it anyway? [y/N]: " >/dev/tty
            read -r ans </dev/tty || true
            [[ "$ans" =~ ^[Yy] ]] || continue
        fi
        taken="$(handle_taken_by "$REPO_DIR" "$id")"
        [[ -n "$taken" ]] || { printf '%s' "$id"; return; }
        type="${taken%% *}"; path="${taken#* }"
        if [[ "$type" == person ]]; then
            printf "  ! '%s' is an existing person scope (%s) — connecting joins it.\n" "$id" "$path" >/dev/tty
            printf "    Is that you? [y/N]: " >/dev/tty
            read -r ans </dev/tty || true
            [[ "$ans" =~ ^[Yy] ]] && { printf '%s' "$id"; return; }
        else
            printf "  ! '%s' already names a %s scope (%s) — that handle would connect it. Pick another.\n" \
                "$id" "$type" "$path" >/dev/tty
        fi
    done
}

# run_wizard — interactive first-time setup. Prompt for handle + host, resolve and
# scaffold the person/host scopes by name, then present every connectable scope as a
# checkbox menu with person + host pre-checked. The connector treats whatever is
# selected as a flat list of scope paths; nothing here knows person/host are special
# beyond proposing them as the default selection.
run_wizard() {
    echo ""
    echo "First-time setup for this exobrain."

    local default_id default_host id host existing
    default_id="$(git -C "$REPO_DIR" config user.email 2>/dev/null | sed 's/@.*//' || true)"
    [[ -z "$default_id" ]] && default_id="${USER:-me}"
    default_host="$(hostname -s 2>/dev/null || echo localhost)"

    existing="$(person_scope_ids "$REPO_DIR" | tr '\n' ' ')"
    [[ -n "$existing" ]] && echo "People already here: ${existing% }" >/dev/tty

    id="$(prompt_handle "$default_id")"
    printf 'This machine name (host scope) [%s]: ' "$default_host" >/dev/tty
    read -r host </dev/tty || true; host="$(sanitize_id "${host:-$default_host}")"

    resolve_identity "$id" "$host"
    scaffold_scope "$PERSON_PATH" person
    scaffold_scope "$HOST_PATH" host

    local items=() s SELECTED=()
    while IFS= read -r s; do [[ -n "$s" ]] && items+=("$s"); done < <(list_connectable_scopes "$REPO_DIR")
    multi_select "$PERSON_PATH,$HOST_PATH" ${items[@]+"${items[@]}"}

    CONNECTED_LEAVES=( ${SELECTED[@]+"${SELECTED[@]}"} )
    # Keep the person id only if the person scope was actually connected.
    PERSON_ID=""
    for s in ${SELECTED[@]+"${SELECTED[@]}"}; do
        if [[ "$s" == "$PERSON_PATH" ]]; then PERSON_ID="$id"; fi
    done
    save_config
}

# resolve_from_flags — non-interactive identity from explicit flags. Used by
# create-instance and the bootstrap test (which gather the answers themselves) and
# any scripted setup. --guest connects nothing; --handle (+ --host) connects the
# deepest EXISTING scope for the handle — the host leaf if that dir exists, else
# the person scope — and never scaffolds: flags are the scripted path
# (create-instance and CI pre-create their scope dirs; the interactive wizard is
# the scaffolding path). With no existing scope it connects nothing beyond
# --scope, with a notice. --scope adds standalone scope paths verbatim.
resolve_from_flags() {
    CONNECTED_LEAVES=(); PERSON_ID=""
    if ! $FLAG_GUEST && [[ -n "$FLAG_HANDLE" ]]; then
        local handle host
        handle="$(sanitize_id "$FLAG_HANDLE")"
        host="$(sanitize_id "${FLAG_HOST:-$(hostname -s 2>/dev/null || echo localhost)}")"
        resolve_identity "$handle" "$host"
        if [[ -f "$REPO_DIR/$HOST_PATH/AGENTS.md" ]]; then
            CONNECTED_LEAVES+=("$HOST_PATH")
        elif [[ -f "$REPO_DIR/$PERSON_PATH/AGENTS.md" ]]; then
            CONNECTED_LEAVES+=("$PERSON_PATH")
        else
            echo "  ! no existing scope for '$handle' — connecting without a person scope" >&2
            echo "    (run the interactive wizard, or create $PERSON_PATH/AGENTS.md, then reconnect)" >&2
            PERSON_ID=""
        fi
    fi
    local s
    for s in ${FLAG_SCOPES[@]+"${FLAG_SCOPES[@]}"}; do
        s="${s#/}"; s="${s%/}"
        [[ -n "$s" ]] && CONNECTED_LEAVES+=("$s")
    done
    save_config
}

# --------------------------------------------------------------------------
# Argument parsing + agent setup
# --------------------------------------------------------------------------

AGENT="" ; RELINK=false ; CONFIGURE=false ; RENDER_ONLY=false
FLAG_HANDLE="" ; FLAG_HOST="" ; FLAG_SCOPES=() ; FLAG_GUEST=false
USAGE="Usage: $0 <claude|codex|openclaw> [--relink] [--configure] [--render-specs-only]
              [--handle <id>] [--host <name>] [--scope <path>]... [--guest]"
while [[ $# -gt 0 ]]; do
    case "$1" in
        claude|codex|openclaw) AGENT="$1" ;;
        --relink)             RELINK=true ;;
        --configure)          CONFIGURE=true ;;
        --render-specs-only)  RENDER_ONLY=true ;;
        --handle)             FLAG_HANDLE="${2:-}"; shift ;;
        --handle=*)           FLAG_HANDLE="${1#*=}" ;;
        --host)               FLAG_HOST="${2:-}"; shift ;;
        --host=*)             FLAG_HOST="${1#*=}" ;;
        --scope)              FLAG_SCOPES+=("${2:-}"); shift ;;
        --scope=*)            FLAG_SCOPES+=("${1#*=}") ;;
        --guest)              FLAG_GUEST=true ;;
        *) echo "$USAGE" >&2; exit 2 ;;
    esac
    shift
done
[[ -n "$AGENT" ]] || { echo "$USAGE" >&2; exit 2; }

# Hard dependency: jq drives config persistence and skills resolution. Fail
# early with an install hint rather than deep inside the run with a cryptic error.
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed." >&2
    case "$(uname -s)" in
        Darwin) echo "  Install with: brew install jq" >&2 ;;
        Linux)  echo "  Install with: apt-get install jq  (or your distro's package manager)" >&2 ;;
    esac
    exit 1
fi

# Each agent's connect marker is a file this script generates — proof a human
# connected that agent here. Claude's is its composed surface, not the .claude/
# directory: that directory ships in every clone (the committed settings.json),
# so its presence proves nothing. The healthcheck tests the same paths.
case "$AGENT" in
    claude)   MARKER="$REPO_DIR/.claude/CLAUDE.md"; TARGET_DIR="$REPO_DIR/.claude"
              AGENT_SIDECAR="CLAUDE.md";   AGENT_SIDECAR_BASE="CLAUDE" ;;
    codex)    MARKER="$REPO_DIR/.codex";    TARGET_DIR="${CODEX_HOME:-$HOME/.codex}"
              AGENT_SIDECAR="CODEX.md";    AGENT_SIDECAR_BASE="CODEX" ;;
    openclaw) MARKER="$REPO_DIR/.openclaw"; TARGET_DIR="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
              AGENT_SIDECAR="OPENCLAW.md"; AGENT_SIDECAR_BASE="OPENCLAW" ;;
esac

# --render-specs-only promises no writes outside the checkout, but openclaw
# delivers part of its surface into TARGET_DIR — the real home config dir when
# the override isn't set — and codex's legacy cleanups (COMPAT 0001/0002/0003)
# prune connector-written files there. Refuse up front rather than touch the
# home dir and call it a render. The codex arm retires with those shims.
if $RENDER_ONLY; then
    case "$AGENT" in
        codex)    [[ -n "${CODEX_HOME:-}" ]] || {
                      echo "--render-specs-only for codex runs legacy home-dir cleanups against CODEX_HOME (default ~/.codex)." >&2
                      echo "Set CODEX_HOME to a throwaway dir first, e.g.: CODEX_HOME=\$(mktemp -d) $0 codex --render-specs-only" >&2
                      exit 1
                  } ;;
        openclaw) [[ -n "${OPENCLAW_WORKSPACE:-}" ]] || {
                      echo "--render-specs-only for openclaw writes USER.md into OPENCLAW_WORKSPACE (default ~/.openclaw/workspace)." >&2
                      echo "Set OPENCLAW_WORKSPACE to a throwaway dir first, e.g.: OPENCLAW_WORKSPACE=\$(mktemp -d) $0 openclaw --render-specs-only" >&2
                      exit 1
                  } ;;
    esac
fi

# Where this agent's always-tier skills are linked. Most agents read skills from
# their context surface ($TARGET_DIR/skills). Codex is the exception: it scans a
# repo-local .agents/skills (cwd→repo-root), so its skills go there — keeping them
# out of the global ~/.codex config, scoped to this repo. SKILLS_OPTIONAL_DIR is the
# sibling the external-skill fetcher derives the same way.
case "$AGENT" in
    codex) SKILLS_DIR="$REPO_DIR/.agents/skills" ;;
    *)     SKILLS_DIR="$TARGET_DIR/skills" ;;
esac
SKILLS_OPTIONAL_DIR="$(dirname "$SKILLS_DIR")/skills-optional"

# On --relink, do nothing unless this agent has a marker (the user connected it).
if $RELINK; then
    [[ -e "$MARKER" ]] || exit 0
fi

# --------------------------------------------------------------------------
# Resolve config
# --------------------------------------------------------------------------

# Identity source, in precedence order:
#   explicit flags  >  existing/parent config  >  interactive prompts  >  guest
flags_given=false
if $FLAG_GUEST || [[ -n "$FLAG_HANDLE" || -n "$FLAG_HOST" || ${#FLAG_SCOPES[@]} -gt 0 ]]; then
    flags_given=true
fi

if $flags_given; then
    resolve_from_flags
elif $CONFIGURE || ! load_config; then
    # --relink / --render-specs-only never prompt or write config: with no config
    # they render as guest (global scope only). A real first-time setup is
    # interactive; a headless run with no flags and no config is guest.
    if ! $RELINK && ! $RENDER_ONLY && is_interactive; then
        run_wizard
    else
        CONNECTED_LEAVES=()
    fi
fi
# else: load_config populated CONNECTED_LEAVES + PERSON_ID from existing config.

GUEST_MODE=false
[[ ${#CONNECTED_LEAVES[@]} -eq 0 ]] && GUEST_MODE=true

# Warn on any connected leaf that isn't actually a scope (no AGENTS.md), but
# keep going — its AGENTS.md-bearing ancestors still wire in.
for leaf in "${CONNECTED_LEAVES[@]:-}"; do
    [[ -z "$leaf" ]] && continue
    if [[ ! -f "$REPO_DIR/$leaf/AGENTS.md" ]]; then
        echo "  ! connected leaf '$leaf' has no AGENTS.md (not a scope) — using its scope ancestors only"
        echo "    renamed or removed? re-run identity setup: scripts/connect-agent.sh $AGENT --configure"
    fi
done

echo "Agent:     $AGENT"
echo "Target:    $TARGET_DIR"
echo "Connected: ${CONNECTED_LEAVES[*]:-<guest: global only>}"

# Both are real directories (the skills parent must be real, not a symlink, for
# codex to scan it); skill children are symlinked in below.
mkdir -p "$TARGET_DIR" "$SKILLS_DIR"
clean_stale "$SKILLS_DIR"
# Specs reach each agent without per-scope symlinks now (claude: a manifest of
# @-imports in connected-scopes.md; codex: the in-repo AGENTS.override.md; openclaw:
# the USER.md marker block). Remove any
# AGENTS.<suffix>.md or sidecar symlink an earlier connect (old scheme) left behind.
# Only symlinks are deleted, so the generated files below are never touched.
find "$TARGET_DIR" -maxdepth 1 \( -name "AGENTS.*.md" -o -name "${AGENT_SIDECAR_BASE}.*.md" \) \
    -type l -delete 2>/dev/null || true

# --------------------------------------------------------------------------
# Resolve the scope chain + skills registry
# --------------------------------------------------------------------------

CHAIN=()
while IFS= read -r s; do CHAIN+=("$s"); done < <(build_scope_chain "$REPO_DIR" "${CONNECTED_LEAVES[@]:-}")

RESOLVED_TSV="$(skills_resolve "$REPO_DIR" "$AGENT" "${CONNECTED_LEAVES[@]:-}")"
REGISTRY_ACTIVE=false
[[ -n "$RESOLVED_TSV" ]] && REGISTRY_ACTIVE=true

# --------------------------------------------------------------------------
# Link always-tier in-tree skills (direct from the resolved registry)
# --------------------------------------------------------------------------

echo ""; echo "Skills:"
linked_any=false
# The set of expected skill-link basenames, held as a newline-delimited string and
# membership-tested below rather than as an associative array — bash 3.2, which
# macOS ships, has no `declare -A`. Basenames carry no newlines, so the delimiter
# is unambiguous.
_EXPECT_SKILL=$'\n'
# Parse tab fields by hand: `IFS=$'\t' read` collapses consecutive tabs (tab is
# IFS whitespace), dropping the empty owner of a global-scope row and shifting tier.
while IFS= read -r _row; do
    [[ -n "$_row" ]] || continue
    name="${_row%%$'\t'*}";  _row="${_row#*$'\t'}"
    scope="${_row%%$'\t'*}"; _row="${_row#*$'\t'}"
    owner="${_row%%$'\t'*}"; _row="${_row#*$'\t'}"
    tier="${_row%%$'\t'*}"
    [[ "$tier" == "always" ]] || continue
    [[ "$scope" == "external" ]] && continue   # external skills handled by the fetcher
    src="$(skills_dir_for "$REPO_DIR" "$scope" "$owner" "$name")"
    [[ -n "$src" && -d "$src" ]] || continue
    suffix="$(skills_link_suffix "$scope" "$owner")"
    dst="$SKILLS_DIR/${name}${suffix:+.$suffix}"
    link_path "$src" "$dst" "skills/${name}${suffix:+.$suffix}"
    _EXPECT_SKILL="${_EXPECT_SKILL}${name}${suffix:+.$suffix}"$'\n'
    linked_any=true
done <<< "$RESOLVED_TSV"
$linked_any || echo "  (no always-tier skills)"

# --------------------------------------------------------------------------
# External skills (fetched third-party) — only when the registry declares any
# --------------------------------------------------------------------------

if awk -F'\t' '$2=="external"{f=1} END{exit !f}' <<< "$RESOLVED_TSV" && [[ -x "$SCRIPT_DIR/fetch-external-skills.sh" ]]; then
    echo ""; echo "External skills:"
    LEAVES_CSV="$(IFS=','; echo "${CONNECTED_LEAVES[*]:-}")"
    "$SCRIPT_DIR/fetch-external-skills.sh" "$SKILLS_DIR" --agent "$AGENT" --leaves "$LEAVES_CSV" || \
        echo "  (fetch-external-skills.sh failed — non-fatal)"
fi

# Prune managed in-tree skill symlinks no longer expected — a removed/off skill,
# or a link from a previous suffix scheme. External skills are fetched as real
# directories, not symlinks, so this loop never touches them.
for d in "$SKILLS_DIR"/*; do
    [[ -L "$d" ]] || continue
    bn="$(basename "$d")"
    case "$_EXPECT_SKILL" in
        *$'\n'"$bn"$'\n'*) ;;
        *) rm "$d"; echo "  - removed stale skill $bn" ;;
    esac
done

# COMPAT 0001 (remove after 2026-08-28) — codex skills used to link under
# ~/.codex/skills (global); they live in the repo-local .agents/skills. Remove the
# symlinks left in the home dir (only
# links pointing back into this repo) so a re-linked codex install keeps no stale
# global copies; anything else under there is left untouched.
if [[ "$AGENT" == codex && "$SKILLS_DIR" != "$TARGET_DIR/skills" && -d "$TARGET_DIR/skills" ]]; then
    for _l in "$TARGET_DIR"/skills/*; do
        [[ -L "$_l" ]] || continue
        [[ "$(readlink "$_l")" == "$REPO_DIR"/* ]] && { rm "$_l"; echo "  - removed legacy codex skill link $(basename "$_l")"; }
    done
    rmdir "$TARGET_DIR/skills" 2>/dev/null || true
fi

# --------------------------------------------------------------------------
# Optional-skills index
# --------------------------------------------------------------------------

# The three indexes below are build inputs for compose_context, not deliverables:
# every agent receives them through its own composed surface. Generate them into
# temp files and let each agent's branch decide what to persist — only Claude keeps
# durable copies, because its @-import manifest names them as real files on disk.
# An index that has nothing to list is expressed by removing its temp file, so the
# `[[ -f … ]]` guards downstream read as "was anything generated?".
INDEX_FILE="$(mktemp)"; TOOLS_INDEX_FILE="$(mktemp)"; KNOWLEDGE_INDEX_FILE="$(mktemp)"
trap 'rm -f "$INDEX_FILE" "$TOOLS_INDEX_FILE" "$KNOWLEDGE_INDEX_FILE"' EXIT

# install_index <tmp> <dest> <label> — persist a generated index onto a surface that
# reads it from disk. No temp means nothing was generated this run: clear whatever an
# earlier relink left at the destination so the surface never imports a stale index.
install_index() {
    local tmp="$1" dest="$2" label="$3"
    if [[ -f "$tmp" ]]; then
        cp "$tmp" "$dest"; echo "  ✓ $label"
    elif [[ -f "$dest" ]]; then
        rm -f "$dest"; echo "  - removed stale $label"
    fi
}

# COMPAT 0003 (remove after 2026-08-28) — prune_home_indexes: the pre-override
# delivery model wrote these indexes into the agent's home config dir, back when that
# dir was the transport. The
# composed surface now carries them inlined, so home-dir copies are read by nothing:
# a shared dir where two checkouts overwrite each other and every copy goes stale at
# the next relink elsewhere. Removes only a file this connector wrote — matched on the
# generated heading — so a same-named file of the human's own is left alone.
prune_home_indexes() {
    local file heading
    while IFS='|' read -r file heading; do
        [[ -f "$TARGET_DIR/$file" ]] || continue
        [[ "$(head -n 1 "$TARGET_DIR/$file")" == "$heading" ]] || continue
        rm -f "$TARGET_DIR/$file"; echo "  - removed dead index copy $TARGET_DIR/$file"
    done <<'LEGACY'
optional-skills.md|# Optional skills
tools-index.md|# Tools
domains-index.md|# Domains
domains-index.md|# Knowledge domains
LEGACY
}

# COMPAT 0004 (remove after 2026-08-30) — prune_renamed_claude_index: the knowledge
# index was called domains-index.md before it was named after the tree it catalogs.
# install_index only ever clears the destination it writes, so a checkout relinking
# across the rename keeps the old copy in .claude/ with nothing importing it. Matched
# on the generated heading, so a same-named file of the human's own is left alone.
# Must run before the index installs: the heading match can't tell a stale copy from
# a live index a diverged connector still writes under the old name — sweeping first
# means such a connector regenerates the file instead of deleting what it just wrote.
prune_renamed_claude_index() {
    local dead="$TARGET_DIR/domains-index.md" first
    [[ -f "$dead" ]] || return 0
    first="$(head -n 1 "$dead")"
    [[ "$first" == "# Knowledge domains" || "$first" == "# Domains" ]] || return 0
    rm -f "$dead"; echo "  - removed renamed index copy .claude/domains-index.md"
}

echo ""; echo "Optional skills index:"
if $REGISTRY_ACTIVE; then
    {
        cat <<'HEADER'
# Optional skills

These skills are registered but **not auto-loaded** into the agent's context. To use one:

1. Read its `SKILL.md` from the path below.
2. Follow the instructions inline.

| Name | Path | Summary |
|------|------|---------|
HEADER
        while IFS= read -r _row; do
            [[ -n "$_row" ]] || continue
            name="${_row%%$'\t'*}";  _row="${_row#*$'\t'}"
            scope="${_row%%$'\t'*}"; _row="${_row#*$'\t'}"
            owner="${_row%%$'\t'*}"; _row="${_row#*$'\t'}"
            tier="${_row%%$'\t'*}"
            [[ "$tier" == "optional" ]] || continue
            if [[ "$scope" == "external" ]]; then
                src="$SKILLS_OPTIONAL_DIR/${name}.$(sanitize_suffix "$owner")"
                [[ -d "$src" ]] || continue
                local_path="$src"
            else
                src="$(skills_dir_for "$REPO_DIR" "$scope" "$owner" "$name")"
                [[ -z "$src" || ! -d "$src" ]] && continue
                local_path="${src#"$REPO_DIR"/}"
            fi
            summary=""
            [[ -f "$src/SKILL.md" ]] && summary="$(skills_extract_description "$src/SKILL.md")"
            summary="${summary//|/\\|}"
            printf '| %s | %s | %s |\n' "$name" "$local_path/SKILL.md" "$summary"
        done <<< "$RESOLVED_TSV" | sort
    } > "$INDEX_FILE"
    echo "  ✓ generated"
else
    rm -f "$INDEX_FILE"
    echo "  SKIP (no registry in any connected scope)"
fi

# --------------------------------------------------------------------------
# Tools index — a flat catalog of every tool doc visible across the chain
# --------------------------------------------------------------------------
# Unlike skills, tools carry no tiers/force/owner: a doc's presence at a scope
# lists it for everyone in that chain. Connection state (which tools this machine
# has set up) lives separately in .exobrain.json; the index is a pure catalog, so
# it stays a function of committed docs and regenerates on the same relink triggers.
echo ""; echo "Tools index:"
TOOLS_TSV="$(tools_resolve "$REPO_DIR" "${CONNECTED_LEAVES[@]:-}")"
if [[ -n "$TOOLS_TSV" ]]; then
    {
        cat <<'HEADER'
# Tools

External systems this agent can read from or act on. Each row points at a self-contained tool doc — **read the doc before using the tool**; it carries the setup, credentials, exact commands, and failure modes. Reach for one whenever a task maps to its summary.

Everyone sees the full catalog; connecting a tool is a separate per-machine step (the `exobrain-tools` skill; connection state in `.exobrain.json`). If a task needs a tool that isn't set up here, propose connecting it.

| Tool | Doc | Summary |
|------|-----|---------|
HEADER
        while IFS= read -r _row; do
            [[ -n "$_row" ]] || continue
            name="${_row%%$'\t'*}"; path="${_row#*$'\t'}"
            summary="$(tools_extract_summary "$REPO_DIR/$path")"
            summary="${summary//|/\\|}"
            printf '| %s | %s | %s |\n' "$name" "$path" "$summary"
        done <<< "$TOOLS_TSV"
    } > "$TOOLS_INDEX_FILE"
    echo "  ✓ generated"
else
    rm -f "$TOOLS_INDEX_FILE"
    echo "  SKIP (no tool docs in any connected scope)"
fi

# --------------------------------------------------------------------------
# Knowledge index — a flat catalog of the durable knowledge areas (knowledge/*)
# --------------------------------------------------------------------------
# Knowledge domains are root-only, unscoped content (no tiers, force, owner, or
# overlays), so the index is a plain glob of knowledge/*/README.md — name + one-line
# summary from each README's frontmatter. Auto-loaded like the tools index so the
# agent knows which areas of *your* world it can draw on instead of answering cold;
# read the domain's README before reasoning about it. A pure function of committed
# docs, regenerated on every relink. (Empty in a checkout with no knowledge/.)
echo ""; echo "Knowledge index:"
KNOWLEDGE_TSV="$(knowledge_resolve "$REPO_DIR")"
if [[ -n "$KNOWLEDGE_TSV" ]]; then
    {
        cat <<'HEADER'
# Knowledge domains

The durable knowledge areas in this exobrain — what *you* know, kept current. Each row points at a domain's `README.md` entry point; **read it before reasoning about that area** so you draw on recorded truth instead of answering cold. (Domains hold current truth; time-bound efforts live in `workspaces/`.)

| Knowledge domain | README | Summary |
|------------------|--------|---------|
HEADER
        while IFS= read -r _row; do
            [[ -n "$_row" ]] || continue
            name="${_row%%$'\t'*}"; path="${_row#*$'\t'}"
            summary="$(frontmatter_field "$REPO_DIR/$path" summary)"
            summary="${summary//|/\\|}"
            printf '| %s | %s | %s |\n' "$name" "$path" "$summary"
        done <<< "$KNOWLEDGE_TSV"
    } > "$KNOWLEDGE_INDEX_FILE"
    echo "  ✓ generated"
else
    rm -f "$KNOWLEDGE_INDEX_FILE"
    echo "  SKIP (no knowledge/ in this checkout)"
fi

# --------------------------------------------------------------------------
# Per-agent injection of scope specs into the agent surface
# --------------------------------------------------------------------------
# compose_context emits the connected chain's deeper-scope specs — each scope's
# AGENTS.md plus this agent's sidecar, shallow→deep — followed by the optional-
# skills index and the tools index, as one stream. The global scope (root AGENTS.md
# + root sidecar) is auto-loaded by the agent and is deliberately omitted. Shared by
# all backends so the composition lives in one place; only the delivery below differs.
compose_context() {
    for scope in ${CHAIN[@]+"${CHAIN[@]}"}; do
        [[ "$scope" == "global" ]] && continue
        if [[ -f "$REPO_DIR/$scope/AGENTS.md" ]]; then
            echo "<!-- scope: $scope -->"; echo ""; cat "$REPO_DIR/$scope/AGENTS.md"; echo ""
        fi
        if [[ -f "$REPO_DIR/$scope/$AGENT_SIDECAR" ]]; then
            echo "<!-- scope: $scope — $AGENT -->"; echo ""; cat "$REPO_DIR/$scope/$AGENT_SIDECAR"; echo ""
        fi
    done
    if [[ -f "$INDEX_FILE" ]]; then
        echo "<!-- optional-skills index -->"; echo ""; cat "$INDEX_FILE"; echo ""
    fi
    if [[ -f "$TOOLS_INDEX_FILE" ]]; then
        echo "<!-- tools index -->"; echo ""; cat "$TOOLS_INDEX_FILE"; echo ""
    fi
    if [[ -f "$KNOWLEDGE_INDEX_FILE" ]]; then
        echo "<!-- knowledge index -->"; echo ""; cat "$KNOWLEDGE_INDEX_FILE"; echo ""
    fi
}

# compose_scope_manifest emits one @-import line per deeper-scope spec (each scope's
# AGENTS.md plus this agent's sidecar, shallow→deep) — for an agent that resolves
# recursive @-imports (Claude). It references the committed source files by path
# rather than copying them, so scope edits show up live without a recompose. Paths
# are RELATIVE to the manifest's home (.claude/, one level under REPO_DIR) — relative
# not absolute so a copied checkout (test sandbox, worktree) still resolves them. The
# global scope (root AGENTS.md + root sidecar) loads via the checked-in root CLAUDE.md
# and is deliberately omitted, matching compose_context.
compose_scope_manifest() {
    echo "<!-- Auto-generated by connect-agent.sh — do not edit; regenerated on relink. -->"
    echo "<!-- @-import manifest of connected-scope specs (live source files, by reference). -->"
    echo ""
    # `if` blocks, not a trailing `[[ … ]] && echo`: a conditional that tests false
    # returns 1, which under `set -e` aborts at the `… > file` call site whenever the
    # last scope lacks a sidecar. An `if` whose test fails returns 0, so the function
    # always succeeds (matching compose_context's style).
    for scope in ${CHAIN[@]+"${CHAIN[@]}"}; do
        [[ "$scope" == "global" ]] && continue
        if [[ -f "$REPO_DIR/$scope/AGENTS.md" ]];      then echo "@../$scope/AGENTS.md"; fi
        if [[ -f "$REPO_DIR/$scope/$AGENT_SIDECAR" ]]; then echo "@../$scope/$AGENT_SIDECAR"; fi
    done
}

case "$AGENT" in
    claude)
        # Claude's own surface — never a file another agent also writes. Claude
        # resolves recursive @-imports, so reference the live source specs through a
        # manifest (no inlined copy: scope edits show up without a recompose) plus the
        # agent-filtered optional-skills index and the tools index. The generated
        # .claude/CLAUDE.md @-imports them; the root spec loads via the checked-in root
        # CLAUDE.md (@AGENTS.md), so global stays out of the manifest.
        echo ""; echo "Composing Claude context surface …"
        compose_scope_manifest > "$TARGET_DIR/connected-scopes.md"
        echo "  ✓ .claude/connected-scopes.md (manifest of source specs)"
        # Claude is the one surface that reads the indexes as files: the manifest
        # @-imports them by name, so they need durable copies in the in-repo
        # (gitignored) .claude/ that travels with the checkout.
        prune_renamed_claude_index
        install_index "$INDEX_FILE"           "$TARGET_DIR/optional-skills.md" ".claude/optional-skills.md"
        install_index "$TOOLS_INDEX_FILE"     "$TARGET_DIR/tools-index.md"     ".claude/tools-index.md"
        install_index "$KNOWLEDGE_INDEX_FILE" "$TARGET_DIR/knowledge-index.md" ".claude/knowledge-index.md"
        {
            echo "@connected-scopes.md"
            # `if`, not `&& printf`: when an index is absent the trailing conditional
            # would return 1 and trip `set -e` at the `} > file` redirection.
            if [[ -f "$INDEX_FILE" ]]; then echo "@optional-skills.md"; fi
            if [[ -f "$TOOLS_INDEX_FILE" ]]; then echo "@tools-index.md"; fi
            if [[ -f "$KNOWLEDGE_INDEX_FILE" ]]; then echo "@knowledge-index.md"; fi
        } > "$TARGET_DIR/CLAUDE.md"
        echo "  ✓ .claude/CLAUDE.md"
        # Supersedes the earlier single inlined file; drop one an old connect left behind.
        rm -f "$TARGET_DIR/AGENTS.override.md"

        # Disable Claude Code's auto-memory — this exobrain provides context via
        # AGENTS.md/CLAUDE.md, so the separate auto-memory layer just adds drift.
        # settings.local.json is gitignored (per-machine); merge to preserve other keys.
        settings="$TARGET_DIR/settings.local.json"
        if command -v jq >/dev/null 2>&1; then
            if [[ -f "$settings" ]]; then
                jq '.autoMemoryEnabled = false' "$settings" > "${settings}.tmp" && mv "${settings}.tmp" "$settings"
            else
                echo '{"autoMemoryEnabled": false}' | jq . > "$settings"
            fi
            echo "  ✓ settings.local.json (autoMemoryEnabled: false)"
        else
            echo "  SKIP settings.local.json (jq not installed)"
        fi
        ;;
    codex)
        # Codex reads AGENTS.override.md natively and it outranks AGENTS.md at the
        # same directory level, so the whole composition lands in one in-repo
        # AGENTS.override.md (gitignored, per-machine). Because the override
        # supersedes the root AGENTS.md Codex would otherwise read, the root spec
        # (and the root sidecar) is prepended ahead of the shared deeper-scope
        # content — nothing carries over from the bare AGENTS.md once it exists.
        OVERRIDE="$REPO_DIR/AGENTS.override.md"
        echo ""; echo "Generating $(basename "$OVERRIDE") (Codex reads it natively) …"
        {
            echo "<!-- Auto-generated by connect-agent.sh — do not edit; regenerated on relink. -->"; echo ""
            echo "<!-- scope: global -->"; echo ""; cat "$REPO_DIR/AGENTS.md"; echo ""
            if [[ -f "$REPO_DIR/$AGENT_SIDECAR" ]]; then
                echo "<!-- scope: root ($AGENT) -->"; echo ""; cat "$REPO_DIR/$AGENT_SIDECAR"; echo ""
            fi
            compose_context
        } > "$OVERRIDE"
        echo "  ✓ $(basename "$OVERRIDE")"

        # COMPAT 0002 (remove after 2026-08-28) — strip the exobrain marker block a
        # prior connector injected into ~/.codex/AGENTS.md, superseded by the override.
        if [[ -f "$TARGET_DIR/AGENTS.md" ]] && grep -qF "<!-- BEGIN exobrain -->" "$TARGET_DIR/AGENTS.md" 2>/dev/null; then
            awk 'BEGIN{s=0} /<!-- BEGIN exobrain -->/{s=1} /<!-- END exobrain -->/{s=0;next} !s' \
                "$TARGET_DIR/AGENTS.md" > "$TARGET_DIR/AGENTS.md.tmp" && mv "$TARGET_DIR/AGENTS.md.tmp" "$TARGET_DIR/AGENTS.md"
            echo "  - removed legacy exobrain block from $TARGET_DIR/AGENTS.md"
        fi
        prune_home_indexes
        ;;
    openclaw)
        # OpenClaw has no import primitive and auto-loads the root AGENTS.md but not
        # the root sidecar, so deliver the composition (root sidecar prepended ahead
        # of the shared deeper-scope content) into its private USER.md, between markers.
        DEST="$TARGET_DIR/USER.md"
        echo ""; echo "Injecting agent context into $(basename "$DEST") …"
        CONTENT_TMP="$(mktemp)"
        {
            echo "<!-- Auto-generated by connect-agent.sh — do not edit manually. -->"; echo ""
            if [[ -f "$REPO_DIR/$AGENT_SIDECAR" ]]; then
                echo "<!-- scope: root ($AGENT) -->"; echo ""; cat "$REPO_DIR/$AGENT_SIDECAR"; echo ""
            fi
            compose_context
        } > "$CONTENT_TMP"
        mkdir -p "$TARGET_DIR"
        inject_block "$DEST" "exobrain" "$CONTENT_TMP" "$(basename "$DEST")"
        rm -f "$CONTENT_TMP"
        prune_home_indexes
        ;;
esac

# --render-specs-only stops here. Everything above writes only inside the checkout
# (the in-repo .claude surface, or the in-repo AGENTS.override.md for codex) or a
# *_HOME-overridden copy dir (openclaw's USER.md — the guard at TARGET_DIR selection
# refuses a render without the override); the connect marker and git hooks below are
# the first writes outside it. Truncating here — not forking a parallel render
# path — keeps the rendered surface identical to a full connect.
if $RENDER_ONLY; then
    echo ""; echo "✓ Rendered $AGENT context surface (no out-of-dir writes)."
    exit 0
fi

# --------------------------------------------------------------------------
# Marker (first run only) + hooks (every run, so template fixes reach
# already-connected checkouts — the post-merge relink refreshes them after a
# pull; see machinery.md § Git hooks). The tmp-then-mv write is atomic, so a
# hook may safely rewrite itself mid-run.
# --------------------------------------------------------------------------

if ! $RELINK; then
    mkdir -p "$(dirname "$MARKER")"; touch "$MARKER"
fi
install_hook

# --------------------------------------------------------------------------
# Scope hooks — a connected scope extending the connect with its own setup
# --------------------------------------------------------------------------
# Each scope in the chain carrying an executable scripts/connect-agent.sh (every
# agent) or scripts/connect-agent.<agent>.sh (that agent alone) gets it run,
# shallow→deep, as: <hook> <agent> <target-dir> <scope-dir>. Both run when both
# exist, universal first. The global scope is skipped — its scripts/connect-agent.sh
# is this connector, so running it as a hook would recurse.
#
# They run below the --render-specs-only cutoff because a hook is arbitrary code
# with its own write surface, and a render promises none. A failing hook is
# reported with its output and the connect carries on: one scope's extra must not
# cost the human their wiring — which is why every loop tail below is an `if`
# block rather than a trailing `[[ … ]] && …`, whose false status would become
# the loop's, ride both loops out of the function, and abort the connect at the
# bare call site under `set -e`.
run_scope_hooks() {
    local scope hook output line status announced=false
    for scope in ${CHAIN[@]+"${CHAIN[@]}"}; do
        if [[ "$scope" == "global" ]]; then continue; fi
        for hook in "$REPO_DIR/$scope/scripts/connect-agent.sh" \
                    "$REPO_DIR/$scope/scripts/connect-agent.$AGENT.sh"; do
            [[ -x "$hook" ]] || continue
            if ! $announced; then echo ""; echo "Scope hooks:"; announced=true; fi
            output="$("$hook" "$AGENT" "$TARGET_DIR" "$REPO_DIR/$scope" 2>&1)" && status=0 || status=$?
            if [[ $status -eq 0 ]]; then
                echo "  ✓ $scope/scripts/$(basename "$hook")"
            else
                echo "  ! $scope/scripts/$(basename "$hook") failed (exit $status) — connect continues"
                while IFS= read -r line; do
                    if [[ -n "$line" ]]; then echo "      $line"; fi
                done <<< "$output"
            fi
        done
    done
}
run_scope_hooks

echo ""; echo "✓ Connected $AGENT."
