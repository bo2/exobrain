---
id: 0088
title: Block machine-specific absolute paths outside host scope at the push
date: 2026-07-28
tags: [validation, portability, scopes]
touches_invariant: false
files: [scripts/validate-exobrain.sh]
---

## Problem

Files at global, group, and person scope are shared across machines; only host scope is
allowed to name one machine's layout. The rule was written down but nothing enforced it,
so an absolute home path — a checkout location baked into a script, a data file
referenced by its full path in a doc — lands in a shared file and works fine for its
author and for nobody else. It surfaces later as a broken script on someone else's
machine, far from the change that caused it.

## Pattern

Add a **diff-scoped** deterministic check to the push-time validator: in files changed
against the default branch, flag absolute paths under a user's home directory
(`/Users/<someone>/`, `/home/<someone>/`) unless the file sits in host scope.

Diff-scoping is what makes this adoptable on a tree that already has such paths — they
are grandfathered, and only newly introduced ones block. It also keeps the check honest
about what it is: a push gate that stops the *next* violation, not a migration.

Three exemptions keep it free of false positives:

- **Host scope** — the one place these paths belong.
- **`_raw/`** — source captures keep their original form.
- **Any directory holding a `Dockerfile`** — a path inside a container image is fixed
  by the image, not by the machine, so it is portable by construction. This is the
  exemption that a naive version gets wrong, and containerized test harnesses are
  exactly where such paths legitimately cluster.

Placeholder forms (`/Users/<name>/`) don't match, since `<` isn't a path character —
docs can still show the shape of a path without tripping the gate.

## Reference (illustration only)

```bash
while IFS= read -r f; do
    case "$f" in hosts/*|*/hosts/*|*/_raw/*|tmp/*) continue ;; esac
    [[ -f "$REPO_DIR/$(dirname "$f")/Dockerfile" ]] && continue
    grep -InE '/(Users|home)/[A-Za-z0-9._-]+/' "$REPO_DIR/$f" | head -5 | ...
done < <(git -C "$REPO_DIR" diff --name-only "$default_ref...HEAD")
```

## Adapt notes

- Needs a default ref to diff against; skip the check when none resolves (fresh clone,
  no remote) rather than scanning the whole tree.
- Use `grep -I` so a binary file never produces a garbled violation line.
- If your validator already resolves the remote default branch for its outgoing-history
  checks, reuse that ref instead of resolving it again.
