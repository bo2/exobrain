#!/usr/bin/env bash
# authoring-review.sh — on-demand LLM review of changed domain/spec files against
# the exobrain authoring & convention rules. The judgment layer that complements
# the deterministic checks in validate-exobrain.sh.
#
# Not a push gate: the pre-push hook runs only validate-exobrain.sh, since a
# per-push model round-trip taxes every push for an occasional payoff. Run this by
# hand before a substantial spec/domain edit:
#   scripts/authoring-review.sh [<base-ref>]   # default base: origin/main
#
# Engine: claude (headless, read-only) if installed, else codex; if neither is
# available — or the checker errors/times out — it DEGRADES OPEN (exit 0), so a
# missing or flaky checker never reports a false violation. It exits 1 only when
# the model reports clear violations.
#
# Opt out:  EXOBRAIN_SKIP_AUTHORING_REVIEW=1

set -uo pipefail
[[ "${EXOBRAIN_SKIP_AUTHORING_REVIEW:-}" == "1" ]] && exit 0

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASE="${1:-origin/main}"

# ---------------------------------------------------------------------------
# 1. In-scope files changed on this branch. Skip fast if none.
# ---------------------------------------------------------------------------
mapfile -t changed < <(git -C "$REPO_DIR" diff --name-only "$BASE...HEAD" -- '*.md' 2>/dev/null)
files=()
for f in "${changed[@]}"; do
    case "$f" in
        */_raw/*) continue ;;
        domains/*.md|AGENTS.md|*/AGENTS.md|*/AGENTS.*.md|CLAUDE.md|*/CLAUDE.md|CODEX.md|*/CODEX.md|OPENCLAW.md|*/OPENCLAW.md|*/SKILL.md)
            [[ -f "$REPO_DIR/$f" ]] && files+=("$f") ;;
    esac
done
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
# it is ever interpreted by the shell.
# ---------------------------------------------------------------------------
RUBRIC="$(cat <<'RUBRIC_EOF'
You are an authoring linter for the "exobrain" knowledge repository. Review the
git diff below for CLEAR, high-confidence violations of the repo's authoring and
convention rules. Output text only; do not modify any files.

The rules live in domains/exobrain/authoring.md, domains/exobrain/domains.md,
and AGENTS.md (sections "Conventions", "Reader Lens", and "Keep auto-loaded
specs tight") -- read them if useful. The ones to check:

- Horizon test: domain files hold durable current truth, not point-in-time
  metrics or a sprint changelog.
- Current-state-only: no change-narrative ("in May we...", "PR #x added...") in
  domain files -- that belongs in workspaces or history files.
- Synthesize, don't transcribe: no code transcription, enum dumps,
  function-by-function walks, or hardcoded tuning constants in domain files.
- No ephemeral numbers: no point-in-time percentages or counts that go stale.
- Scope placement: durable truth belongs in domains/, time-bound records in
  workspaces/; don't cite a workspace from anything that must stay current.
- Specs (auto-loaded files -- AGENTS.md, sidecars, SKILL.md): keep tight (state
  the rule, drop non-load-bearing exposition); write standalone, not as a delta
  (no "now / still / since / recently / no longer / originally").
- Don't duplicate drift-prone facts across files.
- Reader lens: every added line must serve a nameable reader of this file's
  genre. Flag author-serving prose -- "why we did X" justifications, narrative
  about the change itself, asides defending the author's choices -- that no
  reader of the doc needs. (Cut test only; what's *missing* is out of scope.)

Be conservative: flag only what a careful reviewer would clearly call a
violation. If unsure, do not flag. Ignore style and wording preferences.

Output:
- If there are no clear violations, output exactly this token on its own line:
  AUTHORING-OK
- Otherwise output one finding per line as: <path>: <rule> -- <concrete fix>.
  No preamble, no praise, no summary.

Diff under review:
RUBRIC_EOF
)"
PROMPT="$RUBRIC"$'\n'"$diff_text"

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

run_review() {
    if command -v claude >/dev/null 2>&1; then
        printf '%s' "$PROMPT" | "${NOPROXY[@]}" "${TIMEOUT[@]}" claude -p --permission-mode plan 2>/dev/null
    elif command -v codex >/dev/null 2>&1; then
        printf '%s' "$PROMPT" | "${NOPROXY[@]}" "${TIMEOUT[@]}" codex exec -s read-only - 2>/dev/null
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
echo "exobrain-reader-lens skill." >&2
echo "" >&2
echo "Fix them and recheck with 'scripts/authoring-review.sh'." >&2
exit 1
