---
id: 0060
title: "Behavioral-suite checks: prune by basename and scope to agent-changed files"
date: 2026-06-23
tags: [tests]
touches_invariant: false
files:
  - skills/exobrain-tests/scripts/lib/check-helpers.sh
  - skills/exobrain-tests/scripts/cases/route-fact-to-domain/check.sh
  - skills/exobrain-tests/scripts/run.sh
---

## Problem

The behavioral suite runs an agent against a throwaway copy of the instance, then a
per-case `check.sh` inspects what the agent did — locating output across the main
instance and any sibling worktrees the agent created. Three latent defects made the
checks lie about what they found. None are instance-specific; each bites a whole class
of instance.

1. **Path-substring prune drops the whole tree under a `src` checkout.** The `find`
   helper pruned git internals, the seed cache, and the shipped harness with absolute
   `-not -path '*/src/*'` filters. `-path` matches the *full* path, so on any instance
   whose run directory itself lives under a `src` component (e.g. a checkout at
   `~/src/exobrain`), every result matches the `*/src/*` prune and the entire tree is
   dropped — `find` returns nothing and the check spuriously reports "not found."

2. **Blanket content grep false-matches pre-existing prose.** A case that asked "where
   did this fact land?" grepped *all* instance content for its match terms. On a
   content-rich instance, those terms already appear in unrelated docs — a domain that
   says "type fidelity," an unrelated "brokerage" — so the check matched prose the agent
   never touched and passed (or failed) for the wrong reason. It also reused the same
   broken absolute `grep -v '/src/'` filter.

3. **Change-scoped checks need a stable base ref.** The natural fix for (2) — diff what
   the agent changed — breaks if you diff against `trunk`: the agent may commit or
   squash-merge its change onto trunk, advancing trunk to *include* the change, so the
   diff comes back empty. There's nothing to diff against unless the harness pins the
   pre-agent HEAD.

## Pattern

**Prune by directory basename, not by absolute-path substring.** A find that walks an
agent's output tree should prune unwanted directories with `-name <dir> -prune`, which
fires only on those names met *while descending*, never on an ancestor the run dir
happens to sit under. The grep equivalent already does this with `--exclude-dir` (a
basename match) — make `find` agree. Absolute `-path '*/x/*'` / `grep -v '/x/'` filters
are a latent trap: they couple the check's correctness to where the instance is checked
out.

**Scope a "what did the agent do?" check to the files the agent actually changed**, not
to all instance content. Add a helper that lists the agent's added/modified files across
the main instance and its worktrees, and grep only those. This is the only reliable way
to assert *agent behavior* on a content-rich instance whose own docs contain the check's
match terms.

**For any change-scoped check, the harness must pin a stable base ref** (post-setup,
pre-agent HEAD) — a tag the check diffs against — so the agent's own changes are
recoverable no matter where it lands them: a worktree branch, or committed/squash-merged
onto trunk. Pinning a ref also survives the agent moving trunk; diffing trunk directly
does not.

## Reference (illustration only)

Basename prune in the find helper:

```sh
find "$rundir"/instance* \
    \( -name .git -o -name src -o -name exobrain-tests \) -prune -o \
    \( "$@" -print \) 2>/dev/null
```

A "files the agent changed" helper (tracked diff vs the pinned base ∪ untracked new
files, across instance + worktrees):

```sh
base=exobrain-base
git -C "$d" rev-parse -q --verify "$base" >/dev/null 2>&1 || base=trunk
{ git -C "$d" diff --name-only "$base"
  git -C "$d" ls-files --others --exclude-standard
} | sed "s#^#$d/#"
```

The harness pins the ref immediately before invoking the agent:

```sh
git -C "$inst" tag -f exobrain-base HEAD >/dev/null 2>&1 || true
```

## Adapt notes

- Audit your whole suite for absolute `'*/src/*'` / `grep -v '/src/'` (or any
  `-path '*/<dir>/*'`) prunes and convert each to a basename match — the bug is dormant
  until someone checks out under a matching path component. A parallel test suite (e.g.
  a seed-build suite) may *reuse* the same `check-helpers.sh` rather than copy it; fixing
  the one source of truth covers both, but confirm there's no second copy.
- The base-ref name is a contract between the harness (which pins it) and the checks
  (which diff it). Keep the fallback to `trunk` for runs that predate the pin, but the
  pin is what makes change-scoped checks correct — add it before adding any check that
  relies on it.
- If your suite tests the working tree instead of committed history, the change-scoping
  still helps, but the stable-base-ref requirement only bites once an agent commits its
  output; pin the ref anyway so the check is robust to either landing style.
