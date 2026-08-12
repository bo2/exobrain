---
id: 0109
title: Anchor git's relative answers to the repo you asked about
date: 2026-08-12
tags: [scripts, git, setup]
touches_invariant: false
files: [scripts/connect-agent.sh]
---

## Problem

`git -C <repo> rev-parse --git-common-dir` answers relative to the repository it
was pointed at — commonly the bare string `.git`. The calling shell has not moved,
so that answer resolves against the *caller's* working directory:

```bash
hooks_dir="$(git -C "$REPO_DIR" rev-parse --git-common-dir)/hooks"   # ".git/hooks"
mkdir -p "$hooks_dir"                                                # …beside the human
```

Run from inside the checkout this is correct, which is how it passes every manual
test. Run from anywhere else — a connector invoked by absolute path, a script
called from a parent directory, a hook firing with a different cwd — it silently
creates a `.git/hooks` directory wherever the human was standing and installs
nothing in the repository. The script still reports each hook installed, because
the writes succeeded; they just landed somewhere else.

In a worktree it fails more loudly and more confusingly: `.git` there is a *file*,
so the write dies with `mkdir: .git: Not a directory`.

The same trap applies to `--git-dir`, `--show-cdup`, and `--show-toplevel` in its
relative forms: `-C` moves git, never the shell.

## Pattern

Treat any path git hands back as repo-relative until proven otherwise, and anchor
it before use:

```bash
common="$(git -C "$REPO_DIR" rev-parse --git-common-dir)"
[[ "$common" == /* ]] || common="$REPO_DIR/$common"
```

Two lines, and the answer is now meaningful from any cwd. Prefer this to `cd`-ing
into the repo, which changes the environment for everything downstream.

## Adapt notes

No invariant. Grep for `rev-parse` across the framework scripts and check each
result that is used as a path — one anchored call site does not fix the others.
The regression test that proves it must run the script from a directory that is
*not* the repo, since running it from inside cannot distinguish the two behaviors.
