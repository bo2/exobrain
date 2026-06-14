#!/usr/bin/env bash
# create-worktree.sh — Create a git worktree following exobrain conventions.
#
# Run from inside any git repo:
#   create-worktree.sh <branch>
#
# - Worktree path is a sibling of the main repo dir, named <repo>--<branch>
#   with '/' in the branch replaced by '-'.
# - Branch is created off origin's default branch (or trunk/main fallback)
#   if it doesn't exist; otherwise the existing branch is checked out.
# - Symlinks .env, .env.*, and .exobrain.json from the main repo into the
#   worktree if they exist there but not in the worktree (skips tracked
#   files like .env.example that already materialize in the worktree).
#   Walks the repo root plus immediate subdirectories so nested env files
#   like api/.env.development are picked up too.
# - Prints the worktree path on stdout, so:
#     cd "$(scripts/create-worktree.sh fix-budget-calc)"

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: create-worktree.sh <branch>

Run from inside the git repo where you want the worktree.

The new worktree is created as a sibling of the main repo directory,
named <repo>--<branch> with '/' replaced by '-'.

Examples:
  create-worktree.sh fix-budget-calc
  create-worktree.sh add-codex-connector
EOF
}

if [[ $# -ne 1 ]]; then
    usage >&2
    exit 1
fi
case "$1" in
    -h|--help) usage; exit 0 ;;
esac

BRANCH="$1"

# Resolve the main repo working directory regardless of whether we're invoked
# from the main checkout or from an existing worktree.
GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null)" || {
    echo "create-worktree: not inside a git repo" >&2
    exit 1
}
[[ "$GIT_COMMON_DIR" = /* ]] || GIT_COMMON_DIR="$(pwd)/$GIT_COMMON_DIR"
MAIN_ROOT="$(cd "$GIT_COMMON_DIR/.." && pwd)"

REPO_NAME="$(basename "$MAIN_ROOT")"
PARENT_DIR="$(cd "$MAIN_ROOT/.." && pwd)"

BRANCH_SAFE="${BRANCH//\//-}"
WORKTREE_PATH="$PARENT_DIR/${REPO_NAME}--${BRANCH_SAFE}"

if [[ -e "$WORKTREE_PATH" ]]; then
    echo "create-worktree: target already exists: $WORKTREE_PATH" >&2
    exit 1
fi

# Pick a base branch for new branches.
BASE_BRANCH=""
if ref="$(git -C "$MAIN_ROOT" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null)"; then
    BASE_BRANCH="${ref#refs/remotes/origin/}"
fi
if [[ -z "$BASE_BRANCH" ]] || ! git -C "$MAIN_ROOT" rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
    for cand in trunk main master; do
        if git -C "$MAIN_ROOT" rev-parse --verify "$cand" >/dev/null 2>&1; then
            BASE_BRANCH="$cand"
            break
        fi
    done
fi
[[ -n "$BASE_BRANCH" ]] || BASE_BRANCH="$(git -C "$MAIN_ROOT" rev-parse --abbrev-ref HEAD)"

if git -C "$MAIN_ROOT" rev-parse --verify "refs/heads/$BRANCH" >/dev/null 2>&1; then
    git -C "$MAIN_ROOT" worktree add "$WORKTREE_PATH" "$BRANCH" >&2
else
    git -C "$MAIN_ROOT" worktree add -b "$BRANCH" "$WORKTREE_PATH" "$BASE_BRANCH" >&2
fi

# Symlink env-ish files from main repo into worktree (root + immediate subdirs).
# Subdirs are common monorepo layouts (e.g. api/.env.development); we only walk
# one level to keep the surface predictable and avoid descending into
# node_modules or other gitignored paths.
shopt -s nullglob dotglob
linked=0

declare -a ENV_RELS=("")  # repo root
for sub in "$MAIN_ROOT"/*/; do
    sub="${sub%/}"
    name="$(basename "$sub")"
    [[ "$name" == "node_modules" ]] && continue
    [[ -d "$WORKTREE_PATH/$name" ]] || continue
    ENV_RELS+=("$name")
done

for rel in "${ENV_RELS[@]}"; do
    src_dir="${rel:+$MAIN_ROOT/$rel}"
    src_dir="${src_dir:-$MAIN_ROOT}"
    dst_dir="${rel:+$WORKTREE_PATH/$rel}"
    dst_dir="${dst_dir:-$WORKTREE_PATH}"
    for src in "$src_dir"/.env "$src_dir"/.env.* "$src_dir"/.exobrain.json; do
        [[ -f "$src" ]] || continue
        name="$(basename "$src")"
        dst="$dst_dir/$name"
        [[ -e "$dst" || -L "$dst" ]] && continue
        ln -s "$src" "$dst"
        echo "  linked ${rel:+$rel/}$name -> $src" >&2
        linked=$(( linked + 1 ))
    done
done

shopt -u nullglob dotglob
[[ "$linked" -eq 0 ]] && echo "  (no env files to link)" >&2

echo "$WORKTREE_PATH"
