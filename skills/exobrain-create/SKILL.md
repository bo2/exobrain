---
name: exobrain-create
description: >
  Scaffold a new exobrain instance for the user from the canonical concept. Use
  when the user wants to set up, create, bootstrap, or initialize their own
  exobrain — a personal knowledge base their AI agent loads as context — or when
  they paste the bootstrap prompt from github.com/bo2/exobrain. Interviews the
  user, then generates a working repo (scopes, framework scripts, seed domains)
  adapted to their answers.
---

# exobrain-create

You are scaffolding a **new exobrain** for the user, in the directory they're
working in. An exobrain is a version-controlled knowledge base their AI agent
loads as context; the full model is in this repo's `domains/exobrain/`. Read
that first if you haven't — especially `entities.md`, `scopes.md`, and
`propagation.md` — so you can explain choices and adapt the structure sensibly.

This file is a procedure. Follow it top to bottom. Explain each step before doing
anything the user would want to approve; don't assume their setup — detect it.

## 0. Get the framework

You need the seed's files to copy from — and the new instance keeps them as its
update-cache, so don't throw the clone away. First confirm where the new exobrain
should live (call it `$DST`) — default to the current directory; make sure it's
empty (or get the user's OK to add to it).

Put the seed at `$DST/src/exobrain-seed/` (gitignored — local cache, never
committed) and call that path `$SRC`:

- Reached this file by cloning `https://github.com/bo2/exobrain` already? Move or
  copy that clone into `$DST/src/exobrain-seed/`.
- Otherwise `git clone https://github.com/bo2/exobrain $DST/src/exobrain-seed`.
- Can't clone at all? Read the raw files from GitHub as needed; the instance starts
  without a cache and `exobrain-update` clones one on its first run.

`exobrain-update` later reuses or refreshes this same cache (see `propagation.md`).

## 1. Interview

Keep it short — 3–5 questions. Adapt; don't read them robotically.

- **Purpose / who shares it.** Just you? You + family/household? A team/org?
  This sets the scope shape:
  - solo → a `people/<you>/` person scope + a `hosts/<machine>/` host scope under it.
  - family → a `groups/<household>/` scope containing `people/<each>/`.
  - team/org → `groups/<org>/` (or `teams/<team>/`) containing people; nest as deep as needed.
- **Your handle and this machine's name** (for the person and host scopes).
- **Vocabulary.** The durable-content directory is `domains/` by default.
  Offer alternatives if they'd prefer (`knowledge/`, `memory/`, `areas/`, …). Most should keep `domains/`.
- **A domain or two to start** (e.g. `finances`, `home`, a project). Optional — they can add later.
- **Which agent(s)** they'll connect (claude / codex / openclaw).

## 2. Scaffold the structure

Create under `$DST`:

- `AGENTS.md` — copy `$SRC/AGENTS.md`. It's the auto-loaded spec and is already
  generic. If the user renamed the durable-content dir, update the few references to
  `domains/` in it (see step 5).
- `README.md` — stamp `$SRC/skills/exobrain-create/instance-readme.md` (a template,
  not the seed's own `README.md`, which is the "concept + generator" pitch and is
  wrong for an instance). Replace `{{OWNER}}` with the user's handle or the
  group/org name, set the `connect-agent.sh` line to the agent(s) they chose, and
  delete the leading template comment.
- Per-agent root sidecar — copy `$SRC/CLAUDE.md` (and/or `CODEX.md`/`OPENCLAW.md`)
  for the agents they chose.
- `scopes.json` — copy `$SRC/scopes.json` (declares collection→type labels).
- `tools/` — copy `$SRC/tools/` (the catalog `README.md` + the `example-tool.md` template).
- `skills.schema.json` — copy `$SRC/skills.schema.json`.
- `skills.json` — start minimal, registering the copied skills: `{ "$schema": "./skills.schema.json", "skills": [ { "name": "exobrain-reader-lens", "scope": "global", "owner": "", "tier": "optional" }, { "name": "exobrain-update", "scope": "global", "owner": "", "tier": "optional" }, { "name": "exobrain-persist", "scope": "global", "owner": "", "tier": "optional" } ] }`.
- `.gitignore`, `.env.example` — copy from `$SRC`.
- `scripts/` — copy the whole `$SRC/scripts/` directory. These are the framework
  (`connect-agent.sh`, `skills-registry.sh`, `validate-exobrain.sh`,
  `skills-validate.sh`, `skills-status.sh`, `skills-promote.sh`, …). `chmod +x scripts/*.sh`.
- `skills/exobrain-reader-lens/`, `skills/exobrain-update/`, and
  `skills/exobrain-persist/` — copy all three from `$SRC`. `exobrain-update` is how
  the instance pulls future changes, so it ships *in* the instance. Leave
  `exobrain-create` behind — it's a one-shot generator that lives only in the
  canonical repo.

## 3. Copy the concept (the meta-domain)

Copy `$SRC/domains/exobrain/` into `$DST/<domains-dir>/exobrain/` — entities,
scopes, agents, skills, tools, authoring, propagation, and `feed/`. This is what
makes the new exobrain self-documenting. Then create `<domains-dir>/exobrain/adopted-feed.md`
as the provenance ledger: a header that records the **seed repository URL** this
instance updates from (the address `exobrain-update` pulls `src/exobrain-seed/`
from — `https://github.com/bo2/exobrain`, or the intermediate seed you built from),
plus **one row per feed card currently in `$SRC/domains/exobrain/feed/`**, each
marked adopted today ("built in at creation"). The instance starts current, so
`exobrain-update` only ever processes cards published *after* this point (see
`propagation.md`).

Do **not** copy `adopted-feed.md` from `$SRC` (the canonical repo has none — it
publishes the feed, it doesn't adopt).

## 4. Seed scopes and content

- Create the chosen scope dirs, each with an `AGENTS.md` (the scope flag):
  - person: `people/<handle>/AGENTS.md` — a short personal-preferences stub.
  - host: `people/<handle>/hosts/<machine>/AGENTS.md` — a machine-config stub.
  - (family/org) the group/team scope's `AGENTS.md` too.
- For each starting domain: `<domains-dir>/<area>/README.md` with a
  one-line orientation (see `<domains-dir>/exobrain/authoring.md`).
- `workspaces/README.md` — copy from `$SRC`.
- Write `.exobrain.json` (gitignored) with the connected leaf and chosen agent(s):
  `{ "connected": ["people/<handle>/hosts/<machine>"], "agents": [] }`.

## 5. If the user renamed the durable-content dir

`domains/` appears in a few places that must move together — otherwise
validation and the docs drift:

- The directory itself and everything under it.
- `AGENTS.md` and `README.md` references to `domains/`.
- `scripts/validate-exobrain.sh` — the content-tree check forbids `AGENTS.md`
  under `domains/` and `workspaces/`; update those two names to match.
- Cross-references inside the meta-domain files.

Grep the tree for the old name and update every hit. This is the kind of
"adapt, don't merge" work the propagation model expects of you.

## 6. Initialize and verify

```bash
cd "$DST"
git init -q
chmod +x scripts/*.sh
scripts/validate-exobrain.sh          # must be clean
scripts/connect-agent.sh <agent>      # links scopes into the agent's surface, installs hooks
scripts/skills-status.sh              # sanity-check the registry
```

`connect-agent.sh` reads the `.exobrain.json` you wrote, so it links the chosen
scope chain without re-prompting. If validation fails, fix it before handing off.

## 7. Hand off

Tell the user, briefly:
- Where their exobrain is and how it's structured (one line per top-level dir).
- To open their agent **in that directory** to start using it.
- To fill in `people/<handle>/AGENTS.md` (their preferences) and replace the
  example domain with real ones, then commit (and push, if they want a remote).
- That they can pull future updates anytime with `exobrain-update` (no forking;
  their repo stays their own).

## Notes

- **Reuse, don't reinvent.** Everything except the seed content is a copy of
  `$SRC`. The value you add is the interview, the scope shape, and any vocabulary
  adaptation — not rewriting the framework.
- **Don't over-scaffold.** A solo user needs `domains/`, `workspaces/`,
  `people/<you>/hosts/<machine>/`, and the framework. Skip groups/teams unless
  they're sharing.
- **Keep secrets out.** Never write real credentials anywhere; `.env` is
  gitignored and `.env.example` only shows variable names.
