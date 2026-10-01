---
id: 0155
title: Every land between an instance and its mounts passes an isolation gate
date: 2026-10-01
tags: [mounts, security, validation, persist, authoring-review]
touches_invariant: true
files: [scripts/mount-isolation.py, scripts/persist.sh, scripts/authoring-review.sh, knowledge/exobrain/mounts.md, knowledge/exobrain/machinery.md, skills/exobrain-tests/unit/test-mounts.sh, skills/exobrain-tests/unit/test-authoring-review.sh]
---

## Problem

An instance and a mount have different audiences, and the same agent session
writes to both. A written rule — "record a fact in a mount only when its whole
audience may read it" — is all that keeps a private fact out of a shared
repository, and a private mount's facts out of the instance. Nothing checks it,
and a merged leak cannot be withdrawn from clones already made.

## Pattern

Derive which lands are gated from the charters' audiences (card 0154), then
gate them in two layers.

**Direction.** A mount whose audience is strictly narrower than the instance's
is the private party: every land into the instance is gated against it. Any
other mount is the shared party: every land into it is gated against the
instance, and against every other mount whose audience does not include all of
its own. Equal audiences gate nothing.

**Deterministic layer** — `mount-isolation.py`, run by `persist.sh` on every
land when `mounts.json` exists, before the validator. It scans what the land
adds: added lines of every changed file (committed or not, `_raw/` included),
the branch's commit messages, and the `--context` handover bound for the PR
body. It blocks, attended or unattended, on:

- a file outside the charter's `holds`, or a framework file, in a mount;
- a `never` term or pattern of any gated source, and checksum-validated card
  numbers and IBANs;
- a reference into a gated source — its repository, its checkout path, a
  `<mount>:<path>` citation — and, in a mount, any citation at all.

`--plan` prints which roots gate a land and why. A `never` entry too sensitive
to track goes in the gitignored `local/mounts.json` overlay, merged on the
machine that has it.

**Judgment layer** — `--lens` writes an audience lens (who reads the target,
its purpose, each gated source's never-topics) that `authoring-review.sh
--lens` puts ahead of the diff; with a lens, changed workspace files are
reviewed too. A lens finding on a land into a mount blocks in every mode; into
the instance it behaves like any authoring finding.

## Adapt notes

- Extends the validation contract and the publish boundary; does not reinterpret
  either. The gate is skipped when no `mounts.json` exists.
- Built-in number checks are the internationally checksummed ones. National
  identifiers, emails, and phone numbers are locale-specific or noisy: list the
  shapes that must stay out under `never.patterns`.
- The term scan is literal. It catches the careless leak, not a paraphrase —
  the lens is the layer for that, and it degrades open with the review engine.
- The sweep covers the instance's own worktrees only; a detached land into a
  mount that fails is not retried.
