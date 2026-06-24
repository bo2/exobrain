---
id: 0061
title: Keep framework shell scripts portable to macOS's stock bash 3.2
date: 2026-06-23
tags: [scripts, portability, bash]
touches_invariant: false
files: [scripts/authoring-review.sh]
---

## Problem

Framework scripts ship into every instance and run under whatever `bash`
`#!/usr/bin/env bash` resolves to. On macOS the **stock** interpreter at
`/bin/bash` is still 3.2 — and it's first on `PATH` whenever a newer Homebrew
bash isn't (a bare `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, a login shell without
Homebrew, a cron/CI context). A script that only ran under bash 5 then crashes
in the field. Worse, bash parses a script lazily, so an early failure masks the
next one: you fix the crash you see and the script dies a few lines later for an
unrelated 3.2 reason.

## Pattern

Three bash-3.2 incompatibilities recur in framework scripts; avoid all three,
and test under `/bin/bash`, not just the version on your `PATH`:

1. **`mapfile` / `readarray` are bash 4 builtins** — absent in 3.2
   (`command not found`). Read lines with a plain `while IFS= read -r` loop,
   redirected from the producer with process substitution.
2. **Expanding an empty array under `set -u` errors in 3.2** (fixed in 4.4):
   `"${arr[@]}"` on an empty `arr` aborts with `unbound variable`. Either read
   straight into the consuming loop instead of through an intermediate array, or
   guard the expansion with a `[[ ${#arr[@]} -gt 0 ]]` length check.
3. **A heredoc nested inside `$(...)` breaks 3.2's command-substitution parser**
   when the body contains an odd number of single quotes (apostrophes in prose —
   "don't", "repo's"). The 3.2 `$()` scanner miscounts them and aborts at EOF.
   Move the heredoc into a function and capture a plain `$(emit_fn)`; a bare
   heredoc parses fine.

## Reference (illustration only)

```bash
# (1)+(2): read straight into the loop — no bash-4 mapfile, no empty array
files=()
while IFS= read -r f; do
    case "$f" in domains/*.md) files+=("$f") ;; esac
done < <(git diff --name-only "$BASE...HEAD" -- '*.md')

# (2): append an optional array only when non-empty
run_engine() {
    local -a cmd=("${NOPROXY[@]}")
    [[ ${#TIMEOUT[@]} -gt 0 ]] && cmd+=("${TIMEOUT[@]}")
    cmd+=("$@"); printf '%s' "$PROMPT" | "${cmd[@]}"
}

# (3): heredoc in a function, not directly inside $()
emit_rubric() {
    cat <<'RUBRIC_EOF'
... prose with apostrophes is safe here ...
RUBRIC_EOF
}
PROMPT="$(emit_rubric)"
```

## Adapt notes

Pattern, not a patch — an instance that restructured the script re-synthesizes
these idioms into its own shape; one that didn't can copy the reference. The
durable test is the symptom: run the script under `/bin/bash` on macOS (and with
a minimal `PATH` that excludes Homebrew and any `timeout`/`gtimeout`) and confirm
it degrades cleanly instead of crashing. No invariant; purely robustness.
