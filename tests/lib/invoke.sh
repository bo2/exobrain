#!/usr/bin/env bash
# invoke.sh — non-interactive agent runner, dispatching on the agent. Sourced.
#
# invoke_agent <agent> <instance_dir> <prompt_file> <profile> <timeout_s> <model> <output_format> <out_file>
#   agent:   claude | codex
#   profile: read-only | action | build | static
#     read-only    -> no writes (claude plan mode / codex read-only sandbox)
#     action/build -> writable (claude acceptEdits+allowlist / codex workspace-write)
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

    local -a perm=()
    case "$profile" in
        read-only)
            perm=(--permission-mode plan) ;;
        action|build)
            perm=(--permission-mode "${EXOBRAIN_TEST_PERMISSION_MODE:-acceptEdits}"
                  --settings "$ALLOW_SETTINGS") ;;
        *)
            perm=(--permission-mode plan) ;;
    esac

    local -a model_flag=()
    [[ -n "$model" && "$model" != "null" ]] && model_flag=(--model "$model")

    make_timeout "$tmo"

    # cwd is the instance; also allow its parent run dir so a sibling worktree
    # created by create-worktree.sh (…/run-N/instance--<branch>) is writable.
    local rundir; rundir="$(dirname "$inst")"

    (
        cd "$inst" || exit 127
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
        read-only)    sandbox="read-only" ;;
        action|build) sandbox="workspace-write" ;;
        *)            sandbox="read-only" ;;
    esac

    local -a model_flag=()
    [[ -n "$model" && "$model" != "null" ]] && model_flag=(-m "$model")

    make_timeout "$tmo"

    # In workspace-write, also allow the parent run dir so a sibling worktree
    # created by create-worktree.sh is writable (only added for writable runs, so
    # a malformed override can't break read-only cases).
    local rundir; rundir="$(dirname "$inst")"
    local -a extra=()
    [[ "$sandbox" == "workspace-write" ]] && \
        extra=(-c "sandbox_workspace_write.writable_roots=[\"$rundir\"]")

    (
        cd "$inst" || exit 127
        "${NOPROXY[@]}" "${TIMEOUT[@]}" codex exec \
            -s "$sandbox" "${extra[@]}" "${model_flag[@]}" - \
            <"$prompt_file"
    ) >"$out" 2>"$out.err"
}
