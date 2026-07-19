#!/usr/bin/env bash
# provision.sh — provision a throwaway template instance for the suite. Sourced.
#
# The suite always tests a COPY of the instance it is installed in, never the live
# tree. provision_self snapshots REPO_DIR at HEAD (committed state); provision_working_tree
# snapshots the current working tree (uncommitted local changes) so a change can be tested
# before it lands. finalize_template then validates the snapshot, neutralizes hooks,
# commits a `main` base branch for worktree cases, and refuses any github origin (a scratch
# instance must never point at a real remote).

# provision_self <dest> — tracked files of REPO_DIR at HEAD, no .git/src/tmp bloat.
provision_self() {
    local dest="$1"
    mkdir -p "$dest"
    git -C "$REPO_DIR" archive HEAD | tar -x -C "$dest" \
        || { err "[provision] git archive of the current instance failed"; return 1; }
}

# provision_working_tree <dest> — snapshot the CURRENT working tree (committed +
# uncommitted: new, modified, deleted, renamed), honoring .gitignore (so src/, tmp/,
# .claude, .exobrain.json are excluded). Lets you test local changes before persisting
# them. Built by staging the working tree into a TEMPORARY index (GIT_INDEX_FILE), so
# the user's real staging area is never touched, then archiving that tree.
provision_working_tree() {
    local dest="$1"
    mkdir -p "$dest"
    local tmp_index; tmp_index="$(mktemp)"; rm -f "$tmp_index"   # a non-existent path → git inits a fresh index
    local tree
    if ! GIT_INDEX_FILE="$tmp_index" git -C "$REPO_DIR" add -A 2>/dev/null \
       || ! tree="$(GIT_INDEX_FILE="$tmp_index" git -C "$REPO_DIR" write-tree 2>/dev/null)"; then
        rm -f "$tmp_index"
        err "[provision] could not snapshot the working tree"; return 1
    fi
    rm -f "$tmp_index"
    git -C "$REPO_DIR" archive "$tree" | tar -x -C "$dest" \
        || { err "[provision] git archive of the working-tree snapshot failed"; return 1; }
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
