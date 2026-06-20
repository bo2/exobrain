---
id: 0002
title: Disable the agent's native memory; exobrain context is the only memory
date: 2026-06-07
tags: [connect-agent, claude, codex, agents]
touches_invariant: false
files: [scripts/connect-agent.sh]
---

## Problem

AI agents ship their own auto-memory: Claude Code accumulates project memory, and
Codex injects past "memories" into new sessions. An exobrain already provides
context through versioned `AGENTS.md` / scope specs. Running both means two memory
layers that drift apart — the agent "remembers" things that contradict, or aren't
in, the repo you can actually review and edit.

## Pattern

When `connect-agent` wires an agent, also turn off that agent's native memory, so
the exobrain is the single source of context:

- **Claude Code** — set `"autoMemoryEnabled": false` in `.claude/settings.local.json`
  (gitignored, per-machine; merge so other keys survive).
- **Codex** — set `use_memories = false` under a `[memories]` table in the
  user-level `~/.codex/config.toml` (idempotent: skip if already set; don't append
  a second `[memories]` table).

Do it on every connect/relink so it stays in force.

## Reference (illustration only)

```sh
# claude branch
settings="$TARGET_DIR/settings.local.json"
if [ -f "$settings" ]; then jq '.autoMemoryEnabled=false' "$settings" > t && mv t "$settings"
else echo '{"autoMemoryEnabled":false}' | jq . > "$settings"; fi

# codex branch (TARGET_DIR = ~/.codex)
cfg="$TARGET_DIR/config.toml"
grep -q use_memories "$cfg" 2>/dev/null || \
  printf '\n[memories]\nuse_memories = false\n' >> "$cfg"
```

## Adapt notes

Put the setting wherever the agent actually reads it on your platform, and keep
the write idempotent (re-running relink must not duplicate or clobber). If your
instance renamed scopes or config dirs, adjust the paths. No invariant is touched —
this only changes which memory layer is authoritative (now: the exobrain).
