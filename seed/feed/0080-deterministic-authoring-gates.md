---
id: 0080
title: Deterministic authoring gates — reject file:line citations and (verified) markers
date: 2026-07-19
tags: [scripts, validation, authoring, domains]
touches_invariant: true
files: [scripts/validate-exobrain.sh]
---

## Problem

Two authoring rules were asserted in prose but nothing enforced them, so drift
crept back: domain profiles picked up `file.ext:NNN` citations that rot when code
moves, and specs picked up `(verified YYYY-MM-DD)` freshness stamps that the
citation model rejects. The LLM authoring review can catch these, but it is
opt-in and non-deterministic.

## Pattern

Add two grep-based checks to the deterministic validator (the pre-push gate):

1. Reject `file.ext:NNN` line citations inside `domains/**` profiles — cite the
   file, not the line.
2. Reject `(verified <date>)` temporal markers in `domains/**` and `AGENTS.md` —
   a citation records provenance, not a freshness stamp; specs are standalone.

Both exclude `_raw/` (source captures keep their form) and the exobrain
meta-domain (it documents the rules with illustrative examples). The file:line
check is dormant where the meta-domain is the only domain and fires once real
content domains exist.

## Reference (illustration only)

Each is a `grep -rnE` over `domains/` (the second also over `AGENTS.md`) piped
through `grep -v /_raw/` (and, for file:line, `grep -v /domains/exobrain/`),
recording one violation per hit.

## Adapt notes

- `touches_invariant: true` — extends the validation contract. An adaptation may
  add checks but must not silently drop existing ones.
- Keep the exclusions: without the meta-domain and `_raw/` carve-outs the checks
  flag their own documentation and raw source snapshots.
- Match the code-extension list to the languages your instance's code uses.
