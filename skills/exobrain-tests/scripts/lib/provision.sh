#!/usr/bin/env bash
# provision.sh — provision a throwaway template instance for the suite. Sourced.
#
# The suite always tests a COPY, never a live instance. Two sources:
#   provision_self <dest>           — the current repo (this instance) at HEAD.
#   provision_from <src> <dest>     — an already-built instance dir (e.g. from
#                                     seed-tests' from-seed build).
# Then finalize_template validates it, neutralizes hooks, commits a `main` base
# branch for worktree cases, and refuses any github origin (a scratch instance
# must never point at a real remote).

# provision_self <dest> — tracked files of REPO_DIR at HEAD, no .git/src/tmp bloat.
provision_self() {
    local dest="$1"
    mkdir -p "$dest"
    git -C "$REPO_DIR" archive HEAD | tar -x -C "$dest" \
        || { err "[provision] git archive of the current repo failed"; return 1; }
}

# provision_from <src-instance> <dest> — copy an already-built instance verbatim.
provision_from() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    cp -R "$src" "$dest"
}

# finalize_template <dir> — make a provisioned copy safe and ready to test.
finalize_template() {
    local template="$1"

    # A git archive copy has no .git; an already-built instance does.
    [[ -d "$template/.git" ]] || git -C "$template" init -q

    if ! ( cd "$template" && scripts/validate-exobrain.sh --quiet ); then
        err "[provision] provisioned instance FAILS validate-exobrain.sh"
        return 1
    fi

    # Safety: a real github origin must never exist in a scratch instance.
    local origin
    origin="$(git -C "$template" remote get-url origin 2>/dev/null || true)"
    if [[ "$origin" == *github.com* ]]; then
        err "[provision] template has a github.com origin ($origin) — refusing to proceed"
        return 1
    fi

    # Neutralize hooks so the pre-push validator / relink hooks never fire while a
    # case's agent runs git inside the instance.
    git -C "$template" config core.hooksPath /dev/null

    # Establish a `main` base branch so worktree-based cases have something to
    # branch from.
    git -C "$template" add -A
    git -C "$template" \
        -c user.email=harness@exobrain.test -c user.name='exobrain harness' \
        commit -q -m "harness: instance snapshot" || true
    git -C "$template" branch -M main 2>/dev/null || true

    log "[provision] template finalized: validate OK, committed on main, hooks off, no github origin"
}

# make_run_copy <template> <dest> — a fresh per-run copy of the finalized template.
make_run_copy() {
    local template="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    cp -R "$template" "$dest"
}
