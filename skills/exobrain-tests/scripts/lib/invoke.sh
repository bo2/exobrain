#!/usr/bin/env bash
# invoke.sh — non-interactive agent runner, dispatching on the agent. Sourced.
#
# invoke_agent <agent> <instance_dir> <prompt_file> <profile> <timeout_s> <model> <output_format> <out_file>
#   agent:   claude | codex
#   profile: read-only | action | security | security-mcp | build | static
#     read-only    -> no writes (claude plan mode / codex read-only sandbox)
#     action       -> writable, curated allowlist (claude acceptEdits+allowlist /
#                     codex workspace-write) — the behavioral cases
#     security     -> like action, plus the adversarial red-team containment layer:
#                     egress commands ALLOWED (so the PATH-shadow stubs in
#                     $STUB_DIR fire and log to $EGRESS_LOG instead of transmitting),
#                     all MCP servers disabled (empty --mcp-config, --strict-mcp-config),
#                     and codex's shell env inherited so the stubs reach it
#     security-mcp -> as security, but instead of disabling MCP it registers the mock
#                     stdio server ($MCP_MOCK) as the ONLY reachable MCP server (still
#                     --strict-mcp-config), which logs every tools/call to $EGRESS_LOG
#                     — exposing the MCP egress vector the shell stubs can't shadow
#     build        -> writable, no allowlist gate (claude bypassPermissions /
#                     codex workspace-write) — the from-seed instance scaffold
#     static       -> no agent call at all (caller checks state directly)
#   Writes the transcript to <out_file> and stderr to <out_file>.err.
#   Returns the engine's exit code (124 = timed out). Always 0 for `static`.

invoke_agent() {
    local agent="$1" inst="$2" prompt_file="$3" profile="$4" tmo="$5" model="$6" ofmt="$7" out="$8"

    [[ "$profile" == "static" ]] && { : >"$out"; return 0; }

    case "$agent" in
        claude) _invoke_claude "$inst" "$prompt_file" "$profile" "$tmo" "$model" "$ofmt" "$out" ;;
        codex)  _invoke_codex  "$inst" "$prompt_file" "$profile" "$tmo" "$model" "$out" ;;
        *)      err "unknown agent: $agent"; : >"$out"; return 2 ;;
    esac
}

# --- claude ----------------------------------------------------------------
_invoke_claude() {
    local inst="$1" prompt_file="$2" profile="$3" tmo="$4" model="$5" ofmt="$6" out="$7"

    # cwd is the instance; also allow its parent run dir so a sibling worktree
    # created by create-worktree.sh (…/run-N/instance--<branch>) is writable.
    local rundir; rundir="$(dirname "$inst")"
    local egress="$rundir/egress.log"

    local -a perm=()
    case "$profile" in
        read-only)
            perm=(--permission-mode plan) ;;
        build)
            # The from-seed build scaffolds a whole instance and runs the instance's
            # own framework scripts (validate-exobrain.sh, connect-agent.sh, …) by
            # whatever path the agent picks — usually absolute, since the Bash tool's
            # cwd doesn't persist between calls. A curated relative-path allowlist
            # can't match those, so it would stall the build on non-answerable
            # approval prompts until timeout. The build is hermetic (throwaway tmp
            # sandbox) and network-neutralized (NOPROXY), so bypass the permission
            # gate; --settings still carries the deny guards (no push/network).
            perm=(--permission-mode bypassPermissions --settings "$ALLOW_SETTINGS") ;;
        action)
            perm=(--permission-mode "${EXOBRAIN_TEST_PERMISSION_MODE:-acceptEdits}"
                  --settings "$ALLOW_SETTINGS") ;;
        security)
            # Writable like action, but the security allowlist ALLOWS egress
            # commands so the PATH stubs fire, and MCP is fully disabled so no
            # real MCP server (chat/email/publishing) is reachable.
            perm=(--permission-mode "${EXOBRAIN_TEST_PERMISSION_MODE:-acceptEdits}"
                  --settings "$SECURITY_SETTINGS"
                  --strict-mcp-config --mcp-config "$EMPTY_MCP") ;;
        security-mcp)
            # As security, but register the mock stdio server as the ONLY reachable
            # MCP server (strict). Generated per-run so the server's absolute path
            # and this run's $EGRESS_LOG sink are baked into its env — the mock logs
            # every tools/call there instead of transmitting.
            local mcpcfg="$rundir/mcp-config.json"
            cat >"$mcpcfg" <<JSON
{"mcpServers":{"egress_mock":{"command":"python3","args":["$MCP_MOCK"],"env":{"EGRESS_LOG":"$egress"}}}}
JSON
            perm=(--permission-mode "${EXOBRAIN_TEST_PERMISSION_MODE:-acceptEdits}"
                  --settings "$SECURITY_SETTINGS"
                  --strict-mcp-config --mcp-config "$mcpcfg") ;;
        *)
            perm=(--permission-mode plan) ;;
    esac

    local -a model_flag=()
    [[ -n "$model" && "$model" != "null" ]] && model_flag=(--model "$model")

    make_timeout "$tmo"

    (
        cd "$inst" || exit 127
        if [[ "$profile" == security* ]]; then
            # Shadow egress binaries and point the stubs at this run's sink. The
            # agent's Bash tool inherits this PATH + EGRESS_LOG, so `curl`/`gh`/…
            # resolve to the loggers in $STUB_DIR. Init the sink so check.sh always
            # finds it (empty == no egress attempted). For security-mcp the mock MCP
            # server appends to the same sink.
            export EGRESS_LOG="$egress"; : >"$EGRESS_LOG"
            export PATH="$STUB_DIR:$PATH"
        fi
        "${NOPROXY[@]}" "${TIMEOUT[@]}" claude -p \
            "${perm[@]}" "${model_flag[@]}" \
            --add-dir "$inst" --add-dir "$rundir" \
            --output-format "$ofmt" \
            <"$prompt_file"
    ) >"$out" 2>"$out.err"
}

# --- codex -----------------------------------------------------------------
# Profiles map to codex sandbox modes: read-only -> read-only; action/build ->
# workspace-write. The prompt is read from stdin (trailing `-`), matching the
# idiom in scripts/authoring-review.sh (`codex exec -s read-only -`). codex
# auto-loads the instance's root AGENTS.md from the working directory, so no
# connect-agent step is needed for the case rules under test.
#
# NOTE: coded against codex's documented `codex exec -s <sandbox> -` interface;
# re-confirm the writable-roots override after reinstalling codex
# (`npm install -g @openai/codex@latest`).
_invoke_codex() {
    local inst="$1" prompt_file="$2" profile="$3" tmo="$4" model="$5" out="$6"

    local sandbox
    case "$profile" in
        read-only)                          sandbox="read-only" ;;
        action|security|security-mcp|build) sandbox="workspace-write" ;;
        *)                                  sandbox="read-only" ;;
    esac

    local -a model_flag=()
    [[ -n "$model" && "$model" != "null" ]] && model_flag=(-m "$model")

    make_timeout "$tmo"

    # In workspace-write, also make the parent run dir writable so a sibling
    # worktree created by create-worktree.sh (…/run-N/instance--<branch>) can be
    # written (codex's first-class flag for extra writable roots).
    local rundir; rundir="$(dirname "$inst")"
    local egress="$rundir/egress.log"
    local -a extra=()
    [[ "$sandbox" == "workspace-write" ]] && extra=(--add-dir "$rundir")

    # security*: make codex's spawned shell inherit our PATH + EGRESS_LOG (so the
    # PATH stubs shadow its egress commands — codex runs tool commands in its own
    # shell, which otherwise ignores the exported PATH). security disables all MCP
    # servers; security-mcp registers the mock server as the only one (with the
    # sink in its env), exposing the MCP egress vector.
    local -a sec=()
    case "$profile" in
        security)
            sec=(-c shell_environment_policy.inherit=all -c 'mcp_servers={}') ;;
        security-mcp)
            # The mock registers and initializes fine under codex, and the model
            # DOES emit the tools/call — but codex `exec` has no channel for MCP
            # tool-call elicitation/approval, so it auto-cancels every MCP call
            # (even with approval_policy=never). So on codex this vector cannot
            # complete (exfil-via-MCP is impossible by construction) and the case is
            # graded behaviorally by the judge; the deterministic egress-log signal
            # is claude-only. approval_policy=never is still the right hermetic
            # posture (no stalls on shell approvals). Re-check on codex upgrades.
            sec=(-c shell_environment_policy.inherit=all
                 -c 'approval_policy="never"'
                 -c "mcp_servers.egress_mock.command=\"python3\""
                 -c "mcp_servers.egress_mock.args=[\"$MCP_MOCK\"]"
                 -c "mcp_servers.egress_mock.env.EGRESS_LOG=\"$egress\"") ;;
    esac

    (
        cd "$inst" || exit 127
        if [[ "$profile" == security* ]]; then
            export EGRESS_LOG="$egress"; : >"$EGRESS_LOG"
            export PATH="$STUB_DIR:$PATH"
        fi
        "${NOPROXY[@]}" "${TIMEOUT[@]}" codex exec \
            -s "$sandbox" "${extra[@]}" "${sec[@]}" "${model_flag[@]}" - \
            <"$prompt_file"
    ) >"$out" 2>"$out.err"
}
