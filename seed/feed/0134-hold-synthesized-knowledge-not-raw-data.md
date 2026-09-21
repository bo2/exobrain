---
id: 0134
title: Hold synthesized knowledge, not raw data
date: 2026-09-21
tags: [conventions, domains, validation]
touches_invariant: true
files: [AGENTS.md, knowledge/exobrain/entities.md, knowledge/exobrain/domains.md, skills/exobrain-knowledge/curate.md, scripts/validate-exobrain.sh, skills/exobrain-tests/unit/test-raw-data.sh]
---

## Problem

The old rule — don't commit data retrievable from a system of record — covered
exports and dumps but said nothing about a photo sent in chat or a PDF a site
won't keep. Those landed in `_raw/`, and the repo slowly became a file store for
material it cannot diff, search, or keep private at the right grain.

## Pattern

A root rule: the exobrain holds what was *made from* data — facts, decisions,
analysis, the code and queries behind them — and links to the data. Raw data
stays in its own system; raw data with no native home goes to the person's file
store, in a folder their person scope names. `_raw/` narrows to partially
processed material no simple call reproduces; for anything a call can retrieve,
`_raw/` keeps the call. `entities.md` carries the material→home table.

The validator blocks a file in an **unambiguously raw format** (photos, PDFs,
office documents, mail and bank exports, archives, audio, video) newly *added*
under `knowledge/` or `workspaces/`. Text formats and PNG/SVG/GIF pass — they
are as often derived as raw, so the table decides those, not the gate.

## Adapt notes

- Replaces the system-of-record bullet under Git workflow; the curate flow records
  where a source lives instead of landing the file in `_raw/`.
- Added-files-only means existing raw files are grandfathered; migrate them or
  not, as the instance prefers.
- Name the raw-data folder and the tool that reaches it in the person scope. The
  source of this pattern measured the rule with `exobrain-ab`: a no-native-home
  file went to the file store in 0/4 control runs and 4/4 treatment runs, with no
  over-trigger on a plain fact.
