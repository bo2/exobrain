---
id: 0136
title: A worktree links its own branch's skills, and the Codex connector leaves the home dir alone
date: 2026-09-21
tags: [connector, worktrees, codex, skills]
touches_invariant: false
files: [scripts/link-worktree-context.sh, scripts/create-worktree.sh, scripts/connect-agent.sh, scripts/exobrain-healthcheck.sh, scripts/skills-registry.sh, knowledge/exobrain/agents.md, skills/exobrain-tests/unit/test-connect-agent.sh]
---

## Problem

Four faults around Codex and worktrees: a new worktree inherited the generated
markdown but no skill directory, so skill discovery there found nothing; wiring
Codex inside a worktree wrote *through* the inherited `AGENTS.override.md` symlink
into the main checkout; the connector created the Codex home dir and deleted
`AGENTS.*.md` symlinks in it — a person's own files — though its whole surface
is repo-local; and a skill whose `description:` is a YAML block scalar rendered
as `>` in the optional-skills index.

## Pattern

- `link-worktree-context.sh <main> <worktree>`, called by `create-worktree.sh`
  and re-runnable to repair an existing worktree: links generated markdown, and
  builds a *real* skills directory of individual links. An in-tree skill resolves
  to the worktree's own copy, so a branch's skill edit is what loads there.
  Existing files are never replaced; a symlinked skills parent is refused.
- The override is composed to a temp file and moved into place, replacing an
  inherited symlink instead of following it.
- The Codex connector neither creates nor cleans the Codex home.
- The healthcheck checks Codex's override and always-tier skills in the *active*
  checkout; markers and trunk freshness still come from the main one.
- `skills_extract_description` folds `>` / `|` block scalars to one line.
