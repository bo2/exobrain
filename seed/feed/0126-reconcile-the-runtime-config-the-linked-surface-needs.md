---
id: 0126
title: The connector reconciles the runtime config its linked surface needs
date: 2026-09-07
tags: [connect-agent, openclaw, skills]
touches_invariant: false
files: [scripts/connect-agent.sh, skills/exobrain-tests/unit/test-connect-agent.sh, knowledge/exobrain/agents.md, knowledge/exobrain/machinery.md, OPENCLAW.md]
---

## Problem

The connector links always-tier skills into OpenClaw's workspace skills dir as
symlinks into the exobrain checkout. OpenClaw honors a workspace skill symlink
only when the target's root is listed as trusted in its config. With nothing
listed, `openclaw skills list` loaded none of the linked skills — the connect
reported success, and the agent ran without every skill the exobrain declared
for it. Separately, OpenClaw's own Skill Workshop authors skills into the
workspace beside the exobrain's, a second skill system of record with no review.

## Pattern

**Whatever the runtime must be told for the linked surface to work, the
connector tells it — idempotently, below the sandbox cutoff.** For OpenClaw,
three keys through `openclaw config set`:

- `skills.load.allowSymlinkTargets` gains the real parent dir of every linked
  skill;
- `tools.deny` gains `skill_workshop`;
- `skills.workshop.autonomous.mode` becomes `off`.

Lists are unioned, so entries the human added stay. Nothing is written when the
config already matches — a relink is a no-op. The step sits below the
`--wire-sandbox` cutoff because it writes the runtime's own config, and it
degrades open: a missing CLI is reported and the connect carries on, so a
checkout wires the same with or without the runtime installed.

The sidecar states the policy the config enforces: every skill the agent sees is
an exobrain repo file, changed through the normal review; the runtime's own
skill authoring is off.

## Reference (illustration only)

The unit harness backs every wiring helper with a fake `openclaw` CLI
(`config get <path> --json`, `config set --batch-json <ops>` over a JSON file,
every call logged) and covers four cases: reconcile with kept entries,
idempotent relink, degrade without the CLI, untouched under a sandbox wiring.
`OPENCLAW_BIN` points the connector at the fake.

## Adapt notes

- Verify live after connecting: `openclaw skills list` shows each linked skill
  with a workspace source. A linked skill missing from that list is the trusted-
  roots key; an agent that leaves a skill unfixed as "not managed by Skill
  Workshop" is the policy working as intended — edit the repo file.
- Another runtime with an equivalent trust or authoring setting gets the same
  shape: one function per runtime, union semantics, no write when matching,
  degrade open, a fake CLI in the unit suite.
