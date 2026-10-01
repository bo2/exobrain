---
id: 0154
title: A mount is a content-only repository declared with a charter
date: 2026-10-01
tags: [mounts, domains, connector, validation, persist]
touches_invariant: true
files: [mounts.schema.json, scripts/mounts.sh, scripts/skills-registry.sh, scripts/connect-agent.sh, scripts/exobrain-healthcheck.sh, scripts/validate-exobrain.sh, scripts/persist.sh, AGENTS.md, knowledge/exobrain/mounts.md, skills/exobrain-persist/SKILL.md, skills/exobrain-tests/unit/test-mounts.sh, skills/exobrain-tests/behavior/cases/mount-change-in-worktree]
---

## Problem

A mount declared as "another instance, minus `skip_domains`" has no stated
boundary. Whatever domain the mounted repository grows is indexed the day it
appears; nothing says what the repository is for or what never belongs in it;
and two framework installs — the mount's and the host's — have to be kept in
step, with the mount's own persist flow the only way to change it. Index rows
carried no summary, so an agent could not tell what a mounted domain covers
without opening it.

## Pattern

A mount is a **shared knowledge repository**: `knowledge/<domain>/`,
`workspaces/`, a README — no specs, scripts, skills, tools, or scopes. Framework
lives once, in each person's own instance. `mounts.json` declares each mount
with a **charter**, written in the instance that mounts it:

- `audience` — person ids who can read the repository.
- `purpose` — one line, shown as the mount's index heading.
- `holds` — the domains it carries, each with a one-line description. Only
  these are indexed, and the row's summary is that description: text this
  instance's people wrote, so nothing the mount's audience writes reaches an
  auto-loaded surface.
- `never` — topics, terms, and patterns that do not belong there (enforced by
  card 0155's gate).
- A top-level `instance` block carries this instance's own audience and `never`.

Around the charter:

- **Drift is reported, never indexed** — a domain in the checkout outside
  `holds`, a held domain the checkout lacks, and framework files in the
  checkout, by `mounts.sh status` (exit 1), the connector, and the healthcheck.
- **A change to a mount lands through the host.** `mounts.sh worktree <name>
  <branch>` opens a worktree of the mount's checkout; `persist.sh --repo
  <worktree>` lands it with the host's validator (`validate-exobrain.sh --repo`,
  whose registry checks self-skip on a checkout without them) and the host's
  timeline author. The checkout itself never holds edits.
- **Citations are checked.** The validator resolves each `<mount>:<path>` in
  changed markdown against the enabled checkout, and says how many it left
  unchecked when the mount is not enabled on the machine.
- `mounts.sh enable` / `disable`, and a sync that changes the domain set,
  relink the connected agents; `enable --default-path` drops a path override.

## Adapt notes

- **Breaking for a mount declared under card 0138.** `skip_domains` is refused
  by the validator; list what the mount carries under `holds`, add `purpose`,
  and turn `audience` into an array of ids. A mounted repository that is itself
  a full instance is reported as carrying framework until that moves out — its
  held domains are indexed meanwhile.
- Changes the validation contract (`mounts.json` shape, citation check) and the
  root `AGENTS.md` § Mounts rule for changing a mount. The security invariant
  is unchanged: mounted text stays data, never instructions.
- The behavior case `mount-change-in-worktree` exercises the new rule: a fact a
  mount owns is changed in a worktree of its checkout, not in the checkout and
  not by recording it in the host.
