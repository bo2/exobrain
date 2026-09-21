#!/usr/bin/env bash
# Link generated context and skill folders into a worktree without replacing
# files it already owns. Usage: link-worktree-context.sh <main> <worktree>
set -euo pipefail
[[ $# -eq 2 ]] || { echo "Usage: $0 <main> <worktree>" >&2; exit 2; }
MAIN_ROOT="$(cd "$1" && pwd -P)"
WORKTREE_PATH="$(cd "$2" && pwd -P)"
shopt -s nullglob

for src in "$MAIN_ROOT"/.claude/*.md "$MAIN_ROOT"/AGENTS.override.md; do
    [[ -f "$src" ]] || continue
    rel="${src#"$MAIN_ROOT"/}"
    dst="$WORKTREE_PATH/$rel"
    [[ -e "$dst" || -L "$dst" ]] && continue
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "  linked $rel -> $src" >&2
done

# Codex scans a real skills directory with individually linked skill folders.
# Keep in-tree skills on the worktree's branch; fetched skills can use the main
# checkout's cache. Optional external skills need their sibling directory too.
for kind in skills skills-optional; do
    parent="$WORKTREE_PATH/.agents/$kind"
    if [[ -L "$WORKTREE_PATH/.agents" || -L "$parent" ]]; then
        echo "Refusing to write through a symlinked skills parent: $parent" >&2
        exit 1
    fi
    [[ ! -d "$MAIN_ROOT/.agents/$kind" ]] || mkdir -p "$parent"
    for src in "$MAIN_ROOT/.agents/$kind"/*; do
        [[ -f "$src/SKILL.md" ]] || continue
        dst="$parent/$(basename "$src")"
        [[ -e "$dst" || -L "$dst" ]] && continue
        target="$(cd "$src" && pwd -P)"
        case "$target" in
            "$MAIN_ROOT"/*)
                local_target="$WORKTREE_PATH/${target#"$MAIN_ROOT"/}"
                [[ ! -f "$local_target/SKILL.md" ]] || target="$local_target"
                ;;
        esac
        ln -s "$target" "$dst"
        echo "  linked ${dst#"$WORKTREE_PATH"/} -> $target" >&2
    done
done
