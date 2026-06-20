---
id: 0022
title: Domains skill — build and maintain a domain in four modes
date: 2026-06-15
tags: [skills, domains, authoring, grill, update]
touches_invariant: false
files: [skills/exobrain-domains/SKILL.md, skills/exobrain-domains/create.md, skills/exobrain-domains/distill.md, skills/exobrain-domains/curate.md, skills/exobrain-domains/update.md, skills.json]
---

## Problem

The meta-domain says *what* a domain is (`entities.md`), *how to structure* one
(`domains.md`), and *how to write* the prose (`authoring.md`), and the interview
discipline lives in `grill.md` — but the actual *procedures* for building and
maintaining a domain were uncaptured. Every effort reinvented how to scaffold from
scratch, how to turn a finished workspace into a domain, how to fold one new
artifact in, and how to run an unattended refresh — each reapplying the authoring
and grill rules from memory.

## Pattern

One `exobrain-domains` skill, **four modes** picked by what already exists and
whether a human is in the loop. A shared foundation (read the README map, locate
the meta files, worktree, apply every `authoring.md` rule, do the open-questions /
sources / timeline bookkeeping, land via the persist flow) is stated once; each
mode adds only its own procedure:

- **create** — no domain yet, knowledge scattered: scaffold → broad source sweep
  + an end-to-end code walk (a *comprehension* artifact, not text to transcribe)
  → synthesize.
- **distill** — knowledge already collected (a workspace): draft from the corpus,
  build a register of gaps/contradictions/low-confidence claims, run the `grill.md`
  interview, verify with read-back + quiz before shipping. `--wip` builds a
  parallel-construction WIP domain at a declared **definition altitude**, grilling
  only questions at/above it *or* collision-critical for people building in
  parallel.
- **curate** — domain exists, human present: fold in one artifact, or work the
  open-questions backlog, asking only what targeted lookups can't settle.
- **update** — domain exists, no human: sweep the domain's `sources.json`, filter
  every finding by the horizon test, write additively, never delete, never ask —
  the PR is the human gate.

`sources.json` is generic: a list of sources, each naming a **tool** registered in
`tools/` plus that tool's query fields; GitHub (via `gh`) is the built-in worked
example, other tools follow their own doc.

## Reference (illustration only)

`skills/exobrain-domains/` in the seed (one `SKILL.md` + one file per mode),
registered in `skills.json` at tier `optional`.

## Adapt notes

No invariant touched. The skill leans on already-adopted conventions — `domains.md`
(sections, WIP domains, timeline tracking) and `grill.md` (card 0010), the
`authoring.md` rules, the tools-as-scope-aware-primitive model (card 0006), and the
persist flow (cards 0012 / 0020) for landing. Drop or gate `update` mode and
`sources.json` if you haven't adopted tools; keep the four-mode split and the
shared foundation regardless. Genericize any source examples to your own connected
tools — never hardcode one instance's chat/issue/blog systems.
