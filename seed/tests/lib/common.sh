#!/usr/bin/env bash
# common.sh — shared helpers for the exobrain behavioral test harness.
# Sourced by run.sh and the other lib/*.sh files; not run directly.

# Resolve paths: this harness lives at <repo>/seed/tests/lib/.
TESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$TESTS_LIB_DIR")"   # <repo>/seed/tests
SEED_DIR="$(dirname "$TESTS_DIR")"        # <repo>/seed
REPO_DIR="$(dirname "$SEED_DIR")"         # <repo> — the seed under test
ALLOW_SETTINGS="$TESTS_DIR/settings/allow.json"

# Strip inherited proxy vars from the engine subprocess — the model API is
# reached directly, never through a SOCKS/HTTP proxy that would break the call.
# `env -u` of an unset var is a no-op, so this is safe with or without a proxy.
NOPROXY=(env -u ALL_PROXY -u HTTPS_PROXY -u HTTP_PROXY -u all_proxy -u https_proxy -u http_proxy)

# make_timeout <seconds> — set the global TIMEOUT array to a timeout/gtimeout
# invocation, or empty if neither is on PATH (then the command runs unbounded).
make_timeout() {
    local secs="$1" t
    TIMEOUT=()
    if t="$(command -v timeout 2>/dev/null)"; then TIMEOUT=("$t" "$secs")
    elif t="$(command -v gtimeout 2>/dev/null)"; then TIMEOUT=("$t" "$secs"); fi
}

log() { printf '%s\n' "$*" >&2; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

# agent_available <claude|codex> — true only if the agent's CLI is installed AND
# actually runnable. codex can be present on PATH but broken (its native binary
# dependency missing), in which case --version exits non-zero; we skip it.
agent_available() {
    case "$1" in
        claude) command -v claude >/dev/null 2>&1 && claude --version >/dev/null 2>&1 ;;
        codex)  command -v codex  >/dev/null 2>&1 && codex  --version >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

# threshold_met <passes> <total> <threshold> — exit 0 if the pass count clears
# the bar. threshold is "all" (every run must pass) or a fraction like 0.8.
threshold_met() {
    local passes="$1" total="$2" thr="$3"
    [[ "$total" -eq 0 ]] && return 1
    if [[ "$thr" == "all" ]]; then
        [[ "$passes" -eq "$total" ]]
    else
        awk -v p="$passes" -v t="$total" -v thr="$thr" 'BEGIN { exit !(t>0 && p/t >= thr) }'
    fi
}

# json_str <text> — emit a JSON-escaped string (including surrounding quotes).
json_str() {
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$1" | jq -Rsa .
    else
        # Minimal fallback: escape backslash, quote, and newline.
        local s="$1"
        s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"
        printf '"%s"' "$s"
    fi
}
