---
id: 0116
title: A conditional tail is a return value
date: 2026-08-13
tags: [scripts, portability, connector]
touches_invariant: false
files: [scripts/connect-agent.sh, skills/exobrain-tests/unit/test-connect-agent.sh]
---

## Problem

The connector runs each connected scope's own connect hook, and promises that a
hook which fails is reported and the connect carries on — one scope's extra must
not cost the human their wiring. It printed a failing hook's output like this:

```bash
while IFS= read -r line; do
    [[ -n "$line" ]] && echo "      $line"
done <<< "$output"
```

Command output ends in a newline, so the here-string's final line is empty, so the
loop body's last act is a false test. That status is the loop's, then the two
enclosing loops', and finally the function's — and the function is called bare
under `set -e`. A hook that failed *silently* therefore aborted the connect at the
last step: the surface written, `connect continues` printed, no `✓ Connected`, exit
1. Every caller that checks the exit status saw a failed connect.

The guarantee had a test. The test used a fixture whose hook printed to stderr, so
the read loop always ended on a non-empty line and the tail never decided anything.

This is the third appearance of the same shape: a menu loop whose last row was
unchecked aborted first-time setup, and a manifest composer returned 1 whenever the
deepest scope carried no sidecar. The construct reads as a statement and behaves as
a return value.

## Pattern

Under `set -e`, the last command of a function or loop body **is** its exit status.
A trailing `[[ … ]] && …` therefore turns "this line was skipped" into "this
function failed" — silently, and only on the input that skips it.

Write the tail as an `if` block. It costs one line and returns 0 when the test
fails, which is what the code means.

Where the trap is structural — a function whose whole job is a conditional emit —
say so at the definition, so the next edit doesn't reintroduce it.

Test it with the input that exercises the tail. A fixture that always produces
output cannot reach the empty-line path, and a guarantee tested only on its easy
input is untested. Confirm the new case fails against the unfixed code.

## Reference (illustration only)

```bash
while IFS= read -r line; do
    if [[ -n "$line" ]]; then echo "      $line"; fi
done <<< "$output"
```

## Adapt notes

No semantics change beyond the one being restored: a failing scope hook is
reported, never fatal. Worth a sweep rather than a single fix — grep for
`]] &&` and `]] ||` as the final line of a function or loop body, in any script
that runs under `set -e`. The cases that matter are the ones whose test is false
only sometimes.

This class resists a deterministic gate: knowing whether a line is a body's last
statement means parsing the script, not grepping it. It stays a house rule and a
review habit.
