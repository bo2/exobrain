#!/usr/bin/env bash
# One eval run. Spawned in parallel by run.sh via `xargs -P`.
# Env in: AGENT, ARM, TEMPLATE, STUBS, MODEL, TASK_PROMPT, GRADE, CORRECT_RE, WRONG_RE,
#         OUT, SANDBOX_ROOT, MAX_TURNS, TIMEOUT.
# Arg: run index. Appends "<i>,<verdict>,<stublog>" to $OUT.
# Verdict: correct | wrong | other | FAILED (agent produced no output after retries).
#
# The tool decision is captured by PATH-shadow stubs (STUB_LOG), identically for both
# agents. Retries distinguish a *failed* run (empty stdout) from a legit no-tool run
# (empty stublog but real stdout) — so concurrency hiccups self-heal without corrupting
# the no_tool negatives.
i="$1"
RUN="${SANDBOX_ROOT:-/tmp/exo-ab}/${ARM}_run_$$_${i}"
LOG="$RUN.stublog"; OUTF="$RUN.out"

run_agent() { # cwd=$RUN, PATH already has $STUBS, STUB_LOG set
  if [ "${AGENT:-claude}" = codex ]; then
    # CODEX_HOME points at the copy's rendered .codex; inherit=all so the stub PATH +
    # STUB_LOG reach codex's command shell; bypass codex's own sandbox (we shadow tools).
    CODEX_HOME="$RUN/.codex" timeout "${TIMEOUT:-240}" codex exec -C "$RUN" \
      --ignore-user-config --dangerously-bypass-approvals-and-sandbox --ephemeral \
      --skip-git-repo-check -c shell_environment_policy.inherit=all \
      -m "${MODEL:-gpt-5.5}" "$TASK_PROMPT" </dev/null >"$OUTF" 2>/dev/null
  else
    timeout "${TIMEOUT:-240}" claude -p "$TASK_PROMPT" --model "${MODEL:-opus}" \
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
if [ "$ok" = 0 ]; then
  v=FAILED
elif [ "$GRADE" = no_tool ]; then
  if [ -s "$LOG" ]; then v=wrong; else v=correct; fi   # any stub firing = over-trigger
else
  v=other
  grep -qE "$CORRECT_RE" "$LOG" && v=correct
  [ "$v" = other ] && grep -qE "$WRONG_RE" "$LOG" && v=wrong
fi
printf '%s,%s,%s\n' "$i" "$v" "$(tr '\n' ';' < "$LOG" 2>/dev/null | tr ',' ' ')" >> "$OUT"
rm -rf "$RUN" "$LOG" "$OUTF"
