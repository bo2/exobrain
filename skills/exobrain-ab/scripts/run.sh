#!/usr/bin/env bash
# exobrain-ab — behavioral A/B eval of an exobrain auto-load change.
#
# Builds control (trunk) vs treatment (trunk + a diff) sandboxes, renders each via the
# sandbox's OWN connector (`connect-agent.sh <agent> --render-specs-only`, side-effect-
# free), runs a headless agent on each task N times, and measures *which tool/command
# the agent reaches for* — captured by PATH-shadow stubs that log the invocation and
# return canned output. Reports control vs treatment pass rates. See SKILL.md.
#
# Usage: run.sh <change.diff> <tasks.sh> [N] [parallel] [model] [filter]
#   <change.diff>  git-apply-able unified diff (from the repo root) = the change under
#                  test. control = trunk; treatment = trunk + this diff. Empty file,
#                  "-", or /dev/null => an A/A noise-floor run (no change applied).
#   <tasks.sh>     bash file defining TASKS=() — see tasks.example.sh.
#   N              runs per (task × arm). Default 12.
#   parallel       concurrent agents. Default 2 (4 concurrent headless agents can fail).
#   model          agent model. Default: claude→opus, codex→gpt-5.5.
#   filter         dev | holdout | all (default) | <task-id>.
#
# Env: AGENT (claude|codex, default claude), BASE_REF (default: the repo's trunk),
#      SANDBOX_ROOT, OUTDIR (both default under the repo's gitignored tmp/),
#      MAX_TURNS (14), TIMEOUT (240), BUILD_ONLY (stop after building+rendering).
#
# Sandboxes render guest (global scope only) — root AGENTS.md/CLAUDE.md + global skills
# and tool docs, which is what most framework changes touch. Deeper-scope changes need a
# connected leaf wired into the sandbox; that is out of scope for this harness.
set -u

DIFF_ARG="${1:?usage: run.sh <change.diff> <tasks.sh> [N] [parallel] [model] [filter]}"
TASKS_FILE="${2:?usage: run.sh <change.diff> <tasks.sh> [N] [parallel] [model] [filter]}"
N="${3:-12}"; PAR="${4:-2}"; FILTER="${6:-all}"
AGENT="${AGENT:-claude}"
case "$AGENT" in claude|codex) ;; *) echo "AGENT must be claude or codex (got '$AGENT')" >&2; exit 1;; esac
MODEL="${5:-}"; [ -n "$MODEL" ] || { [ "$AGENT" = codex ] && MODEL=gpt-5.5 || MODEL=opus; }
export AGENT MODEL MAX_TURNS="${MAX_TURNS:-14}" TIMEOUT="${TIMEOUT:-240}"

# --- Derive everything from the repo, so the skill is instance-portable ----------
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(git -C "$SELF" rev-parse --show-toplevel)" || { echo "not in a git repo" >&2; exit 1; }
# Trunk = origin's default branch if known, else the current branch.
default_base() {
  git -C "$REPO" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@'
}
BASE_REF="${BASE_REF:-$(default_base)}"; BASE_REF="${BASE_REF:-$(git -C "$REPO" rev-parse --abbrev-ref HEAD)}"
# Sandbox origin = this instance's own origin, so git/gh tasks behave as in the real repo.
ORIGIN="$(git -C "$REPO" remote get-url origin 2>/dev/null || echo 'https://example.invalid/exobrain.git')"
export STUBS="$SELF/stubs"
SANDBOX_ROOT="${SANDBOX_ROOT:-$REPO/tmp/exobrain-ab/sandboxes}"; export SANDBOX_ROOT
OUTDIR="${OUTDIR:-$REPO/tmp/exobrain-ab/results}"; mkdir -p "$OUTDIR" "$SANDBOX_ROOT"

# --- Preflight -------------------------------------------------------------------
command -v "$AGENT" >/dev/null || { echo "$AGENT CLI not found on PATH" >&2; exit 1; }
[ "$AGENT" = codex ] && { [ -e "$HOME/.codex/auth.json" ] || { echo "codex not logged in (~/.codex/auth.json missing)" >&2; exit 1; }; }
[ -f "$TASKS_FILE" ] || { echo "tasks file not found: $TASKS_FILE" >&2; exit 1; }
git -C "$REPO" rev-parse --verify -q "$BASE_REF" >/dev/null || { echo "BASE_REF '$BASE_REF' is not a valid ref" >&2; exit 1; }

# Resolve the diff: empty / "-" / /dev/null / empty file => A/A (no change applied).
DIFF=""
case "$DIFF_ARG" in ""|-|/dev/null) ;; *) [ -s "$DIFF_ARG" ] && DIFF="$(cd "$(dirname "$DIFF_ARG")" && pwd)/$(basename "$DIFF_ARG")";; esac
[ -n "$DIFF" ] && echo "Change under test: $DIFF" || echo "Change under test: (none — A/A noise-floor run)"

# shellcheck disable=SC1090
source "$TASKS_FILE"
[ "${#TASKS[@]}" -gt 0 ] || { echo "tasks file defined no TASKS=()" >&2; exit 1; }

in_filter() { # <set> <id>
  case "$FILTER" in
    all) return 0 ;;
    dev|holdout) [ "$1" = "$FILTER" ] ;;
    *) [ "$2" = "$FILTER" ] ;;
  esac
}

# --- Build a sandbox: trunk (+ diff for treatment), wired by its OWN connector -----
# REPO_DIR resolves to the sandbox (connect-agent.sh uses its own location), so the
# render points at the sandbox's patched files; --render-specs-only skips every
# out-of-dir side effect. The sandbox is a real git repo so the agent sees a clean tree.
build_template() { # <dir> <arm:control|treatment>
  local d="$1" arm="$2"
  rm -rf "$d"; mkdir -p "$d"
  git -C "$REPO" archive "$BASE_REF" | tar -x -C "$d"
  if [ "$arm" = treatment ] && [ -n "$DIFF" ]; then
    ( cd "$d" && git apply "$DIFF" ) || { echo "ERROR: treatment diff did not apply to $BASE_REF" >&2; exit 1; }
  fi
  if [ "$AGENT" = codex ]; then
    CODEX_HOME="$d/.codex" bash "$d/scripts/connect-agent.sh" codex --render-specs-only >/dev/null 2>&1 \
      || { echo "ERROR: 'codex --render-specs-only' failed in $d — does $BASE_REF carry the flag?" >&2; exit 1; }
    ln -sf "$HOME/.codex/auth.json" "$d/.codex/auth.json"
  else
    bash "$d/scripts/connect-agent.sh" claude --render-specs-only >/dev/null 2>&1 \
      || { echo "ERROR: 'claude --render-specs-only' failed in $d — does $BASE_REF carry the flag?" >&2; exit 1; }
  fi
  ( cd "$d" && git init -q && git config user.email e@e.co && git config user.name e \
      && git add -A && git commit -q -m init \
      && git remote add origin "$ORIGIN" )
}

echo "Building templates (agent=$AGENT, model=$MODEL, base=$BASE_REF)..."
build_template "$SANDBOX_ROOT/control"   control   || exit 1
build_template "$SANDBOX_ROOT/treatment" treatment || exit 1

# BUILD_ONLY=1 stops here — inspect the templates (rendered auto-load, applied diff)
# without spending on agent runs.
if [ -n "${BUILD_ONLY:-}" ]; then
  echo "BUILD_ONLY: templates under $SANDBOX_ROOT (control/, treatment/); skipping matrix."
  exit 0
fi

# --- Run the matrix --------------------------------------------------------------
for entry in "${TASKS[@]}"; do
  IFS='|' read -r id set grade correct wrong prompt <<< "$entry"
  in_filter "$set" "$id" || continue
  for arm in control treatment; do
    out="$OUTDIR/${AGENT}-${MODEL}-${id}-${arm}.csv"; : > "$out"
    export TASK_PROMPT="$prompt" GRADE="$grade" CORRECT_RE="$correct" WRONG_RE="$wrong"
    export ARM="$arm" TEMPLATE="$SANDBOX_ROOT/${arm}" OUT="$out"
    echo "  running $id/$arm  (agent=$AGENT, N=$N, par=$PAR)"
    seq 1 "$N" | xargs -P "$PAR" -I{} bash "$SELF/run_one.sh" {}
  done
done

# --- Summary ---------------------------------------------------------------------
echo
echo "================ SUMMARY (agent=$AGENT, model=$MODEL, N=$N, filter=$FILTER) ================"
printf '%-18s %-8s %-18s %-18s %s\n' "task" "set" "control correct" "treatment correct" ""
for entry in "${TASKS[@]}"; do
  IFS='|' read -r id set grade correct wrong prompt <<< "$entry"
  in_filter "$set" "$id" || continue
  cc=$(grep -c ',correct,' "$OUTDIR/${AGENT}-${MODEL}-${id}-control.csv" 2>/dev/null); cc=${cc:-0}
  tc=$(grep -c ',correct,' "$OUTDIR/${AGENT}-${MODEL}-${id}-treatment.csv" 2>/dev/null); tc=${tc:-0}
  note=""; [ "$grade" = no_tool ] && note="(neg: correct = no over-trigger)"
  printf '%-18s %-8s %-18s %-18s %s\n' "$id" "$set" "$cc/$N" "$tc/$N" "$note"
done
echo "Results: $OUTDIR"
echo "DONE ($AGENT/$MODEL, filter=$FILTER)"
