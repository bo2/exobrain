---
id: 0108
title: A loop that closes a function hands back its last test's status
date: 2026-08-12
tags: [scripts, bash, setup]
touches_invariant: false
files: [scripts/connect-agent.sh]
---

## Problem

Under `set -e` a shell function aborts its caller when it returns non-zero, and
the return value of a function is the status of its last command. A `for` loop
takes the status of its final iteration — so this innocuous idiom is a landmine
whenever it closes a function's body:

```bash
for i in "${items[@]}"; do [[ "${checked[$i]}" == 1 ]] && picked+=("$i"); done
```

When the last item fails the test, the `&&` list is false, the loop is false, and
the function returns 1. Nothing failed; the loop did exactly what it was asked.

The bug this produced in an interactive setup flow was invisible in review and
brutal in the field: the connector died the instant the human accepted a checkbox
menu — after every prompt was answered, and before the step that saved the
configuration — so a first-time setup left no state behind and no clue why. It
fired only when the menu's *last* row happened to be unchecked, so the person who
wrote it never saw it.

The general shape: a data-dependent exit status, from a construct nobody reads as
a test, at a position where the status is load-bearing.

## Pattern

Never end a function on a bare `[[ … ]] && …` inside a loop. Write the condition
as an `if` block, whose status is 0 when the branch isn't taken:

```bash
for i in "${items[@]}"; do
    if [[ "${checked[$i]}" == 1 ]]; then picked+=("$i"); fi
done
```

The same applies to a pipeline built from a read loop, which ends non-zero at EOF:
close the group with an explicit `true` when its status is consumed.

`set -e` exempts a failing command that is the left operand of `&&`, which is what
makes this survive review — the exemption applies to the command, not to the
enclosing loop or function whose status it becomes.

Reach for the pattern by position, not by cleverness: a construct one line from a
function's closing brace deserves a look at what status it yields.

## Adapt notes

Purely defensive; no invariant. Audit the tail of every function in a script that
runs under `set -e`, not only the one that broke. The durable test is behavioral —
drive the interactive path (see the companion card on pty-driven prompt tests) with
the *last* option unselected, which is the case a hand-run demo never covers.
