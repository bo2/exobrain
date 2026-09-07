---
id: 0122
title: A chat-turn persist commits, replies, and detaches the land
date: 2026-09-07
tags: [openclaw, persist, git-workflow, sidecars]
touches_invariant: false
files: [OPENCLAW.md, skills/exobrain-persist/SKILL.md, scripts/persist.sh]
---

## Problem

A land spends a minute or two on git and forge round-trips. A chat runtime that
runs it inline holds the session lane for that long: the person's next message
queues behind a push, a PR, and a pull, and a land that fails leaves the person
waiting on an error they did not ask about. Skipping the land instead leaves
work committed on a branch nobody remembers to merge.

## Pattern

Under a chat runtime, a persist is three moves and an exit:

1. Make the change in a worktree and **commit it**. The commit is the durable
   point — "saved" means committed on the branch, not merged. Anything the same
   turn reads back reads the worktree file; later turns read the default branch
   once the land completes.
2. **Reply** to the person.
3. **Start the land detached** — the runtime's background-process primitive,
   running the land script from inside the worktree — and end the turn without
   polling it.

The process exit wakes the session. Exit 0: nothing to say. Non-zero: tell the
requester the change is committed on its branch but not yet landed, and what
failed. The safety net is the sweep: the land claims the worktree before it does
anything else, so a run the runtime killed is picked up by the scheduled sweep
on its next pass — a transient failure needs no action from anyone.

A scheduled (cron) session has no one waiting and runs the land in the
foreground.

The wiring belongs in the runtime's root sidecar, since it names that runtime's
primitives; the skill only points at it.

## Reference (illustration only)

```markdown
## Persisting from a chat turn

1. Commit in the worktree.
2. Reply.
3. Start `scripts/persist.sh` detached from inside the worktree (`-m` when the
   work is still uncommitted) and end the turn. Don't poll for it.
4. On a non-zero exit, say the change is committed but not landed and what
   failed; the scheduled sweep retries a claimed worktree.
```

## Adapt notes

Requires the one-command land (card 0121) — the claim marker and `--sweep` are
what make detaching safe. Name the runtime's actual background primitive in
the sidecar. Agent runtimes that already run turns asynchronously, or that
have no session lane to hold, need only the sweep.
