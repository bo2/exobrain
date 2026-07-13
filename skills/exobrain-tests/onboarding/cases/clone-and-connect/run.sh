#!/usr/bin/env bash
# clone-and-connect case orchestrator. Receives $INSTANCE_DIR, $CASE_DIR, $MODE.
# Builds the fresh-machine image and runs the selected mode:
#   probe — deterministic connect cascade vs a real clone + self-seeded fixtures (no token)
#   agent — no-context headless claude walking the onboarding prompt
# The instance's connector is overlaid onto the clone so the test exercises the
# LOCAL working tree, not just what's on the origin.
set -uo pipefail
: "${INSTANCE_DIR:?}"; : "${CASE_DIR:?}"; : "${MODE:?}"
# shellcheck source=../../lib/common.sh
source "$(cd "$CASE_DIR/../../lib" && pwd)/common.sh"

IMG="instance-test-clone-and-connect"
OUT="$CASE_DIR/out"; mkdir -p "$OUT"; rm -f "$OUT"/* 2>/dev/null || true

ORIGIN_URL="${INSTANCE_TEST_ORIGIN:-$(git -C "$INSTANCE_DIR" remote get-url origin 2>/dev/null)}"
[[ "$ORIGIN_URL" == https://* ]] || { err "origin is not an https URL: ${ORIGIN_URL:-<none>}"; exit 1; }

log "building image (cached after first run)…"
docker build -q -f "$CASE_DIR/Dockerfile" -t "$IMG" "$CASE_DIR" >/dev/null || { err "image build failed"; exit 1; }

# This instance's connector overlaid so the test exercises the LOCAL working tree.
COMMON=(
  -e "ORIGIN_URL=$ORIGIN_URL"
  -v "$INSTANCE_DIR/scripts/connect-agent.sh":/overlay/connect-agent.sh:ro
  -v "$INSTANCE_DIR/scripts/skills-registry.sh":/overlay/skills-registry.sh:ro
)

if [[ "$MODE" == probe ]]; then
  docker run --rm "${COMMON[@]}" \
    -v "$CASE_DIR/probe.sh":/probe.sh:ro \
    --entrypoint bash "$IMG" /probe.sh
  exit $?
fi

# agent mode — token + the onboarding prompt. An instance whose README carries a
# real onboarding prompt should extract that here instead of the case default.
TOKEN="$OUT/oauth-token.txt"
extract_oauth_token "$INSTANCE_DIR" "$TOKEN" || { err "no CLAUDE_CODE_OAUTH_TOKEN in $INSTANCE_DIR/.env"; exit 1; }
sed "s|{ORIGIN_URL}|$ORIGIN_URL|g" "$CASE_DIR/prompt.md" > "$OUT/prompt.txt"
log "launching no-context agent (several minutes)…"

docker run --rm "${COMMON[@]}" \
  -v "$CASE_DIR/entrypoint.sh":/agent-entrypoint.sh:ro \
  -v "$OUT/prompt.txt":/prompt.txt:ro \
  -v "$TOKEN":/run/secrets/oauth:ro \
  -v "$OUT":/out \
  -e RUN_TIMEOUT="${RUN_TIMEOUT:-1500}" -e MAX_TURNS="${MAX_TURNS:-40}" -e CONSENT_ROUNDS="${CONSENT_ROUNDS:-6}" \
  --entrypoint bash "$IMG" /agent-entrypoint.sh
exit $?
