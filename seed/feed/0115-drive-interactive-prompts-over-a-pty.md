---
id: 0115
title: An interactive prompt is untested code — drive it over a pty
date: 2026-08-12
tags: [testing, scripts, setup]
touches_invariant: false
files: [skills/exobrain-tests/unit/test-connect-agent.sh]
---

## Problem

The interactive setup path is the first code a new instance runs and the least
tested code in the framework. It stays untested for a structural reason, not a
lazy one: a prompt reads `/dev/tty` and gates itself on `[[ -t 0 && -t 1 ]]`, so
piping stdin does not reach it. A test suite with no terminal cannot get in at all,
and the path is exercised only by hand, only by someone who already knows the
answers, and only along the route they happen to take.

What hides there is exactly what hand-running misses: a defect that depends on
which option is last, or on an id that collides with something already present.

## Pattern

Give the suite a terminal. A short pty driver forks the script under a pseudo-
terminal and feeds one answer each time the process falls quiet — no fixed sleeps,
no prompt-string matching, so it survives rewording of the prompts:

```python
import os, pty, select, sys, time
answers = os.environ["ANSWERS"].split("|")
pid, fd = pty.fork()
if pid == 0:
    os.execv(sys.argv[1], sys.argv[1:])
out, i, deadline = b"", 0, time.time() + 30
while time.time() < deadline:
    ready, _, _ = select.select([fd], [], [], 0.4)
    if ready:
        chunk = os.read(fd, 4096)          # OSError/empty ⇒ the child exited
        if not chunk: break
        out += chunk
    elif i < len(answers):                 # quiet ⇒ it is waiting on a prompt
        os.write(fd, (answers[i] + "\n").encode()); i += 1
    else:
        break
sys.stdout.write(out.decode(errors="replace").replace("\r\n", "\n"))
```

The transcript it returns is the assertion surface: what the flow *said* (a warning
shown, a default withheld) as well as what it wrote.

Two things make it safe to keep in a fast suite: **self-skip** when the interpreter
that supplies the pty is absent, so the suite still runs on its base dependencies;
and point every home/config override at the temp dir, since driving the real flow
means running its real writes.

## Adapt notes

No invariant — test infrastructure only. Once the harness exists, add a case for
the *awkward* path rather than the happy one: the last option unselected, a name
that collides, an empty answer. Those are the cases the interactive flow's author
never types.

Answer scripts are coupled to the prompt sequence: adding a confirmation step
shifts every later answer, and a stale script fails in a way that reads like a
product bug. Comment each answer with what it responds to.
