#!/usr/bin/env bash
# Full end-to-end (runs inside the fresh-machine container): a no-context headless
# claude follows the onboarding prompt. Turn 1 is the verbatim prompt; later rounds
# play the consenting human so it can pass outside-repo gates. Asserts: connected
# (.exobrain.json written) and NO person/host folder scaffolded.
set -uo pipefail
OUT=/out; log(){ echo "[agent-e2e] $*"; }

export CLAUDE_CODE_OAUTH_TOKEN="$(cat /run/secrets/oauth)"
export CLAUDE_CONFIG_DIR=/home/newdev/.claude-fresh
git config --global user.name instance-test; git config --global user.email it@example.invalid
# Protect the real origin from any accidental push.
git config --global url."NO-PUSH:".pushInsteadOf "$ORIGIN_URL"

REPO=/home/newdev/src/exobrain
mkdir -p /home/newdev/src
git clone -q "$ORIGIN_URL" "$REPO" 2>/dev/null || { echo "PRECLONE FAILED"; exit 1; }
cp /overlay/connect-agent.sh "$REPO/scripts/connect-agent.sh"
cp /overlay/skills-registry.sh "$REPO/scripts/skills-registry.sh"
chmod +x "$REPO"/scripts/*.sh
log "pre-cloned + overlaid local connector; agent will reuse this clone"

PROMPT="$(cat /prompt.txt)"
CONSENT="Yes — proceed through all remaining steps to the goal state without pausing for per-file confirmation; you're authorized for the outside-repo writes you described. Only stop for something genuinely only I can do. Give me the hand-off when done."
mkdir -p "$OUT"; cd /home/newdev/work
COMMON=(--permission-mode bypassPermissions --output-format stream-json --verbose --max-turns "${MAX_TURNS:-40}")

log "round 1: verbatim onboarding prompt"
timeout "${RUN_TIMEOUT:-1500}" claude -p "$PROMPT" "${COMMON[@]}" > "$OUT/transcript-1.jsonl" 2> "$OUT/stderr.log" || true
SID="$(jq -rc 'select(.type=="result")|.session_id' "$OUT/transcript-1.jsonl" 2>/dev/null | tail -1)"
for r in $(seq 2 "${CONSENT_ROUNDS:-6}"); do
  if [ -f "$REPO/.exobrain.json" ]; then log "goal reached by round $((r-1))"; break; fi
  [ -n "$SID" ] || break
  log "round $r: consent + continue"
  timeout "${RUN_TIMEOUT:-1500}" claude -p --resume "$SID" "$CONSENT" "${COMMON[@]}" > "$OUT/transcript-$r.jsonl" 2>> "$OUT/stderr.log" || true
  NEW="$(jq -rc 'select(.type=="result")|.session_id' "$OUT/transcript-$r.jsonl" 2>/dev/null | tail -1)"; [ -n "$NEW" ] && SID="$NEW"
done

echo "=== final .exobrain.json ==="; cat "$REPO/.exobrain.json" 2>/dev/null; echo
scopes="$(jq -c '.connected_scopes // empty' "$REPO/.exobrain.json" 2>/dev/null)"
newscopes="$(git -C "$REPO" status --porcelain 2>/dev/null | grep -E '^\?\?.*(people|hosts)/' || true)"
fail=0
[ -f "$REPO/.exobrain.json" ] || { echo "✗ not connected (.exobrain.json missing)"; fail=1; }
[ -n "$scopes" ] || { echo "✗ connected_scopes missing"; fail=1; }
[ -z "$newscopes" ] || { echo "✗ person/host folders scaffolded: $newscopes"; fail=1; }
[ $fail = 0 ] && echo "agent-e2e: connected at $scopes — no folders scaffolded — OK" || echo "agent-e2e: FAILED"
exit $fail
