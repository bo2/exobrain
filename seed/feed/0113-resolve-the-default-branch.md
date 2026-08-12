---
id: 0113
title: Resolve the default branch; never hardcode main
date: 2026-08-12
tags: [scripts, git, validation]
touches_invariant: false
files: [scripts/authoring-review.sh]
---

## Problem

Any gate that reviews "what changed" needs a base ref, and `origin/main` is the
easy default. It is also wrong for every instance whose trunk carries another
name — and a diff against a ref that does not exist doesn't fail loudly, it
produces an empty or misleading range.

That is worst in a gate designed to **degrade open** — one that exits 0 when its
engine is missing so a flaky checker never blocks a push. A bad base ref there is
indistinguishable from a clean review: the gate reports nothing, and reports it
confidently, on every run forever.

The failure is also invisible in the repository that wrote the script, whose
default branch is of course `main`.

## Pattern

Ask git, then fall back:

```bash
BASE="$(git -C "$REPO_DIR" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
if [[ -z "$BASE" ]]; then
    for cand in origin/main origin/trunk origin/master; do
        git -C "$REPO_DIR" rev-parse --verify --quiet "$cand" >/dev/null 2>&1 && { BASE="$cand"; break; }
    done
fi
```

More useful than the snippet: when several scripts in a framework need the same
derived value, they must agree. Resolve it once, the same way everywhere, and treat
a script that hardcodes what its siblings compute as a defect — the inconsistency
is the bug, discovered later and further from its cause than a wrong constant.

## Adapt notes

No invariant. Audit every script that diffs against a base, not just the one that
prompted the change; grep for the branch name as a literal. An instance with no
remote at all keeps whatever local fallback it already used — the resolution order
above degrades to it.
