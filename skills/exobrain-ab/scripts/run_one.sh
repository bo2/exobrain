#!/usr/bin/env bash
# One eval run. Spawned in parallel by run.sh via `xargs -P`.
# Env in: AGENT, ARM, TEMPLATE, STUBS, MODEL, TASK_PROMPT, GRADE, CORRECT_RE, WRONG_RE,
#         OUT, SANDBOX_ROOT, MAX_TURNS, TIMEOUT.
# Arg: run index. Appends "<i>,<verdict>,<evidence>" to $OUT.
# Verdict: correct | wrong | other | FAILED (agent produced no output after retries).
#
# Two things are observable, and GRADE picks which one a task scores:
#   - the tool decision — which command the agent reached for (PATH-shadow STUB_LOG);
#   - the authored output — what the agent actually wrote ($OUTF, its stdout).
# So the harness can A/B any desired behaviour, not just tool choice. Retries
# distinguish a *failed* run (empty stdout) from a legit no-tool run (empty stublog but
# real stdout) — so concurrency hiccups self-heal without corrupting the negatives.
i="$1"
RUN="${SANDBOX_ROOT:-/tmp/exo-ab}/${ARM}_run_$$_${i}"
LOG="$RUN.stublog"; OUTF="$RUN.out"

# Bound each agent run when a coreutils `timeout` exists (macOS ships none; Homebrew
# installs it as `gtimeout`); without one the run is unbounded rather than failed.
TMO=()
if t="$(command -v timeout 2>/dev/null)"; then TMO=("$t" "${TIMEOUT:-240}")
elif t="$(command -v gtimeout 2>/dev/null)"; then TMO=("$t" "${TIMEOUT:-240}"); fi

run_agent() { # cwd=$RUN, PATH already has $STUBS, STUB_LOG set
  if [ "${AGENT:-claude}" = codex ]; then
    # CODEX_HOME points at the copy's wired .codex; inherit=all so the stub PATH +
    # STUB_LOG reach codex's command shell; bypass codex's own sandbox (we shadow tools).
    CODEX_HOME="$RUN/.codex" ${TMO[@]+"${TMO[@]}"} codex exec -C "$RUN" \
      --ignore-user-config --dangerously-bypass-approvals-and-sandbox --ephemeral \
      --skip-git-repo-check -c shell_environment_policy.inherit=all \
      -m "${MODEL:-gpt-5.5}" "$TASK_PROMPT" </dev/null >"$OUTF" 2>/dev/null
  else
    ${TMO[@]+"${TMO[@]}"} claude -p "$TASK_PROMPT" --model "${MODEL:-opus}" \
      --max-turns "${MAX_TURNS:-14}" --permission-mode bypassPermissions >"$OUTF" 2>/dev/null
  fi
}

ok=0
for attempt in 1 2 3; do
  rm -rf "$RUN"; cp -R "$TEMPLATE" "$RUN"; : > "$LOG"
  ( cd "$RUN" && export STUB_LOG="$LOG" PATH="$STUBS:$PATH" && run_agent )
  if [ -s "$OUTF" ]; then ok=1; break; fi   # real result -> done
  sleep 3
done
# Grade. Tool-choice modes read the PATH-stub log ($LOG = which command fired);
# output modes read the agent's own stdout ($OUTF = what it wrote). "*_absent" modes
# are negatives — correct = the pattern is absent. The evidence column records the
# graded stream so a verdict is inspectable after the fact.
ev=""
if [ "$ok" = 0 ]; then
  v=FAILED
else
  case "$GRADE" in
    no_tool)                # stublog negative: any stub firing = over-trigger
      if [ -s "$LOG" ]; then v=wrong; else v=correct; fi
      ev="$(tr '\n' ';' < "$LOG" 2>/dev/null)" ;;
    output)                 # stdout: correct_re wins; else wrong_re => wrong
      v=other
      [ -n "$CORRECT_RE" ] && grep -qE "$CORRECT_RE" "$OUTF" && v=correct
      [ "$v" = other ] && [ -n "$WRONG_RE" ] && grep -qE "$WRONG_RE" "$OUTF" && v=wrong
      ev="$(grep -hoE "${WRONG_RE:-$CORRECT_RE}" "$OUTF" 2>/dev/null | head -3 | tr '\n' ';')" ;;
    output_absent)          # stdout negative: correct = wrong_re NOT present
      if grep -qE "$WRONG_RE" "$OUTF"; then v=wrong; else v=correct; fi
      ev="$(grep -hoE "$WRONG_RE" "$OUTF" 2>/dev/null | head -3 | tr '\n' ';')" ;;
    *)                      # match (default): grade the stublog
      v=other
      grep -qE "$CORRECT_RE" "$LOG" && v=correct
      [ "$v" = other ] && grep -qE "$WRONG_RE" "$LOG" && v=wrong
      ev="$(tr '\n' ';' < "$LOG" 2>/dev/null)" ;;
  esac
fi
printf '%s,%s,%s\n' "$i" "$v" "$(printf '%s' "$ev" | tr ',' ' ')" >> "$OUT"
rm -rf "$RUN" "$LOG" "$OUTF"
