#!/usr/bin/env bash
# build.sh — build a fresh instance from the canonical seed by running the REAL
# create-instance skill via a builder agent, so the bootstrap flow is itself
# exercised. Sourced by seed-tests' run.sh. Requires log/err + invoke_agent +
# REPO_DIR (the seed) from exobrain-tests' common.sh / invoke.sh.
#
#   build_raw_instance <dest> [builder_agent]   -> a scaffolded instance at <dest>
#
# Produces a RAW instance (scaffolded + connected, not finalized). exobrain-tests'
# provisioner finalizes the copy it runs against (validate, main base, hooks off).

# render_build_prompt <builder_agent> — the task handed to the agent to scaffold the
# instance. The heredoc stays literal (so $SRC/$DST and backticks survive); the
# agent name is substituted into the __AGENT__ placeholder.
render_build_prompt() {
    local agent="$1"
    cat <<'EOF' | sed "s/__AGENT__/$agent/g"
You are scaffolding a new exobrain instance in the CURRENT working directory.

The seed (source framework to copy from) is ALREADY present at
./src/exobrain-seed — use it as $SRC. Do NOT clone anything from GitHub or the
network; work entirely from that local copy.

Follow the procedure in ./src/exobrain-seed/seed/skills/create-instance/SKILL.md
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
adopted-feed.md ledger; then `git init`, `scripts/validate-exobrain.sh` (must
pass), and `scripts/connect-agent.sh __AGENT__ --handle test-user --host test-host`
(which establishes the connection and writes .exobrain.json).

Do NOT create any git commits — leave committing to the harness. Do NOT push
anything anywhere. When finished, briefly confirm the instance is scaffolded and
that validate-exobrain.sh passed.
EOF
}

# build_raw_instance <dest> [builder] — clone the seed into <dest>/src/exobrain-seed
# and run create-instance via the builder agent to scaffold <dest>.
build_raw_instance() {
    local dest="$1" builder="${2:-claude}"
    local seed_cache="$dest/src/exobrain-seed"

    mkdir -p "$dest"
    log "[build] cloning local seed -> src/exobrain-seed"
    git clone --local --no-hardlinks --quiet "$REPO_DIR" "$seed_cache" \
        || { err "[build] local seed clone failed"; return 1; }

    local prompt_file="$dest/.build-prompt.txt"
    render_build_prompt "$builder" >"$prompt_file"

    log "[build] running create-instance via $builder (one agent session; may take minutes)…"
    invoke_agent "$builder" "$dest" "$prompt_file" build "${BUILD_TIMEOUT:-1800}" "${BUILD_MODEL:-}" \
        text "$dest/build.stdout.txt"
    log "[build] create-instance session finished ($builder rc=$?)"

    if [[ ! -d "$dest/.git" ]]; then
        err "[build] no .git in instance — create-instance did not run 'git init'"
        return 1
    fi
    # The seed clone is the instance's update-cache, but it bloats the test copy
    # and must never be mistaken for instance content — drop it before testing.
    rm -rf "$dest/src"
}
