#!/usr/bin/env bash
# invoke.sh — wrapper around non-interactive `claude -p`. Sourced, not run.
#
# invoke_agent <instance_dir> <prompt_file> <profile> <timeout_s> <model> <output_format> <out_file>
#   profile: read-only | action | build | static
#     read-only -> --permission-mode plan (no writes)
#     action/build -> --permission-mode acceptEdits + the curated --settings allowlist
#     static -> no agent call at all (caller checks state directly)
#   Writes the transcript to <out_file> and stderr to <out_file>.err.
#   Returns claude's exit code (124 = timed out). Always returns 0 for `static`.

invoke_agent() {
    local inst="$1" prompt_file="$2" profile="$3" tmo="$4" model="$5" ofmt="$6" out="$7"

    [[ "$profile" == "static" ]] && { : >"$out"; return 0; }

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
