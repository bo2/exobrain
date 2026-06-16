#!/usr/bin/env bash
# instance.sh — build a sample exobrain instance and clone it per run. Sourced.
#
# build_template <run_root> [builder_agent]  -> $run_root/template
# make_run_copy <template> <dest>
#
# The template is produced by running the REAL exobrain-create skill via the
# builder agent (default claude) against a local clone of the seed under test, so
# the bootstrap flow is itself exercised. The instance content is agent-neutral;
# one template is built and every agent-under-test runs against copies of it. The
# template is then validated, committed (to establish a `main` base branch),
# hook-neutralized, and asserted free of any github origin.

# render_build_prompt <builder_agent> — the task handed to the agent to scaffold
# the instance. The heredoc stays literal (so $SRC/$DST and backticks survive);
# the agent name is substituted into the __AGENT__ placeholder.
render_build_prompt() {
    local agent="$1"
    cat <<'EOF' | sed "s/__AGENT__/$agent/g"
You are scaffolding a new exobrain instance in the CURRENT working directory.

The seed (source framework to copy from) is ALREADY present at
./src/exobrain-seed — use it as $SRC. Do NOT clone anything from GitHub or the
network; work entirely from that local copy.

Follow the procedure in ./src/exobrain-seed/skills/exobrain-create/SKILL.md
exactly, scaffolding the new instance into the current directory ($DST = the
current directory, which currently contains only src/exobrain-seed — it is fine
to add to it).

This is a NON-INTERACTIVE run. Do not ask questions; use these interview answers:
- Purpose: solo (just one person)
- Handle: test-user
- Machine name: test-host
- Vocabulary: keep the default durable-content directory name "domains/"
- Starting domains: finance, home
- Agent to connect: __AGENT__

Run the procedure to completion, including: copying the framework, the
meta-domain, and the three shipped skills; creating the scope directories and the
adopted-feed.md ledger; writing .exobrain.json; then `git init`,
`scripts/validate-exobrain.sh` (must pass), and `scripts/connect-agent.sh __AGENT__`.

Do NOT create any git commits — leave committing to the harness. Do NOT push
anything anywhere. When finished, briefly confirm the instance is scaffolded and
that validate-exobrain.sh passed.
EOF
}

build_template() {
    local run_root="$1" builder="${2:-claude}"
    local template="$run_root/template"
    local seed_cache="$template/src/exobrain-seed"

    mkdir -p "$template"
    log "[build] cloning local seed -> src/exobrain-seed"
    git clone --local --no-hardlinks --quiet "$REPO_DIR" "$seed_cache" \
        || { err "[build] local seed clone failed"; return 1; }

    local prompt_file="$run_root/.build-prompt.txt"
    render_build_prompt "$builder" >"$prompt_file"

    log "[build] running exobrain-create via $builder (one agent session; may take minutes)…"
    invoke_agent "$builder" "$template" "$prompt_file" build "${BUILD_TIMEOUT:-900}" "${BUILD_MODEL:-}" \
        text "$run_root/build.stdout.txt"
    log "[build] exobrain-create session finished ($builder rc=$?)"

    finalize_template "$template"
}

finalize_template() {
    local template="$1"

    if [[ ! -d "$template/.git" ]]; then
        err "[build] no .git in template — exobrain-create did not run 'git init'"
        return 1
    fi

    if ! ( cd "$template" && scripts/validate-exobrain.sh --quiet ); then
        err "[build] scaffolded instance FAILS validate-exobrain.sh"
        return 1
    fi

    # Safety: a real github origin must never exist in a scratch instance.
    local origin
    origin="$(git -C "$template" remote get-url origin 2>/dev/null || true)"
    if [[ "$origin" == *github.com* ]]; then
        err "[build] template has a github.com origin ($origin) — refusing to proceed"
        return 1
    fi

    # Neutralize hooks so the pre-push authoring-review (an LLM call) and the
    # relink hooks never fire while a case's agent runs git inside the instance.
    git -C "$template" config core.hooksPath /dev/null

    # Establish a `main` base branch so worktree-based cases have something to
    # branch from (exobrain-create deliberately leaves committing to the user).
    git -C "$template" add -A
    git -C "$template" \
        -c user.email=harness@exobrain.test -c user.name='exobrain harness' \
        commit -q -m "harness: initial instance snapshot" || true
    git -C "$template" branch -M main 2>/dev/null || true

    log "[build] template finalized: validate OK, committed on main, hooks off, no github origin"
}

make_run_copy() {
    local template="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    cp -R "$template" "$dest"
}
