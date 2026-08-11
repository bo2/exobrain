---
id: 0107
title: A connect marker must be a path the connector generates, never one a clone ships
date: 2026-08-11
tags: [connect-agent, agents, healthcheck]
touches_invariant: false
files: [scripts/connect-agent.sh, knowledge/exobrain/agents.md, knowledge/exobrain/machinery.md, skills/exobrain-tests/unit/test-connect-agent.sh]
---

## Problem

Each agent gets a **connect marker** — a path meaning *"a human connected this
agent in this checkout."* `--relink` exits early when the marker is missing, and
the post-merge/post-rewrite hooks lean entirely on that guard: they relink all
supported agents unconditionally and expect the unconnected ones to skip.

Claude's marker was the `.claude/` **directory**, tested with `-d`. But that
directory is committed — it carries `settings.json`, un-ignored out of an
otherwise-ignored `.claude/*`. Every clone has it, so the guard always passed:
in a checkout where the human connected only Codex, the first `git pull` fired
the hook and generated a full Claude surface — `CLAUDE.md`, the indexes,
`settings.local.json`, linked skills — for an agent nobody chose.

The session-start healthcheck had already worked around it, testing
`.claude/CLAUDE.md` with a comment naming the trap. Two scripts, two answers to
"is this agent connected", and the connector held the wrong one.

## Pattern

**A marker must be a path that exists only because the connector wrote it.** Test
existence of a *generated, gitignored* artifact, never of a directory or file the
repo ships. A committed path proves the clone happened, not that the human chose
anything — and any check built on one silently answers a different question than
the one asked.

Two corollaries worth holding:

- **One definition, one place.** When a connector and a healthcheck both ask "is
  this agent connected", they test the same paths. A workaround in the second
  reader is a bug report against the first.
- **Prefer the artifact the agent actually needs.** Claude's composed surface is
  written on every connect and relink, so it is both the marker and the thing
  whose absence means "not wired" — no separate sentinel to keep in sync.

## Reference (illustration only)

Point the marker at the generated surface; with every marker now a file, the
directory/file branch disappears from both the guard and the first-run write:

```bash
case "$AGENT" in
    claude)   MARKER="$REPO_DIR/.claude/CLAUDE.md"; TARGET_DIR="$REPO_DIR/.claude" ;;
    codex)    MARKER="$REPO_DIR/.codex";    TARGET_DIR="${CODEX_HOME:-$HOME/.codex}" ;;
    openclaw) MARKER="$REPO_DIR/.openclaw"; TARGET_DIR="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}" ;;
esac

if $RELINK; then [[ -e "$MARKER" ]] || exit 0; fi
```

## Adapt notes

- The regression test needs the fresh-clone shape, not a bare temp repo: create
  the committed file inside the agent's config directory, then assert a `--relink`
  adds nothing to it and installs no hooks. A fixture that never creates that
  file passes against the broken code.
- Pair it with the opposite assertion — a *connected* agent's relink still
  refreshes the surface and the hooks — so the guard can't be tightened into a
  no-op.
- Sweep every doc that prints the marker paths (the supported-agents table, the
  generated-artifacts index, any onboarding skill that tells the user to confirm
  the marker was created). The paths are user-visible, so a stale one sends
  someone looking for a file that no longer means anything.
- No compat shim: a checkout that was genuinely connected already has the
  generated surface, and one that wasn't should stop relinking — which is the fix.
