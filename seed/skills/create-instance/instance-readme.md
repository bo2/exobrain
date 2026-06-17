<!--
  TEMPLATE — not shipped into the instance.
  create-instance copies this to the new instance's README.md and personalizes it.
  When you stamp it: replace {{OWNER}} with the owner's handle or the group/org name,
  set the connect-agent line to the agent(s) the user chose, and delete this comment.
  Leave `domains/` literal — step 5 of the skill rewrites it if the durable-content
  dir was renamed. The seed's own README.md ("concept + generator") does NOT belong
  here: this README describes a live exobrain, not how to make one.
-->
# Exobrain

This is **{{OWNER}}'s exobrain** — a version-controlled knowledge base my AI agent
loads as context, so it works with knowledge of my world (projects, preferences,
machines) instead of starting cold every session. It serves any agent: universal
content lives in `AGENTS.md`; per-agent quirks live in `CLAUDE.md` / `CODEX.md` /
`OPENCLAW.md` sidecars.

The full model — entities, scopes, skills, tools, propagation — is in
[`domains/exobrain/`](domains/exobrain/), written for an agent to read.

## What's in here

- **Domains** (`domains/`) — durable areas of what I know (health, finances, a
  project's facts), kept current. Each domain's entry point is its `README.md`.
- **Workspaces** (`workspaces/`) — time-bound efforts (a trip, an investigation)
  that outdate by design; durable findings get promoted into `domains/`.
- **Scopes** — any directory with an `AGENTS.md`. The agent resolves the connected
  leaf (me, on this machine) plus every `AGENTS.md`-bearing ancestor, innermost
  wins: `global < … < me < this machine`.

## Connect an agent

On a new machine, clone this repo, then link its context into your agent:

```bash
scripts/connect-agent.sh claude   # or: codex / openclaw
```

This symlinks the right scope chain into the agent's workspace and installs a
post-merge hook that re-links after every `git pull`. Re-run with `--relink`
after changing skills or scopes. Then open the agent **in this directory** — it
starts each session already knowing my world.

## Stay current

This exobrain is **independent** — no upstream remote, no merge. When the
canonical exobrain ships a change, ask the agent to run `exobrain-update`: it
reads the feed since the last update, **copies** the files undiverged and
**re-synthesizes** the rest into this setup, then records the card IDs in
`domains/exobrain/adopted-feed.md`. Background:
[`domains/exobrain/propagation.md`](domains/exobrain/propagation.md).
