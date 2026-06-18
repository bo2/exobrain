---
id: 0032
title: Link an agent's skills repo-locally when it scans a project-local skills dir
date: 2026-06-18
tags: [connect-agent, skills, agents]
touches_invariant: false
files: [scripts/connect-agent.sh]
---

## Problem

Linking framework skills into an agent's global, per-user config dir (e.g. `~/.<agent>/skills`) makes them surface in *every* project that agent opens, not just the repo that owns them. One repo's skills crowd the global namespace, and there's no way to scope them to where they're relevant.

## Pattern

When an agent scans a **project-local** skills directory (walking from the working dir up to the repo root), link its skills there instead of the global config dir. The framework's skills then exist only while the agent runs inside that repo — the same project-rooted behavior an in-repo skills dir already gives other agents. Split the skills-link target from the rest of the agent surface: most agents keep `skills` under their context dir, the project-local scanner gets a repo-local dir.

## Reference (illustration only)

```sh
case "$AGENT" in
  scans_repo_local) SKILLS_DIR="$REPO/.agents/skills" ;;   # repo-local linker output
  *)                SKILLS_DIR="$TARGET_DIR/skills" ;;
esac
mkdir -p "$TARGET_DIR" "$SKILLS_DIR"     # the skills parent must be a REAL dir, not a symlink
# link each resolved skill as a child of $SKILLS_DIR; derive the optional dir as its sibling
# legacy: remove old skill symlinks the agent left under its global ~/.<agent>/skills
```

## Adapt notes

Two gotchas: (1) some agents won't follow a *symlinked parent* skills dir — make the parent a real directory and symlink the individual skills inside it; **verify discovery on the target agent's version before relying on it.** (2) Repo-local scoping means skills are found only when the agent launches inside the repo tree — the intended trade for not polluting the global namespace, but flag it for skills meant to be used while working in sibling repos. Gitignore the repo-local skills dir, and migrate seamlessly: on relink, delete the old global symlinks (only those pointing back into this repo). *This card was adopted on a sibling instance's verification; the seed instance connects only one agent backend, so the repo-local path here is unverified locally — confirm against the live agent before depending on it.*
