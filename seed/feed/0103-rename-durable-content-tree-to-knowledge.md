---
id: 0103
title: Rename the durable-content tree from domains/ to knowledge/
date: 2026-07-31
tags: [conventions, scripts, propagation]
touches_invariant: false
files: [AGENTS.md, README.md, scripts/connect-agent.sh, scripts/skills-registry.sh, scripts/validate-exobrain.sh, scripts/exobrain-healthcheck.sh, scripts/authoring-review.sh, scripts/scheduler.py, .gitleaks.toml, skills/exobrain-knowledge/SKILL.md]
---

## Problem

The durable-content tree was named `domains/` — after the entity it holds, not
the content. The name needed the spec to explain it, where its sibling
`workspaces/` reads at a glance.

The framework now fixes the name as `knowledge/` (card 0095), and every
consumer hardcodes the path: the connector's index glob, the registry's domain
resolver, the validator's content-tree and compat-ledger checks, the
healthcheck's ledger path, the authoring filter and rubric, the scheduler's
skip list, the secret-scanner allowlist, the test fixtures. An instance that
stays on the old name can no longer take any of those files by copy, and every
future card touching them costs a re-synthesis — a permanent divergence tax on
a name that carries no instance content.

## Pattern

Name a content tree after what it holds — `knowledge/` reads as "what you
know" at a glance — and treat the rename as a **strict migration**: move the
tree and every consumer that resolves it in one change, then grep for the old
name. A consumer left behind fails silently (an empty index, a check that
walks a tree that isn't there), not loudly.

The move, in full:

- the tree itself: `domains/` → `knowledge/`; the meta-domain becomes
  `knowledge/exobrain/`;
- every path reference in the root specs, README, and sidecars;
- the connector's domains-index glob, and the generated index it writes —
  renamed `domains-index.md` → `knowledge-index.md`, which is itself a state
  migration on every connected machine (card 0096);
- the registry's domain resolver;
- the validator's content-tree and compat-ledger checks;
- the healthcheck's ledger path;
- the authoring gate's in-scope filter and rubric paths;
- the scheduler's skip list, the secret-scanner allowlist, the unit and
  behavioral test fixtures;
- the domain skill: `exobrain-domains` → `exobrain-knowledge`; the rename
  inherits the old name's standing through the shared-skill proof gate
  (card 0094).

The vocabulary is unchanged: a durable knowledge area is still a **domain**,
its entry point is still its `README.md`, and the entity doc keeps its name
(`knowledge/exobrain/domains.md` in the seed's layout).

## Adapt notes

- Historical cards keep their `domains/` paths — they record what shipped on
  their date. Apply them into `knowledge/` from here on.
- The validation contract is preserved, not touched: the content-tree check
  walks the renamed tree with the same guarantees. Don't drop the check while
  moving it.
- After the move, `grep -r domains/` (excluding historical feed cards) is the
  completeness test — zero hits outside the entity vocabulary means every
  consumer moved.
