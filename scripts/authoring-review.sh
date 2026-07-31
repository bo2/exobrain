#!/usr/bin/env bash
# authoring-review.sh — LLM review of changed domain/spec files against the
# exobrain authoring & convention rules. The judgment layer that complements the
# deterministic checks in validate-exobrain.sh. It also carries one deterministic
# gate of its own — the new-shared-skill proof gate in section 0 — because that one
# belongs at the deliberate land, not on every push.
#
# Runs as a step in the exobrain-persist flow (after commit, before push), where a
# deliberate land is the right moment for a model round-trip; also runnable by hand
# before a substantial spec/domain edit. Not wired into the pre-push hook — that
# gate stays fast and deterministic (validate-exobrain.sh only), so ordinary pushes
# aren't taxed by a per-push model round-trip.
#   scripts/authoring-review.sh [<base-ref>]   # default base: origin/main
#
# Engine: claude (headless, read-only) if installed, else codex; if neither is
# available — or the checker errors/times out — it DEGRADES OPEN (exit 0), so a
# missing or flaky checker never reports a false violation. It exits 1 only when
# the model reports clear violations, and 2 when the deterministic new-shared-skill
# gate below blocks (that one needs no model).
#
# Opt out:  EXOBRAIN_SKIP_AUTHORING_REVIEW=1

set -uo pipefail
[[ "${EXOBRAIN_SKIP_AUTHORING_REVIEW:-}" == "1" ]] && exit 0

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASE="${1:-origin/main}"

# ---------------------------------------------------------------------------
# 0. New-shared-skill proof gate — deterministic, runs before the model pass.
#
# A skill declared at a shared scope loads for everyone whose chain includes that
# scope, so a newly declared one must carry committed proof it earns that reach:
# registration as a periodic job in a schedule.json, or a test/eval/ab artifact inside
# the skill dir. Absent either, the skill belongs under a person scope, which imposes
# on no one. Proof must live WITH the skill — a skill may not cite the workspace it
# came from (AGENTS.md: links from anything that must stay current go stale silently).
#
# Exempt: person and host scopes (per scopes.json), external skills (`source`) and
# overrides (`from`). Skills already declared at BASE are grandfathered — under their
# current name or the one they were renamed from — so adopting this gate never flags
# an existing corpus and a rename is not read as a fresh declaration. Skipped when
# BASE doesn't resolve — degrading open like the rest of this script.
# ---------------------------------------------------------------------------

# Scope collections that are personal rather than shared. Read from scopes.json so
# an instance that renames its collections still resolves; falls back to the defaults.
personal_collections="people hosts"
if [[ -f "$REPO_DIR/scopes.json" ]]; then
    _pc="$(jq -r '[(.scopes // [])[] | select(.type == "person" or .type == "host") | .collection] | join(" ")' \
           "$REPO_DIR/scopes.json" 2>/dev/null)"
    [[ -n "$_pc" ]] && personal_collections="$_pc"
fi

is_personal_path() {   # $1 = repo-relative path
    local seg
    for seg in $personal_collections; do
        case "/$1" in */"$seg"/*) return 0 ;; esac
    done
    return 1
}

skill_proof_signal() {   # $1 = skill dir (abs), $2 = skill name — 0 if proof exists
    local dir="$1" name="$2" sched
    while IFS= read -r sched; do
        [[ -n "$sched" ]] || continue
        grep -qF -- "$name" "$REPO_DIR/$sched" 2>/dev/null && return 0
    done < <(git -C "$REPO_DIR" ls-files 'schedule.json' '*/schedule.json' 2>/dev/null)
    [[ -n "$(find "$dir" -type d -iname 'evals' 2>/dev/null | head -1)" ]] && return 0
    [[ -n "$(find "$dir" -type f \( -iname '*test*' -o -name 'ab-results.json' \
             -o -iname '*.eval.json' \) 2>/dev/null | head -1)" ]] && return 0
    return 1
}

unproven=()
_seen_skills=" "
check_new_skill() {   # $1 = name, $2 = scope label, $3 = skill dir (abs)
    case "$_seen_skills" in *" $1 "*) return ;; esac
    _seen_skills="$_seen_skills$1 "
    [[ -d "$3" ]] || return
    skill_proof_signal "$3" "$1" || unproven+=("$1 ($2)")
}

if git -C "$REPO_DIR" rev-parse --verify --quiet "$BASE" >/dev/null 2>&1; then
    _decls='.skills[] | select((has("from") | not) and (has("source") | not)) | .name'

    # A rename changes what a skill is called, not whose chain loads it, so a
    # renamed skill inherits its old name's standing. Map <new>=<old> from git's
    # rename detection over SKILL.md paths. The inheritance is granted per registry
    # (below), so a skill MOVED from a person scope to a shared one — where the
    # reach genuinely widens — is still gated.
    _renames=" "
    while IFS=$'\t' read -r _st _old _new; do
        case "$_st" in R*) ;; *) continue ;; esac
        _old="${_old#*skills/}"; _old="${_old%/SKILL.md}"
        _new="${_new#*skills/}"; _new="${_new%/SKILL.md}"
        _renames="$_renames$_new=$_old "
    done < <(git -C "$REPO_DIR" diff --name-status --find-renames "$BASE...HEAD" \
             -- '*SKILL.md' 2>/dev/null)

    rename_src() {   # $1 = skill name at HEAD — echoes the name it was renamed from
        local rec
        for rec in $_renames; do
            case "$rec" in "$1="*) printf '%s' "${rec#*=}"; return ;; esac
        done
    }

    # (i) Declarations present at HEAD but not at BASE — the authoritative signal:
    # a skill becomes shared the moment a shared scope's registry names it.
    while IFS= read -r sj; do
        [[ -n "$sj" ]] || continue
        is_personal_path "$sj" && continue
        scope_dir="$(dirname "$sj")"
        if [[ "$scope_dir" == "." ]]; then
            scope_lbl="global"; skills_dir="$REPO_DIR/skills"
        else
            scope_lbl="$scope_dir"; skills_dir="$REPO_DIR/$scope_dir/skills"
        fi
        head_decls="$(jq -r "$_decls" "$REPO_DIR/$sj" 2>/dev/null)"
        base_decls="$(git -C "$REPO_DIR" show "$BASE:$sj" 2>/dev/null | jq -r "$_decls" 2>/dev/null)"
        while IFS= read -r nm; do
            [[ -n "$nm" ]] || continue
            printf '%s\n' "$base_decls" | grep -qxF -- "$nm" && continue
            # Declared at BASE under its former name in THIS registry — grandfathered.
            _from="$(rename_src "$nm")"
            if [[ -n "$_from" ]] && printf '%s\n' "$base_decls" | grep -qxF -- "$_from"; then
                continue
            fi
            check_new_skill "$nm" "$scope_lbl" "$skills_dir/$nm"
        done <<< "$head_decls"
    done < <(git -C "$REPO_DIR" ls-files 'skills.json' '*/skills.json' 2>/dev/null)

    # (ii) Newly added SKILL.md files — belt-and-suspenders for a skill dropped in a
    # shared scope's skills/ whose declaration lands in a later commit.
    while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        is_personal_path "$f" && continue
        case "$f" in
            skills/*/SKILL.md)
                nm="${f#skills/}"; nm="${nm%/SKILL.md}"
                check_new_skill "$nm" "global" "$REPO_DIR/skills/$nm" ;;
            */skills/*/SKILL.md)
                sd="${f%/skills/*}"; nm="${f#*/skills/}"; nm="${nm%/SKILL.md}"
                check_new_skill "$nm" "$sd" "$REPO_DIR/$sd/skills/$nm" ;;
        esac
    done < <(git -C "$REPO_DIR" diff --name-only --find-renames --diff-filter=A "$BASE...HEAD" 2>/dev/null \
             | grep 'SKILL\.md$')
fi

if [[ ${#unproven[@]} -gt 0 ]]; then
    {
        echo ""
        echo "NEW SHARED SKILL — newly declared at a shared scope with no committed proof it"
        echo "earns that reach: no schedule.json registration, and no test/eval/ab artifact in"
        echo "the skill dir. A shared skill loads for everyone whose chain includes its scope."
        echo "For each, either PROVE it — commit the test run, eval, or exobrain-ab result into"
        echo "the skill's own directory, so the proof travels with the skill — or RELOCATE it"
        echo "under a person scope's skills/, which imposes on no one and is exempt:"
        printf '  - %s\n' "${unproven[@]}"
        echo ""
        echo "Then re-run scripts/authoring-review.sh."
        echo ""
    } >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# 1. In-scope files changed on this branch. Skip fast if none.
# ---------------------------------------------------------------------------
files=()
# Plain while-read instead of `mapfile` (a bash 4 builtin) so this runs under
# macOS's stock bash 3.2. Reading straight into the loop also avoids expanding an
# empty intermediate array under `set -u`, which errors on bash 3.2.
while IFS= read -r f; do
    case "$f" in
        */_raw/*) continue ;;
        knowledge/*.md|AGENTS.md|*/AGENTS.md|*/AGENTS.*.md|CLAUDE.md|*/CLAUDE.md|CODEX.md|*/CODEX.md|OPENCLAW.md|*/OPENCLAW.md|*/SKILL.md)
            [[ -f "$REPO_DIR/$f" ]] && files+=("$f") ;;
    esac
done < <(git -C "$REPO_DIR" diff --name-only "$BASE...HEAD" -- '*.md' 2>/dev/null)
[[ ${#files[@]} -eq 0 ]] && exit 0

diff_text="$(git -C "$REPO_DIR" diff "$BASE...HEAD" -- "${files[@]}" 2>/dev/null)"
[[ -z "$diff_text" ]] && exit 0
# Bound the prompt size; very large diffs get truncated (the deterministic hook
# still covers the whole change).
if [[ ${#diff_text} -gt 120000 ]]; then
    diff_text="${diff_text:0:120000}"$'\n[diff truncated for review]'
fi

# ---------------------------------------------------------------------------
# 2. Prompt — conservative, sentinel-delimited output. The rubric is a quoted
# heredoc (no expansion); the diff is concatenated as plain data so nothing in
# it is ever interpreted by the shell. The heredoc lives in a function rather
# than directly inside `$(...)`: bash 3.2's command-substitution parser miscounts
# apostrophes in a heredoc body nested in `$()` and aborts, so a bare heredoc in
# a function (captured by a plain `$(emit_rubric)`) keeps this portable to
# macOS's stock bash.
# ---------------------------------------------------------------------------
emit_rubric() {
    cat <<'RUBRIC_EOF'
You are an authoring linter for the "exobrain" knowledge repository. Review the
git diff below for CLEAR, high-confidence violations of the repo's authoring and
convention rules. Output text only; do not modify any files.

The rules live in knowledge/exobrain/authoring.md, knowledge/exobrain/domains.md,
and AGENTS.md (sections "Conventions", "Reader Lens", and "Keep auto-loaded
specs tight") -- read them if useful. The ones to check:

- Horizon test: knowledge-domain files hold durable current truth, not point-in-time
  metrics or a sprint changelog.
- Current-state-only: no change-narrative ("in May we...", "PR #x added...") in
  domain files -- that belongs in workspaces or history files.
- Synthesize, don't transcribe: no code transcription, enum dumps,
  function-by-function walks, or hardcoded tuning constants in domain files.
- No ephemeral numbers: no point-in-time percentages or counts that go stale.
- Scope placement: durable truth belongs in knowledge/, time-bound records in
  workspaces/; don't cite a workspace from anything that must stay current.
- Specs (auto-loaded files -- AGENTS.md, sidecars, SKILL.md): keep tight (state
  the rule, drop non-load-bearing exposition); write standalone, not as a delta
  (no "now / still / since / recently / no longer / originally").
- Don't duplicate drift-prone facts across files.
- Reader lens: every added line must serve a nameable reader of this file's
  genre. Flag author-serving prose -- "why we did X" justifications, narrative
  about the change itself, asides defending the author's choices -- that no
  reader of the doc needs. (Cut test only; what's *missing* is out of scope.)

For any changed */SKILL.md, ALSO evaluate the skill against the skill-authoring
rubric:
- Type: Utility (ships scripts, endpoints, or a real procedure), Behavior-shaping
  (mostly prose nudging the agent's own reasoning), or Hybrid. A helper script's
  mere presence does not make a prose-heavy skill a Utility.
- Leverage: does it let the agent do something it cannot already do from
  auto-loaded context? Flag a skill that mostly restates AGENTS.md, a sidecar, or
  another skill (redundant, and it will drift), or that is a generic
  best-practices checklist with no exobrain-specific leverage.
- Proof (shared-scope skills must be proven): a Utility by a committed run, test,
  or scheduler registration; a Behavior-shaping skill by an exobrain-ab result
  showing it moves behavior. Flag an unproven shared skill (the deterministic
  block is section 0 of this script).
- Reach: flag force:true or tier:always that is disproportionate to the
  demonstrated value (e.g. `always` for content only needed on demand).
Recommend one of KEEP / TRIM (cut the redundant or generic prose) / PROVE /
DEMOTE (to a person scope's skills/) / MERGE.

Be conservative: flag only what a careful reviewer would clearly call a
violation. If unsure, do not flag. Ignore style and wording preferences.

Output:
- If there are no clear violations, output exactly this token on its own line:
  AUTHORING-OK
- Otherwise output one finding per line as: <path>: <rule> -- <concrete fix>.
  No preamble, no praise, no summary.

Diff under review:
RUBRIC_EOF
}
PROMPT="$(emit_rubric)"$'\n'"$diff_text"

# ---------------------------------------------------------------------------
# 3. Run the review (claude → codex → degrade open). Time-bounded.
# ---------------------------------------------------------------------------
TIMEOUT=()
if t="$(command -v timeout 2>/dev/null)"; then TIMEOUT=("$t" 240)
elif t="$(command -v gtimeout 2>/dev/null)"; then TIMEOUT=("$t" 240); fi

# Strip inherited proxy vars from the engine subprocess. Some networks route git
# through a SOCKS/HTTP proxy in the environment; the engine talks to its
# own model API directly and must not route through that proxy, or every proxied
# push would silently skip the review. `env -u` of an unset var is a no-op, so
# this is safe whether or not a proxy is set.
NOPROXY=(env -u ALL_PROXY -u HTTPS_PROXY -u HTTP_PROXY -u all_proxy -u https_proxy -u http_proxy)

# Build the command, appending TIMEOUT only when present — expanding an empty
# array under `set -u` errors on bash 3.2, which is the default on macOS.
run_engine() {
    local -a cmd
    cmd=("${NOPROXY[@]}")
    if [[ ${#TIMEOUT[@]} -gt 0 ]]; then
        cmd+=("${TIMEOUT[@]}")
    fi
    cmd+=("$@")
    printf '%s' "$PROMPT" | "${cmd[@]}" 2>/dev/null
}

run_review() {
    if command -v claude >/dev/null 2>&1; then
        run_engine claude -p --permission-mode plan
    elif command -v codex >/dev/null 2>&1; then
        run_engine codex exec -s read-only -
    else
        return 3
    fi
}

# Degrade open either way, but distinguish the causes: rc=3 means no engine on
# PATH; any other non-zero means the engine errored or timed out.
output="$(run_review)"; rc=$?
if [[ $rc -eq 3 ]]; then
    echo "authoring-review: no claude/codex engine on PATH — skipping." >&2
    exit 0
elif [[ $rc -ne 0 ]]; then
    echo "authoring-review: engine errored or timed out (rc=$rc) — skipping." >&2
    exit 0
fi
output="$(printf '%s\n' "$output" | sed '/^[[:space:]]*$/d')"
[[ -z "$output" ]] && { echo "authoring-review: empty result — skipping." >&2; exit 0; }

# ---------------------------------------------------------------------------
# 4. Verdict.
# ---------------------------------------------------------------------------
if grep -q 'AUTHORING-OK' <<<"$output"; then
    exit 0
fi

echo "" >&2
echo "Authoring review flagged possible issues in the changed files:" >&2
echo "" >&2
echo "$output" >&2
echo "" >&2
echo "For a deeper reader-lens pass on new or justification-heavy docs, run the" >&2
echo "exobrain-authoring-audit skill." >&2
echo "" >&2
echo "Fix them and recheck with 'scripts/authoring-review.sh'." >&2
exit 1
