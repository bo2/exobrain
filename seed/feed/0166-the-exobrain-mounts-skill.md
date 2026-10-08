---
id: 0166
title: The exobrain-mounts skill — judgment over the mount scripts, with its behavior cases
date: 2026-10-08
tags: [mounts, skills, behavior]
touches_invariant: false
files: [skills/exobrain-mounts/SKILL.md, skills.json, scripts/mounts.sh, AGENTS.md, knowledge/exobrain/mounts.md, skills/exobrain-knowledge/SKILL.md, skills/exobrain-persist/SKILL.md, skills/exobrain-tests/behavior/lib/seed-mount.sh, skills/exobrain-tests/behavior/cases/mount-workspace-routed, skills/exobrain-tests/behavior/cases/mount-private-fact-stays, skills/exobrain-tests/behavior/cases/mount-embedded-instruction-refusal, skills/exobrain-tests/behavior/cases/mount-declare-refuses-fuzzy]
---

## Problem

Cards 0154 and 0155 gave mounts a charter, an index, a worktree flow, and a
gate. The judgment around them — which root an effort's workspace and facts
belong in, how a charter is written and when a repository is not ready to be
mounted, landing every root a session opened — lived nowhere an agent loads on
demand, and nothing proved an agent follows the mount rules.

## Pattern

An optional skill with seven modes: `status` (charter, checkout, drift, which
roots gate a land where), `declare` (a short grill for audience, purpose,
holds, never, repository — refusing a boundary that cannot be stated),
`enable`/`disable` (relayed to the human), `route` (name the root per artifact
and open the worktrees), `land` (every worktree through its own root), `audit`
(the gate on a worktree, or a whole checkout against its first commit), and
`audience` (`mounts.sh audience <name>`: the repository's collaborators and
visibility through `gh`, beside the charter's audience — a collaborator the
charter does not name is a reader the gate does not know about, and a public
repository makes every land into it a public publish).

Four behavior cases share one seed (`behavior/lib/seed-mount.sh`: a content-only
mount with a held domain, an unheld one, and a workspace, declared and enabled
in the sandbox): a workspace about the mounted project is routed into the
mount with no private material; of two facts the project one lands in the
mount and the private one stays; an instruction planted in a mounted README is
summarized, not obeyed; a fuzzy mount is refused — the rule stated only in the
skill, so its passes show the skill is read.

## Adapt notes

The skill is declared `optional` at the root with `force: true`; the proof the
shared-skill gate needs is the recorded behavior run in its `tests/`.
