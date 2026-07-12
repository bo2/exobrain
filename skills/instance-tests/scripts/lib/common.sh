#!/usr/bin/env bash
# Shared helpers for the instance-tests suite: logging, requirement checks.
# Requirement checkers return 0 when satisfied. They never print secret values.

BOLD=$'\033[1m'; RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; DIM=$'\033[0;90m'; RESET=$'\033[0m'

log()  { echo "${DIM}[instance-tests]${RESET} $*"; }
err()  { echo "${RED}[instance-tests] $*${RESET}" >&2; }

# require_<name> <instance_dir> — 0 if the requirement is met on this machine.
require_docker() { command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; }

# origin-https: the instance's origin is an https URL a container can clone
# (anonymously for a public repo; a private one needs creds baked into the case).
require_origin_https() {
    local url
    url="$(git -C "$1" remote get-url origin 2>/dev/null)" || return 1
    [[ "$url" == https://* ]] || return 1
    git ls-remote --heads "$url" >/dev/null 2>&1
}

require_oauth_token() { local env="$1/.env"; [ -f "$env" ] && grep -q '^CLAUDE_CODE_OAUTH_TOKEN=' "$env"; }

# check_requirement <name> <instance_dir> — dispatch by requirement name.
check_requirement() {
    case "$1" in
        docker)       require_docker ;;
        origin-https) require_origin_https "$2" ;;
        oauth-token)  require_oauth_token "$2" ;;
        *)            err "unknown requirement: $1"; return 2 ;;
    esac
}

# extract_oauth_token <instance_dir> <dest_file> — copy ONLY the token var from .env
# into dest via redirect; the value is never printed to stdout. Returns 1 if absent.
extract_oauth_token() {
    local env="$1/.env" dest="$2"
    grep -m1 '^CLAUDE_CODE_OAUTH_TOKEN=' "$env" 2>/dev/null \
        | sed -E 's/^CLAUDE_CODE_OAUTH_TOKEN=//; s/^"//; s/"$//; s/^'\''//; s/'\''$//' > "$dest" || true
    chmod 600 "$dest" 2>/dev/null || true
    [ -s "$dest" ] || { rm -f "$dest"; return 1; }
}
